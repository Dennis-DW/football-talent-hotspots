# Football Talent Hotspots — interactive dashboard
# Where do England's Premier League and Championship footballers come from?
#
# Data are prepared by R/09_app_data.R (app/data/*.rds). Run locally with
#   shiny::runApp("app", host = "0.0.0.0", port = 3838)

suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(leaflet)
  library(sf)
  library(dplyr)
  library(ggplot2)
  library(terra)
})

units <- readRDS("data/units.rds")
births <- readRDS("data/births_unit_year.rds")
players <- readRDS("data/players.rds")
tabs <- readRDS("data/tables.rds")
world <- readRDS("data/world.rds")
rr_rast <- rast("data/relative_risk.tif")

LEVELS <- c("Travel to Work Areas (main)" = "ttwa", "Local authorities" = "lad21", "20 km hexagons" = "hex20")
GI_COLS <- c("Hotspot (FDR q<0.05)" = "#b2182b", "Hotspot (q<0.10)" = "#ef8a62",
             "Hot, exploratory (p<0.05)" = "#fddbc7", "Not significant" = "#f7f7f7",
             "Cold, exploratory (p<0.05)" = "#d1e5f0", "Coldspot (q<0.10)" = "#67a9cf",
             "Coldspot (FDR q<0.05)" = "#2166ac")
YEARS <- range(players$birth_year)

# --- helpers -----------------------------------------------------------------------------
filter_players <- function(p, years, premier, certain, positions) {
  p <- p[p$birth_year >= years[1] & p$birth_year <= years[2], ]
  if (premier) p <- p[p$premier_league, ]
  if (certain) p <- p[p$certain, ]
  if (length(positions) && !"All" %in% positions) p <- p[!is.na(p$position) & p$position %in% positions, ]
  p
}

# Observed / expected / SR for any player subset (proposal section 6.4), plus
# Empirical Bayes smoothing (global method-of-moments, Marshall 1991).
compute_sr <- function(level, p, years) {
  if (level != "ttwa") p <- p[p$fine, ]
  b <- births[births$level == level & births$birth_year >= years[1] & births$birth_year <= years[2], ]
  n_y <- table(factor(p$birth_year, levels = years[1]:years[2]))
  B_y <- tapply(b$b, b$birth_year, sum)
  rate <- as.numeric(n_y[as.character(names(B_y))]) / B_y
  b$e <- b$b * rate[as.character(b$birth_year)]
  E <- tapply(b$e, b$unit, sum)
  O <- table(factor(p[[level]], levels = names(E)))
  d <- data.frame(unit = names(E), E = as.numeric(E), O = as.numeric(O[names(E)]))
  d$SR <- ifelse(d$E > 0, d$O / d$E, NA)
  m <- sum(d$O) / sum(d$E)
  s2 <- sum(d$E * (d$SR - m)^2, na.rm = TRUE) / sum(d$E)
  phi <- max(s2 - m / mean(d$E), 0)
  C <- phi / (phi + m / d$E)
  d$SR_EB <- m + C * (d$SR - m)
  d
}

sr_pal <- function() colorNumeric(c("#2166ac", "#67a9cf", "#f7f7f7", "#ef8a62", "#b2182b"),
                                  domain = c(-2, 2), na.color = "#dddddd")
clamp_log2 <- function(x) pmin(pmax(log2(x), -2), 2)

# Background maps that need no API key (CARTO basemaps now require one):
# Esri Light Gray Canvas (default) and OpenStreetMap, switchable in the map.
base_tiles <- function(map) {
  map |>
    addProviderTiles(providers$Esri.WorldGrayCanvas, group = "Light grey (Esri)") |>
    addTiles(group = "OpenStreetMap") |>
    addLayersControl(baseGroups = c("Light grey (Esri)", "OpenStreetMap"),
                     position = "topright", options = layersControlOptions(collapsed = TRUE))
}

# --- UI ------------------------------------------------------------------------------------
filters <- tagList(
  sliderInput("years", "Players born", min = YEARS[1], max = YEARS[2], value = YEARS, sep = "", step = 1),
  checkboxInput("premier", "Premier League players only", FALSE),
  checkboxInput("certain", "Certain appearance evidence only", FALSE),
  checkboxGroupInput("positions", "Position", c("All", "Goalkeeper", "Defender", "Midfielder", "Forward"),
                     selected = "All", inline = TRUE),
  helpText("Expected counts are recomputed for the selected players from male births in the same years.")
)

ui <- page_navbar(
  title = "Football Talent Hotspots",
  theme = bs_theme(version = 5, bootswatch = "flatly"),
  nav_panel(
    "Hotspot map",
    layout_sidebar(
      sidebar = sidebar(
        width = 320,
        selectInput("level", "Areas", LEVELS),
        radioButtons("measure", "Show", c("Smoothed SR (Empirical Bayes)" = "SR_EB", "Raw SR (observed / expected)" = "SR",
                                          "Getis-Ord Gi* hotspots" = "gi")),
        filters,
        uiOutput("gi_note")
      ),
      card(full_screen = TRUE, leafletOutput("map", height = "72vh")),
      card(card_header("Areas with the most players relative to births (smoothed)"), tableOutput("top_units"))
    )
  ),
  nav_panel(
    "Players",
    layout_sidebar(
      sidebar = sidebar(width = 320, uiOutput("player_count"),
                        helpText("English-born players with a town-level birthplace. Public information from Wikidata only."),
                        sliderInput("years_p", "Players born", min = YEARS[1], max = YEARS[2], value = YEARS, sep = ""),
                        checkboxInput("premier_p", "Premier League players only", FALSE)),
      card(full_screen = TRUE, leafletOutput("pmap", height = "78vh"))
    )
  ),
  nav_panel(
    "Clustering (RQ1)",
    layout_columns(
      col_widths = c(6, 6),
      card(card_header("Relative risk: player density ÷ births density (σ = 15 km)"),
           leafletOutput("rrmap", height = "60vh")),
      card(card_header("Inhomogeneous L-function vs. births (999 simulations)"),
           plotOutput("lplot", height = "40vh"), tableOutput("ltests"))
    ),
    card(card_header("Players per 10,000 male births by region"), tableOutput("regions"))
  ),
  nav_panel(
    "Drivers (RQ3)",
    layout_columns(
      col_widths = c(12, 6, 6),
      card(card_header("Rate ratios: negative binomial models, offset = expected from births"),
           plotOutput("forest", height = "45vh")),
      card(card_header("Region effects (vs. West Midlands)"), plotOutput("regfx", height = "35vh")),
      card(card_header("Smoothed SR vs. distance to nearest club at age 12 (TTWA)"), plotOutput("scatter", height = "35vh"))
    ),
    card(card_header("Academy-era sub-model (born 1996–2005): distance per +10 km"), tableOutput("academy"))
  ),
  nav_panel(
    "Foreign-born (RQ4)",
    layout_sidebar(
      sidebar = sidebar(width = 300,
                        radioButtons("wmeasure", "Show", c("Players per million people" = "per_million",
                                                           "Number of players" = "total")),
                        radioButtons("wcohort", "Born", c("1975–2005" = "total", "1975–1989" = "1975–1989",
                                                         "1990–2005" = "1990–2005")),
                        helpText("Descriptive only: players born abroad reflect recruitment by English clubs, not talent production in each country.")),
      card(full_screen = TRUE, leafletOutput("wmap", height = "55vh")),
      card(card_header("Top 25 countries"), tableOutput("wtable"))
    )
  ),
  nav_panel("About", card(HTML(commonmark::markdown_html(paste(readLines("about.md", encoding = "UTF-8"), collapse = "\n"), extensions = TRUE))))
)

# --- server ---------------------------------------------------------------------------------
server <- function(input, output, session) {
  is_default <- reactive(identical(as.numeric(input$years), as.numeric(YEARS)) && !input$premier &&
                           !input$certain && ("All" %in% input$positions || !length(input$positions)))
  sel <- reactive(filter_players(players, input$years, input$premier, input$certain, input$positions))
  sr <- reactive({
    g <- units[[input$level]]
    g |> left_join(compute_sr(input$level, sel(), input$years), by = "unit")
  })

  output$gi_note <- renderUI({
    if (input$measure == "gi" && !is_default())
      div(class = "alert alert-warning", "Gi* hotspots were computed for all players (9,999 permutations) and do not change with the filters.")
  })

  output$map <- renderLeaflet({
    leaflet(options = leafletOptions(preferCanvas = TRUE)) |> base_tiles() |>
      setView(-1.6, 52.9, 6)
  })
  observe({
    d <- sr()
    pop <- sprintf("<b>%s</b><br>Players: %d<br>Expected: %.1f<br>SR: %.2f<br>Smoothed SR: %.2f<br>Gi* z: %.2f (q = %.2f)",
                   htmltools::htmlEscape(d$name), as.integer(d$O), d$E, d$SR, d$SR_EB, d$Gi_z, d$Gi_q)
    proxy <- leafletProxy("map", data = d) |> clearShapes() |> removeControl("legend")
    if (input$measure == "gi") {
      pal <- colorFactor(GI_COLS, levels = names(GI_COLS))
      proxy |> addPolygons(fillColor = ~pal(gi_class), fillOpacity = 0.8, color = "#888", weight = 0.4, popup = pop) |>
        addLegend("bottomright", pal = pal, values = names(GI_COLS), title = "Getis-Ord Gi*", layerId = "legend")
    } else {
      pal <- sr_pal()
      v <- clamp_log2(d[[input$measure]])
      proxy |> addPolygons(fillColor = pal(v), fillOpacity = 0.8, color = "#888", weight = 0.4, popup = pop) |>
        addLegend("bottomright", colors = pal(c(-2, -1, 0, 1, 2)), labels = c("≤0.25", "0.5", "1", "2", "≥4"),
                  title = "SR (players / expected)", layerId = "legend")
    }
  })
  output$top_units <- renderTable({
    st_drop_geometry(sr()) |> filter(E >= 3) |> arrange(desc(SR_EB)) |> head(10) |>
      transmute(Area = name, Players = as.integer(O), Expected = round(E, 1), SR = round(SR, 2), `Smoothed SR` = round(SR_EB, 2))
  })

  # players map
  psel <- reactive({
    p <- players[players$fine & players$birth_year >= input$years_p[1] & players$birth_year <= input$years_p[2], ]
    if (input$premier_p) p <- p[p$premier_league, ]
    p
  })
  output$player_count <- renderUI(strong(sprintf("%s players shown", format(nrow(psel()), big.mark = ","))))
  output$pmap <- renderLeaflet({
    p <- psel()
    leaflet(p) |> base_tiles() |>
      addCircleMarkers(~lon, ~lat, radius = 4, stroke = FALSE, fillOpacity = 0.7,
                       color = ~ifelse(premier_league, "#b2182b", "#2166ac"),
                       clusterOptions = markerClusterOptions(),
                       popup = ~sprintf("<b><a href='https://www.wikidata.org/wiki/%s' target='_blank'>%s</a></b><br>Born %d, %s<br>%s<br>%s",
                                        player_qid, htmltools::htmlEscape(label), birth_year,
                                        htmltools::htmlEscape(place_label), ifelse(is.na(position), "", position),
                                        ifelse(premier_league, "Premier League", "Championship / second tier")))
  })

  # clustering
  output$rrmap <- renderLeaflet({
    v <- clamp(log2(rr_rast), -2, 2)
    pal <- colorNumeric(c("#2166ac", "#67a9cf", "#f7f7f7", "#ef8a62", "#b2182b"), domain = c(-2, 2), na.color = "transparent")
    leaflet() |> base_tiles() |>
      addRasterImage(v, colors = pal, opacity = 0.75, project = TRUE) |>
      addLegend("bottomright", colors = pal(c(-2, -1, 0, 1, 2)), labels = c("≤0.25", "0.5", "1", "2", "≥4"), title = "relative risk")
  })
  output$lplot <- renderPlot({
    e <- tabs$lenv
    ggplot(e, aes(r_km)) + geom_ribbon(aes(ymin = lo - r_km, ymax = hi - r_km), fill = "grey80") +
      geom_hline(yintercept = 0, linetype = 2) + geom_line(aes(y = L_obs - r_km), colour = "#b2182b", linewidth = 1) +
      labs(x = "distance r (km)", y = "L(r) − r (km)", caption = "Grey: 95% global envelope of births-only placement") +
      theme_minimal(base_size = 13)
  })
  output$ltests <- renderTable(tabs$ltests |> transmute(Pattern = pattern, Test = test, `r (km)` = r_range_km,
                                                         `p-value` = signif(p_value, 2), Simulations = nsim))
  output$regions <- renderTable(tabs$regions |> transmute(Region = region, Players = players,
                                                           `Per 10,000 births` = round(per_10k_births, 2),
                                                           SR = round(SR, 2), `p-value` = signif(p_value, 2)))

  # drivers
  output$forest <- renderPlot({
    lab <- c(imd10 = "Deprivation (+10 IMD points)", urban10 = "Urban share (+10 pp)", dist10 = "Distance to club (+10 km)")
    d <- tabs$rr |> mutate(term = lab[term], model = factor(model, rev(unique(model))))
    ggplot(d, aes(RR, model)) + geom_vline(xintercept = 1, linetype = 2) +
      geom_errorbar(aes(xmin = lo, xmax = hi), width = 0.2, orientation = "y") +
      geom_point(aes(colour = model == "TTWA: main (M2)"), size = 2.5) +
      scale_colour_manual(values = c(`TRUE` = "#b2182b", `FALSE` = "grey20"), guide = "none") +
      facet_wrap(~term, scales = "free_x") + scale_x_log10() + labs(x = "Rate ratio (95% CI)", y = NULL) +
      theme_minimal(base_size = 12)
  })
  output$regfx <- renderPlot({
    ggplot(tabs$region_fx, aes(RR, reorder(term, RR), fill = RR > 1)) + geom_col() +
      geom_vline(xintercept = 1, linetype = 2) + scale_fill_manual(values = c(`TRUE` = "#ef8a62", `FALSE` = "#67a9cf"), guide = "none") +
      labs(x = "Rate ratio vs. West Midlands", y = NULL) + theme_minimal(base_size = 12)
  })
  output$scatter <- renderPlot({
    ggplot(tabs$model_data, aes(dist_club_km, SR_EB, colour = region)) + geom_point(alpha = 0.8) +
      geom_smooth(aes(group = 1), method = "glm", formula = y ~ x, colour = "black", se = FALSE, linewidth = 0.6) +
      scale_y_log10() + labs(x = "distance to nearest professional club at age 12 (km)", y = "smoothed SR (log scale)", colour = NULL) +
      theme_minimal(base_size = 11) + theme(legend.position = "bottom", legend.text = element_text(size = 8))
  })
  output$academy <- renderTable(tabs$academy |> filter(term %in% c("club10", "acad10")) |>
                                  transmute(Model = model, Distance = ifelse(term == "club10", "any professional club", "Category 1 academy"),
                                            `Rate ratio` = round(RR, 3), `95% CI` = sprintf("%.2f–%.2f", lo, hi), `p-value` = signif(p, 2)))

  # world
  wdata <- reactive({
    c <- tabs$countries
    v <- if (input$wcohort == "total") c$total else c[[input$wcohort]]
    c$players <- v
    c$value <- if (input$wmeasure == "per_million") v / (c$pop_mean / 1e6) else v
    c
  })
  output$wmap <- renderLeaflet({
    c <- wdata()
    w <- world |> left_join(c |> select(country, players, value), by = "country")
    w$value[!is.na(w$value) & w$value <= 0] <- NA
    pal <- colorNumeric("plasma", domain = log10(range(w$value, na.rm = TRUE)), na.color = "#eeeeee")
    leaflet(w) |> base_tiles() |> setView(10, 35, 2) |>
      addPolygons(fillColor = ~pal(log10(value)), fillOpacity = 0.8, color = "#999", weight = 0.3,
                  popup = ~sprintf("<b>%s</b><br>Players: %s<br>%s", htmltools::htmlEscape(country),
                                   ifelse(is.na(players), 0, players),
                                   ifelse(is.na(value), "", sprintf(if (input$wmeasure == "per_million") "%.2f per million" else "%.0f", value)))) |>
      addLegend("bottomleft", pal = pal, values = log10(range(w$value, na.rm = TRUE)),
                labFormat = labelFormat(transform = function(x) signif(10^x, 2)),
                title = if (input$wmeasure == "per_million") "per million" else "players")
  })
  output$wtable <- renderTable({
    wdata() |> filter(country != "(unknown)") |> arrange(desc(players)) |> head(25) |>
      transmute(Country = country, `Born 1975–89` = `1975–1989`, `Born 1990–2005` = `1990–2005`,
                Total = total, `Per million` = round(per_million, 2))
  })
}

shinyApp(ui, server)
