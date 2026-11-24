# Filter sidebar of the Map Explorer.

explorer_sidebar <- sidebar(
  width = 320, open = list(desktop = "open", mobile = "closed"),
  div(class = "filter-head", h6("Filters"),
      actionButton("reset", tagList(bs_icon("arrow-counterclockwise"), "Reset"), class = "btn-sm btn-outline-secondary")),
  uiOutput("filter_summary"),
  accordion(
    id = "filters", open = c("Map", "Players"), multiple = TRUE,
    accordion_panel(
      "Map", icon = bs_icon("map"),
      selectInput("level", "Areas", LEVELS),
      seg_group("measure", "Colour areas by", MEASURES, "SR_EB"),
      input_switch("show_players", "Show player birthplaces", FALSE)
    ),
    accordion_panel(
      "Players", icon = bs_icon("people"),
      sliderInput("years", "Born", min = YEARS[1], max = YEARS[2], value = YEARS, sep = "", step = 1, ticks = FALSE),
      seg_group("league", "League", c("Both leagues" = "all", "Premier League" = "pl"), "all"),
      seg_group("evidence", "Appearance evidence", c("All" = "all", "Certain only" = "certain"), "all"),
      seg_group("positions", "Position (none = all)", POSITIONS, type = "checkbox")
    ),
    accordion_panel(
      "Display", icon = bs_icon("sliders"),
      sliderInput("opacity", "Area opacity", min = 0.3, max = 1, value = 0.8, step = 0.05, ticks = FALSE)
    )
  )
)
