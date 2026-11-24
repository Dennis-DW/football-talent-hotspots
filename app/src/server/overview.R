# Overview page outputs.
# Sourced inside server() with local = TRUE, so it shares input, output, session and the reactives.

output$ov_map <- renderLeaflet({
  d <- units$ttwa |> left_join(compute_sr("ttwa", players, YEARS), by = "unit")
  leaflet(d, options = leafletOptions(minZoom = 5)) |> base_tiles() |> england_view() |>
    addPolygons(fillColor = ~sr_pal(clamp_log2(SR_EB)), fillOpacity = 0.85, color = "#fff", weight = 0.5,
                label = lapply(sprintf("<b>%s</b><br>%.2f× expected", htmlEscape(d$name), d$SR_EB), HTML),
                highlightOptions = highlightOptions(weight = 2, color = "#222", bringToFront = TRUE)) |>
    addLegend("bottomright", colors = sr_pal(c(2, 1, 0, -1, -2)), labels = c("4×+", "2×", "as expected", "half", "¼ or less"),
              title = "Players vs. births", opacity = 0.9)
})
