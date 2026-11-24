# Items on the right of the top bar: Guide, Downloads and About.

guide_item <- function() {
  nav_item(popover(
    tags$a(class = "nav-link", href = "#", bs_icon("question-circle"), " Guide"),
    title = "How to read this dashboard",
    tags$dl(class = "small mb-0",
            tags$dt("SR (standardised ratio)"), tags$dd("Players born in an area ÷ players expected from the number of boys born there. 1 = as expected, 2 = twice as many, 0.5 = half."),
            tags$dt("Smoothed"), tags$dd("Empirical Bayes: pulls areas with few births toward the average so they do not look extreme by chance."),
            tags$dt("Hotspots"), tags$dd("Groups of neighbouring areas that are together unusually high or low (Getis-Ord Gi*, false-discovery-rate corrected)."),
            tags$dt("Travel to Work Areas"), tags$dd("A town plus its catchment; avoids birthplaces being counted at the maternity-hospital town only.")),
    placement = "bottom"
  ))
}

downloads_menu <- function() {
  nav_menu(
    "Downloads", icon = bs_icon("download"), align = "right",
    nav_item(downloadLink("dl_players", "Players (CSV)")),
    nav_item(downloadLink("dl_areas", "Area results, all players (CSV)"))
  )
}

page_about <- function() {
  nav_panel("About", icon = bs_icon("info-circle"),
            card(class = "mt-2", HTML(commonmark::markdown_html(paste(readLines("about.md", encoding = "UTF-8"), collapse = "\n"), extensions = TRUE))))
}
