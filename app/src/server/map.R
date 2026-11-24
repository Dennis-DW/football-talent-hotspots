# Map Explorer: the map.
# Sourced inside server() with local = TRUE, so it shares input, output, session and the reactives.

output$map <- renderLeaflet({
  leaflet(options = leafletOptions(preferCanvas = TRUE, minZoom = 5)) |> base_tiles() |> england_view() |>
    addEasyButton(easyButton(icon = HTML("<span style='font-size:16px'>&#8634;</span>"), title = "Back to England",
                             onClick = JS("function(btn, map){ map.setView([52.8, -1.9], 6); }")))
})
observe({
  req(input$map_zoom)               # the map must exist in the browser before drawing
  d <- sr()
  req(nrow(d) > 0)
  measure <- input$measure %||% "SR_EB"
  lab <- lapply(sprintf("<b>%s</b><br>%s players · %.1f expected<br>Ratio %.2f · smoothed %.2f",
                        htmlEscape(d$name), fmt_int(d$O), d$E, d$SR, d$SR_EB), HTML)
  fill <- if (measure == "gi") unname(GI_COLS[d$gi_class]) else sr_pal(clamp_log2(d[[measure]]))
  proxy <- leafletProxy("map", data = d) |> clearGroup("areas") |> removeControl("legend") |>
    addPolygons(layerId = ~unit, group = "areas", fillColor = fill, fillOpacity = input$opacity %||% 0.8,
                color = "#ffffff", weight = 0.6, label = lab,
                labelOptions = labelOptions(direction = "auto", textsize = "12px"),
                highlightOptions = highlightOptions(weight = 2.5, color = "#222", bringToFront = TRUE))
  if (measure == "gi") {
    proxy |> addLegend("bottomright", colors = unname(GI_COLS), labels = unname(GI_SHORT), title = "Gi* hotspots",
                       layerId = "legend", opacity = 0.9)
  } else {
    proxy |> addLegend("bottomright", colors = sr_pal(c(2, 1, 0, -1, -2)),
                       labels = c("4× or more", "2×", "as expected", "half", "¼ or less"),
                       title = "Players vs. births", layerId = "legend", opacity = 0.9)
  }
})
observe({
  req(input$map_zoom)
  proxy <- leafletProxy("map") |> clearGroup("players")
  if (isTRUE(input$show_players)) {
    p <- sel()
    p <- p[p$fine, ]
    proxy |> addCircleMarkers(data = p, lng = ~lon, lat = ~lat, group = "players", radius = 5, stroke = TRUE, weight = 1,
                              color = "#fff", fillColor = ifelse(p$premier_league, "#3d195b", "#2b8a3e"), fillOpacity = 0.85,
                              clusterOptions = markerClusterOptions(showCoverageOnHover = FALSE),
                              label = lapply(sprintf("<b>%s</b><br>%s, born %d", htmlEscape(p$label),
                                                     htmlEscape(p$place_label), p$birth_year), HTML))
  }
})
observeEvent(input$map_shape_click, {
  id <- input$map_shape_click$id
  if (!is.null(id) && id %in% sr()$unit) selected(id)
})
observe({
  req(input$map_zoom)
  proxy <- leafletProxy("map") |> clearGroup("selected")
  id <- selected()
  if (!is.null(id)) {
    g <- sr()[sr()$unit == id, ]
    if (nrow(g)) proxy |> addPolylines(data = g, group = "selected", color = "#111", weight = 3, opacity = 1)
  }
})
