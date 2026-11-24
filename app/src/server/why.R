# "Why?" page outputs.
# Sourced inside server() with local = TRUE, so it shares input, output, session and the reactives.

output$why_main <- renderPlot({
  d <- tabs$rr |> filter(model %in% c("TTWA: no region (M1)", "TTWA: main (M2)")) |>
    mutate(term = factor(lab_terms[term], rev(lab_terms)),
           model = factor(ifelse(model == "TTWA: main (M2)", "With region effects (main)", "Without region effects"),
                          c("Without region effects", "With region effects (main)")),
           lab = sprintf("%+.0f%%", (RR - 1) * 100))
  pd <- position_dodge(width = 0.55)
  ggplot(d, aes(RR, term, colour = model)) + geom_vline(xintercept = 1, linetype = 2, colour = "grey55") +
    geom_errorbar(aes(xmin = lo, xmax = hi), width = 0.18, orientation = "y", linewidth = 0.8, position = pd) +
    geom_point(size = 3.6, position = pd) +
    geom_text(aes(label = lab), position = pd, vjust = -1.1, size = 3.6, show.legend = FALSE) +
    scale_colour_manual(values = c("Without region effects" = "grey60", "With region effects (main)" = "#1f3a5f"), name = NULL) +
    scale_x_continuous(labels = function(x) sprintf("%+.0f%%", (x - 1) * 100)) +
    labs(x = "Change in players produced (95% CI)", y = NULL) + theme_dash(13) +
    theme(legend.position = "top", legend.justification = "left")
})
output$regfx <- renderPlot({
  d <- tabs$region_fx |> bind_rows(tibble(term = "West Midlands (reference)", RR = 1)) |>
    mutate(lab = ifelse(term == "West Midlands (reference)", "reference", sprintf("%+.0f%%", (RR - 1) * 100)))
  ggplot(d, aes(RR - 1, reorder(term, RR), fill = RR > 1)) + geom_col(width = 0.7) +
    geom_vline(xintercept = 0, colour = "grey30") +
    geom_text(aes(label = lab, hjust = ifelse(RR >= 1, -0.15, 1.15)), size = 3.6) +
    scale_fill_manual(values = c(`TRUE` = "#ef8a62", `FALSE` = "#67a9cf"), guide = "none") +
    scale_x_continuous(labels = function(x) sprintf("%+.0f%%", 100 * x), expand = expansion(mult = 0.25)) +
    labs(x = "Players per birth vs. the West Midlands", y = NULL) + theme_dash(12)
})
output$scatter <- renderPlot({
  d <- tabs$model_data
  lab <- d |> filter(name %in% c("Liverpool", "London", "Sheffield", "Manchester", "Guildford and Aldershot",
                                 "Crawley", "Isle of Wight", "Penzance", "Barnsley", "Doncaster"))
  ggplot(d, aes(dist_club_km, SR_EB)) +
    geom_hline(yintercept = 1, linetype = 2, colour = "grey60") +
    geom_smooth(method = "lm", formula = y ~ x, colour = "#1f3a5f", fill = "#c9d6e6", linewidth = 0.9) +
    geom_point(aes(colour = SR_EB > 1), alpha = 0.8, size = 2.2) +
    geom_text(data = lab, aes(label = name), size = 3.2, hjust = -0.12, vjust = 0.4, check_overlap = TRUE, colour = "grey25") +
    scale_colour_manual(values = c(`TRUE` = "#d6604d", `FALSE` = "#4393c3"), guide = "none") +
    scale_y_log10(labels = function(x) sprintf("%.1f×", x)) +
    scale_x_continuous(expand = expansion(mult = c(0.02, 0.14))) +
    labs(x = "Distance to the nearest professional club at age 12 (km)", y = "Players vs. births (smoothed)") + theme_dash(12)
})
output$robust_plot <- renderPlot({
  d <- tabs$rr |> filter(term == "dist10") |>
    mutate(label = factor(ROBUST_LABELS[model], rev(ROBUST_LABELS)),
           main = model == "TTWA: main (M2)", sig = p < 0.05,
           lab = sprintf("%+.0f%%", (RR - 1) * 100))
  ggplot(d, aes(RR, label)) + geom_vline(xintercept = 1, linetype = 2, colour = "grey55") +
    geom_errorbar(aes(xmin = lo, xmax = hi, colour = main), width = 0.25, orientation = "y", linewidth = 0.7) +
    geom_point(aes(colour = main, shape = sig), size = 3.2) +
    geom_text(aes(x = hi, label = lab), hjust = -0.25, size = 3.4, colour = "grey30") +
    scale_colour_manual(values = c(`TRUE` = "#b2182b", `FALSE` = "#1f3a5f"), guide = "none") +
    scale_shape_manual(values = c(`TRUE` = 16, `FALSE` = 1), labels = c(`TRUE` = "significant", `FALSE` = "not significant"), name = NULL) +
    scale_x_continuous(labels = function(x) sprintf("%+.0f%%", (x - 1) * 100), expand = expansion(mult = c(0.05, 0.15))) +
    labs(x = "Change in players per extra 10 km to a club (95% CI)", y = NULL) + theme_dash(12) +
    theme(legend.position = "top", legend.justification = "left")
})
output$model_tbl <- renderReactable({
  d <- tabs$rr |> transmute(Factor = unname(lab_terms[term]), Model = model, Effect = effect_words(term, RR),
                            CI = sprintf("%.2f – %.2f", lo, hi), RR, p)
  reactable(d, compact = TRUE, highlight = TRUE, groupBy = "Factor", defaultExpanded = TRUE, defaultPageSize = 40,
            columns = list(Factor = colDef(minWidth = 200), Model = colDef(minWidth = 220),
                           Effect = colDef("Effect", minWidth = 150), CI = colDef("95% CI (rate ratio)", minWidth = 130),
                           RR = colDef("Rate ratio", format = colFormat(digits = 3), width = 95),
                           p = colDef("Significant?", width = 105, cell = sig_tag)))
})
