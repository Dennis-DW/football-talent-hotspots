# Map Explorer filters and the reactive player subset / SR table.
# Sourced inside server() with local = TRUE, so it shares input, output, session and the reactives.

years <- debounce(reactive(input$years %||% YEARS), 400)
sel <- reactive(filter_players(players, years(), input$league, input$evidence, input$positions))
level <- reactive(input$level %||% "ttwa")
sr <- reactive(units[[level()]] |> left_join(compute_sr(level(), sel(), years()), by = "unit"))
selected <- reactiveVal(NULL)
observeEvent(level(), selected(NULL))

observeEvent(input$reset, {
  updateSelectInput(session, "level", selected = "ttwa")
  updateRadioButtons(session, "measure", selected = "SR_EB")
  updateSliderInput(session, "years", value = YEARS)
  updateRadioButtons(session, "league", selected = "all")
  updateRadioButtons(session, "evidence", selected = "all")
  updateCheckboxGroupInput(session, "positions", selected = character(0))
  update_switch("show_players", value = FALSE)
  updateSliderInput(session, "opacity", value = 0.8)
  selected(NULL)
})

output$filter_summary <- renderUI({
  y <- years()
  chips <- c(if (!identical(as.numeric(y), as.numeric(YEARS))) sprintf("Born %d–%d", y[1], y[2]),
             if (identical(input$league, "pl")) "Premier League",
             if (identical(input$evidence, "certain")) "Certain evidence",
             if (length(input$positions)) paste(names(POSITIONS)[POSITIONS %in% input$positions], collapse = " · "))
  n <- nrow(sel())
  tagList(
    div(class = "chips", if (length(chips)) lapply(chips, function(x) span(class = "chip", x)) else span(class = "chip", "All players")),
    div(class = "sample-count", strong(fmt_int(n)), " players · ", nrow(units[[level()]]), " ", LEVEL_NOUN[[level()]]),
    if (n < MIN_PLAYERS) div(class = "alert alert-warning py-1 px-2 mt-2 small mb-1", bs_icon("exclamation-triangle"),
                             " Few players with these filters — results are less reliable."),
    if (identical(input$measure, "gi") && length(chips) > 0)
      div(class = "alert alert-info py-1 px-2 mt-2 small mb-1", "Hotspots were computed for all players and do not change with filters.")
  )
})
output$me_kpis <- renderUI({
  d <- st_drop_geometry(sr())
  top <- d |> filter(E >= 3) |> slice_max(SR_EB, n = 1, with_ties = FALSE)
  above <- sum(d$SR_EB > 1, na.rm = TRUE)
  layout_column_wrap(
    width = "200px", fill = FALSE, class = "mb-3",
    kpi("people-fill", "navy", fmt_int(nrow(sel())), "Players selected",
        if (nrow(sel()) == nrow(players)) "all English-born players on the map" else "with the current filters"),
    kpi("arrow-up-right-circle-fill", "red", sprintf("%d of %d", above, nrow(d)), "Areas above expected",
        sprintf("%.0f%% of %s", 100 * above / nrow(d), LEVEL_NOUN[[level()]])),
    kpi("trophy-fill", "gold", if (nrow(top)) sprintf("%.2f×", top$SR_EB) else "—", if (nrow(top)) top$name else "Top area",
        "highest smoothed ratio"),
    kpi("dash-circle-fill", "teal", sum(d$O == 0), "Areas with no players", sprintf("of %d %s", nrow(d), LEVEL_NOUN[[level()]]))
  )
})
output$map_title <- renderUI({
  m <- c(SR_EB = "Players relative to births (smoothed)", SR = "Players relative to births (raw)", gi = "Hotspots and coldspots")
  span(m[[input$measure %||% "SR_EB"]], span(class = "hint", paste0(" · ", LEVEL_NOUN[[level()]])))
})
