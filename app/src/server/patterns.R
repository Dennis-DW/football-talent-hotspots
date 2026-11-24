# Patterns page outputs.
# Sourced inside server() with local = TRUE, so it shares input, output, session and the reactives.

output$region_tbl <- renderReactable({
  d <- reg |> arrange(desc(per_10k_births)) |>
    transmute(region, players, expected = E, per_10k_births, SR, p_value)
  reactable(
    d, compact = TRUE, highlight = TRUE, pagination = FALSE,
    theme = reactableTheme(headerStyle = list(fontSize = ".78rem", textTransform = "uppercase", letterSpacing = ".03em",
                                              color = "var(--bs-secondary-color)")),
    columns = list(
      region = colDef("Region", minWidth = 125, style = list(fontWeight = 600)),
      players = colDef("Players", width = 70, align = "right"),
      expected = colDef(width = 55, align = "right", format = colFormat(digits = 0),
                        header = with_tooltip("Exp.", "Players expected from the number of boys born.")),
      per_10k_births = colDef(minWidth = 125, header = with_tooltip("Per 10k births", "Players per 10,000 boys born, 1975–2005."),
                              cell = function(v, i) plain_bar(v, 5, if (d$SR[i] > 1) "#d6604d" else "#4393c3", digits = 2)),
      SR = colDef(minWidth = 120, cell = sr_bar, header = with_tooltip("vs. expected", "Observed ÷ expected; the centre line is 1 = as expected.")),
      p_value = colDef(width = 55, align = "center", cell = sig_tag,
                       header = with_tooltip("Sig.", "Significantly different from the England average (exact Poisson test, p < 0.05)."))
    )
  )
})
output$scale_tbl <- renderReactable({
  lv <- c(ttwa = "Travel to Work Areas", lad21 = "Local authorities", hex20 = "20 km hexagons")
  nb <- c(queen = "Shared border", knn6 = "6 nearest", knn4 = "4 nearest", knn8 = "8 nearest")
  d <- tabs$global |> transmute(Areas = sprintf("%s (%d)", lv[level], units), Neighbours = nb[weights], I = EB_Moran_I, p_value)
  first <- !duplicated(d$Areas)
  reactable(d, compact = TRUE, pagination = FALSE, sortable = FALSE,
            rowStyle = function(i) if (first[i] && i > 1) list(borderTop = "2px solid var(--bs-border-color)"),
            columns = list(
              Areas = colDef("Areas", minWidth = 170, cell = function(v, i) if (first[i]) strong(v) else ""),
              Neighbours = colDef("Neighbours", minWidth = 105),
              I = colDef("Moran's I", minWidth = 120, cell = function(v) plain_bar(v, 0.3, "#1f7a7f", digits = 3)),
              p_value = colDef("Sig.", width = 55, align = "center", cell = sig_tag)))
})
output$rrmap <- renderLeaflet({
  v <- clamp(log2(rr_rast), -2, 2)
  pal <- colorNumeric(SR_COLS, domain = c(-2, 2), na.color = "transparent")
  leaflet(options = leafletOptions(minZoom = 5)) |> base_tiles() |> england_view() |>
    addRasterImage(v, colors = pal, opacity = 0.75, project = TRUE) |>
    addLegend("bottomright", colors = pal(c(2, 1, 0, -1, -2)), labels = c("4×+", "2×", "as births", "half", "¼ or less"),
              title = "Players vs. births", opacity = 0.9)
})
output$lplot <- renderPlot({
  e <- tabs$lenv
  ggplot(e, aes(r_km)) + geom_ribbon(aes(ymin = lo - r_km, ymax = hi - r_km), fill = "grey88") +
    geom_hline(yintercept = 0, linetype = 2, colour = "grey45") +
    geom_line(aes(y = L_obs - r_km), colour = "#b2182b", linewidth = 1.2) +
    annotate("text", x = 40, y = min(e$lo - e$r_km, na.rm = TRUE) * 0.7, label = "95% range if players followed births",
             colour = "grey35", size = 4) +
    annotate("text", x = 30, y = max(e$L_obs - e$r_km, na.rm = TRUE) + 1, label = "players", colour = "#b2182b",
             fontface = "bold", size = 4.2) +
    annotate("text", x = 58, y = 0.6, label = "no extra bunching", colour = "grey40", size = 3.5, hjust = 1) +
    labs(x = "Distance (km)", y = "Extra bunching (km)") + theme_dash(13)
})
output$tests_tbl <- renderReactable({
  d <- tabs$ltests |> transmute(
    Test = sprintf("%s, %s km", ifelse(pattern == "players", "Clustering test", "Null check (births-only fake players)"), r_range_km),
    Method = test, `p-value` = p_value, Simulations = nsim, Significant = p_value)
  reactable(d, compact = TRUE, borderless = TRUE,
            columns = list(Test = colDef(minWidth = 260), `p-value` = colDef(format = colFormat(digits = 3)),
                           Significant = colDef(cell = sig_tag)))
})
