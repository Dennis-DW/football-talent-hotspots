# Football Talent Hotspots — interactive dashboard
# Where do England's Premier League and Championship footballers come from?
#
# Data are prepared by analysis/dashboard/09_app_data.R (app/data/). Styles: app/www/styles.css.
# The code is split into src/:
#   setup/    packages, data and constants, headline numbers
#   helpers/  statistics, maps and plots, reusable UI components
#   ui/       one file per page, the Map Explorer sidebar, the top bar and the page layout
#   server/   one file per page or feature, sourced inside server() so they share its reactives
# Run locally with
#   shiny::runApp("app", host = "0.0.0.0", port = 3838)

# order matters: the headline numbers use the data and the helpers
for (f in c("setup/packages.R", "setup/data.R", "helpers/stats.R", "helpers/maps_plots.R", "helpers/components.R",
            "setup/headline_numbers.R", "ui/sidebar.R", "ui/page_overview.R", "ui/page_map_explorer.R", "ui/page_why.R",
            "ui/page_patterns.R", "ui/page_world.R", "ui/top_bar.R", "ui/ui.R")) {
  source(file.path("src", f), local = TRUE)
}

server <- function(input, output, session) {
  # (shareable links: ?tab=Map Explorer etc. are handled when the page is built, see src/ui/ui.R)
  for (f in c("navigation", "filters", "map", "ranking", "area_profile", "downloads",
              "overview", "why", "patterns", "world")) {
    source(file.path("src/server", paste0(f, ".R")), local = TRUE)
  }
}

shinyApp(ui, server)
