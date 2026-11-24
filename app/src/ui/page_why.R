# "Why?" page.

page_why <- function() {
  nav_panel(
    "Why?", icon = bs_icon("lightbulb"),
    div(class = "page-intro",
        h4("What explains where players come from?"),
        p(class = "note mb-0", bs_icon("info-circle"), " Statistical models of player production in the 155 Travel to Work Areas (negative binomial, ",
          "with expected players from births as the baseline). Results for all players; the Map Explorer filters do not change them.")),
    layout_column_wrap(
      width = "230px", fill = FALSE, class = "mb-3",
      kpi("signpost-split-fill", "red", sprintf("−%.0f%%", dist_pct), "Per 10 km from a club", "fewer players than births predict"),
      kpi("graph-down-arrow", "navy", pct_txt(y_club_young$RR), "Born 1996–2005", "per 10 km from a club — a stronger effect"),
      kpi("mortarboard-fill", "gold", pct_txt(y_acad$RR), "Elite academy distance", "no effect once any club is nearby"),
      kpi("compass-fill", "teal", pct_txt(y_nw$RR), "North West vs. West Midlands", "same deprivation, urbanisation and distance")
    ),
    layout_columns(
      col_widths = c(7, 5),
      card(card_header("Effect of each factor", info("Change in players produced, with 95% confidence intervals. Grey: model without region effects; navy: main model with region effects.")),
           plotOutput("why_main", height = 300)),
      card(card_header("In plain words"),
           verdict("signpost-split", "Distance to a club", "yes", "Clear effect",
                   sprintf("Each extra 10 km to the nearest professional club at age 12 means about %.0f%% fewer players — in every robustness check.", dist_pct)),
           verdict("cash-coin", "Deprivation", "no", "Proxy for region",
                   sprintf("Looks positive on its own (%s per 10 IMD points) but disappears once region is included (%s): deprived areas are mostly in the North.",
                           pct_txt(y_m1_imd$RR), pct_txt(y_m2_imd$RR))),
           verdict("buildings", "Urban share", "no", "No effect",
                   sprintf("%s per 10 percentage points, not significant.", pct_txt(y_m2_urb$RR))),
           verdict("compass", "Region", "yes", "Strong effect",
                   "The North West and North East produce about 39% more players per birth than the West Midlands; the South East and South West about 22% fewer."))
    ),
    layout_columns(
      col_widths = c(5, 7),
      card(card_header("Region effects", info("Rate ratio vs. the West Midlands, after deprivation, urbanisation and club distance.")),
           plotOutput("regfx", height = 330)),
      card(card_header("Distance to a club vs. production", info("Each dot is a Travel to Work Area; the line is the overall trend.")),
           plotOutput("scatter", height = 330))
    ),
    layout_columns(
      col_widths = c(5, 7),
      card(card_header("Any club or an elite academy?", info("Players born 1996–2005 (aged 16 or under when the Elite Player Performance Plan began in 2012/13); 594 players.")),
           div(class = "versus",
               div(class = "vs-panel vs-yes",
                   div(class = "vs-label", bs_icon("geo-alt-fill"), " Any professional club"),
                   div(class = "vs-value", pct_txt(y_club_young$RR)), div(class = "vs-sub", "per 10 km"),
                   tag_span("yes", sprintf("significant · p = %.4f", y_club_young$p))),
               div(class = "vs-or", "vs"),
               div(class = "vs-panel vs-no",
                   div(class = "vs-label", bs_icon("mortarboard-fill"), " Category 1 academy"),
                   div(class = "vs-value", pct_txt(y_acad$RR)), div(class = "vs-sub", "per 10 km"),
                   tag_span("no", sprintf("no effect · p = %.2f", y_acad$p)))),
           p(class = "note mt-3 mb-0", "Even after the elite academy system began, what predicts reaching the top two divisions is having ",
             "a professional club nearby — consistent with boys joining their local club first and moving on later.")),
      card(card_header("Is the club effect robust?", info("The distance-to-club rate ratio (+10 km) when the main model is refitted to different players, baselines and areas.")),
           plotOutput("robust_plot", height = 330))
    ),
    accordion(open = FALSE, class = "mb-3",
              accordion_panel("All model results (every factor, every check)", icon = bs_icon("table"), reactableOutput("model_tbl"))),
    div(class = "alert alert-light border note", bs_icon("exclamation-triangle"),
        " These are associations between areas, not proof of cause: club locations also reflect where population and industry were, ",
        "and region effects capture football culture and history that are not measured.")
  )
}
