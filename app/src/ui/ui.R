# Page layout: top bar and pages. A function of the request so that ?tab=<page> opens that page.

TABS <- c("Overview", "Map Explorer", "Why?", "Patterns", "World", "About")
ui <- function(request) {
  start <- parseQueryString(request$QUERY_STRING)$tab
  if (is.null(start) || !start %in% TABS) start <- "Overview"
  page_navbar(
    id = "nav", selected = start,
    title = tags$span(span(class = "brand-mark", bs_icon("geo-alt-fill")), "Football Talent Hotspots"),
    window_title = "Football Talent Hotspots",
    theme = bs_theme(version = 5, primary = "#1f3a5f",
                     base_font = font_google("Inter", local = FALSE),
                     heading_font = font_google("Inter", local = FALSE)),
    navbar_options = navbar_options(bg = "#1f3a5f", theme = "dark", underline = FALSE),
    fillable = FALSE,
    # version stamp so browsers reload the stylesheet whenever it changes (no stale cache)
    header = tags$head(tags$link(rel = "stylesheet",
                                 href = paste0("styles.css?v=", as.integer(file.mtime("www/styles.css"))))),
    footer = div(class = "app-footer",
                 "Data: Wikidata (CC0) · Wikipedia (CC BY-SA) · ONS & MHCLG (Open Government Licence v3.0; contains OS data © Crown copyright) · ",
                 "World Bank (CC BY 4.0) · Natural Earth · Base maps © Esri, © OpenStreetMap contributors · Code: MIT"),

    page_overview(),
    page_map_explorer(),
    page_why(),
    page_patterns(),
    page_world(),
    nav_spacer(),
    guide_item(),
    downloads_menu(),
    page_about()
  )
}
