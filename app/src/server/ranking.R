# Map Explorer: area ranking table.
# Sourced inside server() with local = TRUE, so it shares input, output, session and the reactives.

ranked <- reactive({
  st_drop_geometry(sr()) |>
    arrange(desc(SR_EB)) |>
    mutate(rank = row_number(), region = coalesce(region, "—"))
})
observe({
  regs <- sort(unique(ranked()$region[ranked()$region != "—"]))
  updateSelectInput(session, "rank_region", choices = c("All regions" = "all", setNames(regs, short_region(regs))),
                    selected = if (isTRUE(input$rank_region %in% regs)) input$rank_region else "all")
})
ranked_view <- reactive({
  d <- ranked()
  f <- input$rank_filter %||% "all"
  if (f == "above") d <- d[d$SR_EB > 1, ] else if (f == "below") d <- d[d$SR_EB < 1, ]
  if (!identical(input$rank_region %||% "all", "all")) d <- d[d$region == input$rank_region, ]
  d
})
output$rank_table <- renderReactable({
  d <- ranked_view()
  reactable(
    d |> mutate(region = short_region(region)) |> select(rank, name, region, O, E, SR, SR_EB, gi_class, unit),
    selection = "single", onClick = "select", highlight = TRUE, compact = TRUE, searchable = TRUE,
    defaultPageSize = 10, showPageSizeOptions = TRUE, pageSizeOptions = c(10, 25, 50, 200),
    theme = reactableTheme(rowSelectedStyle = list(backgroundColor = "#e7eef7", boxShadow = "inset 3px 0 0 #1f3a5f"),
                           headerStyle = HEADER_STYLE),
    rowStyle = function(i) if (d$E[i] < 3) list(color = "#9aa1a9"),
    columns = list(
      .selection = colDef(show = FALSE),
      rank = colDef("#", width = 48, align = "right"),
      name = colDef("Area", minWidth = 170, style = list(fontWeight = 600)),
      region = colDef("Region", minWidth = 165, show = level() != "hex20"),
      O = colDef("Players", width = 75, align = "right", format = colFormat(separators = TRUE)),
      E = colDef(width = 80, align = "right", format = colFormat(digits = 1),
                 header = with_tooltip("Expected", "Players expected from the number of boys born there.")),
      SR = colDef(minWidth = 160, cell = sr_bar, html = TRUE,
                  header = with_tooltip("Players vs. expected", "Raw standardised ratio (observed ÷ expected); the centre line is 1 = as expected.")),
      SR_EB = colDef(width = 90, align = "right", format = colFormat(digits = 2),
                     header = with_tooltip("Smoothed", "Empirical Bayes: areas with few births pulled toward the average.")),
      gi_class = colDef(minWidth = 125, cell = function(v) if (v == "Not significant") "" else tag_span(GI_TAG[[v]], GI_SHORT[[v]]),
                        header = with_tooltip("Hotspot", "Getis-Ord Gi* class for all players (does not change with filters).")),
      unit = colDef(show = FALSE)
    ),
    language = reactableLang(searchPlaceholder = "Search areas…", noData = "No areas match these filters")
  )
})
# table -> map
observeEvent(getReactableState("rank_table", "selected"), {
  i <- getReactableState("rank_table", "selected")
  if (length(i)) {
    id <- ranked_view()$unit[i]
    if (!identical(selected(), id)) {
      selected(id)
      bb <- st_bbox(sr()[sr()$unit == id, ])
      leafletProxy("map") |> flyToBounds(bb[["xmin"]], bb[["ymin"]], bb[["xmax"]], bb[["ymax"]], options = list(maxZoom = 9))
    }
  }
}, ignoreNULL = TRUE)
# map -> table: highlight the row and jump to its page
observeEvent(selected(), {
  id <- selected()
  if (is.null(id)) return(updateReactable("rank_table", selected = NA))
  i <- match(id, ranked_view()$unit)
  if (is.na(i)) return()
  ps <- getReactableState("rank_table", "pageSize") %||% 10
  if (!identical(getReactableState("rank_table", "selected"), i))
    updateReactable("rank_table", selected = i, page = ceiling(i / ps))
}, ignoreNULL = FALSE)
output$dl_rank <- downloadHandler(
  filename = function() sprintf("area_ranking_%s.csv", level()),
  content = function(f) write.csv(ranked() |> select(rank, unit, name, region, players = O, expected = E, SR,
                                                     SR_smoothed = SR_EB, hotspot = gi_class), f, row.names = FALSE)
)
