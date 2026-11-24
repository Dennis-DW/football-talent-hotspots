# "Patterns" page.

page_patterns <- function() {
  nav_panel(
    "Patterns", icon = bs_icon("diagram-3"),
    div(class = "page-intro",
        h4("Is football talent clustered?"),
        p(class = "note mb-0", bs_icon("info-circle"), " Do players come from some places more than births alone would predict, and do those places ",
          "sit together? Results for all players; the Map Explorer filters do not change them.")),
    layout_column_wrap(
      width = "230px", fill = FALSE, class = "mb-3",
      kpi("bar-chart-fill", "gold", sprintf("%.1f×", ratio_ns), "Best vs. worst region", "players per birth, London vs. South West"),
      kpi("check2-circle", "navy", sprintf("%d of %d", p_n_sig, nrow(reg)), "Regions differ significantly", "from the England average"),
      kpi("diagram-3-fill", "teal", sprintf("%.2f", p_moran$EB_Moran_I), "Areas cluster (Moran's I)",
          sprintf("p = %.3f · neighbouring areas are alike", p_moran$p_value)),
      kpi("bullseye", "red", sprintf("p = %.2f", p_dclf$p_value), "Bunching beyond births", "players closer together than births predict")
    ),
    layout_columns(
      col_widths = c(6, 6),
      card(card_header("Region by region", info("Players per 10,000 boys born 1975–2005; exact Poisson test of observed vs. expected.")),
           reactableOutput("region_tbl"),
           p(class = "note mt-2 mb-0", sprintf("England average: %.2f players per 10,000 boys born.", sum(reg$players) / sum(reg$births) * 1e4))),
      card(card_header("Where players exceed births", info("Kernel-smoothed player density ÷ births density (15 km). Exploratory — no significance test.")),
           leafletOutput("rrmap", height = 430))
    ),
    layout_columns(
      col_widths = c(7, 5),
      card(card_header("Where areas cluster (Getis-Ord Gi*)",
                       info("Travel to Work Areas that, together with their neighbours, are unusually high or low; 9,999 permutations, false-discovery-rate corrected.")),
           layout_columns(col_widths = c(6, 6),
                          div(div(class = "glance-sub", bs_icon("arrow-up-circle"), " Hot clusters"), cluster_rows(p_hot)),
                          div(div(class = "glance-sub", bs_icon("arrow-down-circle"), " Cold clusters"), cluster_rows(p_cold))),
           p(class = "note mt-2 mb-0", "No single area passes the strictest test (FDR q < 0.05): the evidence is for a broad north-west / south-east ",
             "pattern rather than sharp local hotspots. Gi* scores neighbourhoods, so Liverpool — the highest single area — is not listed: ",
             "its neighbours are mixed. Warrington & Wigan sits between Liverpool, Manchester and Preston.")),
      card(card_header("Does it depend on scale?", info("Global EB Moran's I (999 permutations) for different area types and neighbour definitions.")),
           reactableOutput("scale_tbl"),
           p(class = "note mt-2 mb-0", "Clustering is strong for Travel to Work Areas and weak for local authorities and hexagons — ",
             "local authorities are distorted by the maternity-hospital effect, hexagons by small numbers."))
    ),
    card(card_header("Are birthplaces more bunched together than births?",
                     info("Inhomogeneous L-function with births as background; 999 births-only simulations.")),
         layout_columns(col_widths = c(8, 4),
                        plotOutput("lplot", height = 320),
                        div(class = "reading",
                            tags$ul(
                              tags$li("The ", strong("red line"), " shows how much closer together players' birthplaces are than births would make them."),
                              tags$li("The ", strong("grey band"), " is the range expected if players simply followed births (999 simulations)."),
                              tags$li("The line stays ", strong("above zero at every distance"), sprintf(": modest but significant bunching (p = %.2f).", p_dclf$p_value)),
                              tags$li("A check with fake players placed by births alone finds ", strong("no bunching"), " (p ≈ 0.5), so the method is not biased.")))),
         accordion(open = FALSE, accordion_panel("Technical details: global tests", reactableOutput("tests_tbl"))))
  )
}
