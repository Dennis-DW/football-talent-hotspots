# World page outputs.
# Sourced inside server() with local = TRUE, so it shares input, output, session and the reactives.

wdata <- reactive({
  c <- w_all
  v <- if ((input$wcohort %||% "total") == "total") c$total else c[[input$wcohort]]
  c$players <- v
  c$value <- if ((input$wmeasure %||% "per_million") == "per_million") v / (c$pop_mean / 1e6) else v
  c
})
output$wmap <- renderLeaflet({
  c <- wdata()
  w <- world |> left_join(c |> select(country, players, value), by = "country")
  w$value[!is.na(w$value) & w$value <= 0] <- NA
  rng <- log10(range(w$value, na.rm = TRUE))
  pal <- colorNumeric("YlOrRd", domain = rng, na.color = "#f1f1f1")
  per_m <- (input$wmeasure %||% "per_million") == "per_million"
  leaflet(w, options = leafletOptions(minZoom = 2, worldCopyJump = TRUE)) |> base_tiles() |> setView(5, 35, 2) |>
    addPolygons(fillColor = ~pal(log10(value)), fillOpacity = 0.85, color = "#999", weight = 0.3,
                label = lapply(sprintf("<b>%s</b><br>%s players%s", htmlEscape(w$country), fmt_int(coalesce(w$players, 0)),
                                       ifelse(is.na(w$value) | !per_m, "", sprintf(" · %.2f per million", w$value))), HTML),
                highlightOptions = highlightOptions(weight = 1.5, color = "#222", bringToFront = TRUE)) |>
    addLegend("bottomleft", pal = pal, values = rng, opacity = 0.9,
              labFormat = labelFormat(transform = function(x) signif(10^x, 2)),
              title = if (per_m) "Players per<br>million people" else "Players")
})
output$wcont <- renderPlot({
  d <- w_all |> select(group, `1975–1989`, `1990–2005`) |>
    tidyr::pivot_longer(-group, names_to = "cohort", values_to = "n") |>
    group_by(cohort, group) |> summarise(n = sum(n), .groups = "drop_last") |> mutate(share = n / sum(n)) |> ungroup() |>
    mutate(group = factor(group, rev(W_GROUPS)))
  ggplot(d, aes(share, group, fill = cohort)) + geom_col(position = position_dodge(width = 0.75), width = 0.7) +
    geom_text(aes(label = sprintf("%.0f%%", 100 * share)), position = position_dodge(width = 0.75), hjust = -0.15, size = 3.2) +
    scale_fill_manual(values = c("1975–1989" = "#9ecae1", "1990–2005" = "#1f3a5f"), name = "Born") +
    scale_x_continuous(labels = function(x) sprintf("%.0f%%", 100 * x), expand = expansion(mult = c(0, 0.2))) +
    labs(x = NULL, y = NULL) + theme_dash(11) + theme(legend.position = "top", legend.justification = "left")
})
wtab <- reactive({
  d <- wdata() |> mutate(change = `1990–2005` - `1975–1989`,
                         pct = ifelse(`1975–1989` > 0, change / `1975–1989`, NA),
                         share = total / w_outside) |>
    arrange(desc(total)) |> mutate(rank = row_number())
  if (!identical(input$wcontinent %||% "all", "all")) d <- d |> filter(group == input$wcontinent)
  d
})
output$wtable <- renderReactable({
  d <- wtab()
  max_total <- max(w_all$total)
  max_pm <- max(w_all$per_million[w_all$total >= 10], na.rm = TRUE)
  reactable(
    d |> select(rank, country, subregion, total, `1975–1989`, `1990–2005`, change, pct, share, per_million),
    compact = TRUE, searchable = TRUE, highlight = TRUE, defaultPageSize = 15, showPageSizeOptions = TRUE,
    pageSizeOptions = c(15, 30, 60, 150), selection = "single", onClick = "select",
    theme = reactableTheme(rowSelectedStyle = list(backgroundColor = "#e7eef7", boxShadow = "inset 3px 0 0 #1f3a5f"),
                           headerStyle = list(fontSize = ".78rem", textTransform = "uppercase", letterSpacing = ".03em",
                                              color = "var(--bs-secondary-color)")),
    rowStyle = function(i) if (d$total[i] < 10) list(color = "#9aa1a9"),
    language = reactableLang(searchPlaceholder = "Search countries…"),
    columns = list(
      .selection = colDef(show = FALSE),
      rank = colDef("#", width = 48, align = "right"),
      country = colDef("Country", minWidth = 190, cell = function(v, i) {
        div(div(style = "font-weight:600", v, if (d$country[i] %in% UK_OTHER) span(class = "tag tag-pl ms-1", "UK")),
            div(class = "note", d$subregion[i]))
      }),
      subregion = colDef(show = FALSE),
      total = colDef("Players", minWidth = 150, cell = function(v) plain_bar(v, max_total, "#1f3a5f", digits = 0)),
      `1975–1989` = colDef("Born 1975–89", width = 105, align = "right"),
      `1990–2005` = colDef("Born 1990–2005", width = 115, align = "right"),
      change = colDef("Change", width = 120, align = "right", cell = function(v, i) {
        p <- d$pct[i]
        lab <- if (is.na(p)) "" else sprintf(" (%+.0f%%)", 100 * p)
        if (v > 0) span(class = "up", "▲ ", v, span(class = "note", lab))
        else if (v < 0) span(class = "down", "▼ ", abs(v), span(class = "note", lab)) else "—"
      }),
      pct = colDef(show = FALSE),
      share = colDef("Share", width = 75, align = "right", format = colFormat(percent = TRUE, digits = 1),
                     header = with_tooltip("Share", "Share of all players born outside England.")),
      per_million = colDef("Per million people", minWidth = 170,
                           cell = function(v) if (is.na(v)) "—" else plain_bar(v, max_pm, "#d6604d", digits = 2))
    )
  )
})
observeEvent(getReactableState("wtable", "selected"), {
  i <- getReactableState("wtable", "selected")
  if (length(i)) {
    ctry <- wtab()$country[i]
    g <- world[world$country == ctry, ]
    if (nrow(g)) {
      bb <- st_bbox(g)
      leafletProxy("wmap") |> clearGroup("wsel") |>
        addPolylines(data = g, group = "wsel", color = "#111", weight = 2.5, opacity = 1) |>
        flyToBounds(bb[["xmin"]], bb[["ymin"]], bb[["xmax"]], bb[["ymax"]], options = list(maxZoom = 6))
    }
  }
}, ignoreNULL = TRUE)
output$dl_world <- downloadHandler(
  filename = function() "players_by_country.csv",
  content = function(f) write.csv(tabs$countries |> select(country, `1975–1989`, `1990–2005`, total, pop_mean, per_million),
                                  f, row.names = FALSE)
)
