# "Overview" page.

page_overview <- function() {
  nav_panel(
    "Overview", icon = bs_icon("house"),
    div(class = "hero",
        h1("Where do England's top footballers come from?"),
        p(class = "lead", "Some places produce far more Premier League and Championship players than the number of boys born there ",
          "would predict. This dashboard maps where — and tests why."),
        actionButton("go_map", tagList(bs_icon("map"), " Explore the map"), class = "btn-gold"),
        actionButton("go_why", tagList(bs_icon("lightbulb"), " Why it happens"), class = "btn-outline-primary"),
        div(class = "meta", span(sprintf("%s players", fmt_int(n_study))), span("Born 1975–2005"),
            span("Premier League & Championship, 1992/93–2025/26"), span("155 Travel to Work Areas"))),
    layout_column_wrap(
      width = "230px", fill = FALSE, class = "mb-3",
      kpi("people-fill", "navy", fmt_int(n_study), "Players studied", "men with ≥1 PL or 2nd-tier league game"),
      kpi("geo-alt-fill", "teal", fmt_int(n_england), "Born in England", sprintf("%.0f%% of all players", 100 * n_england / n_study)),
      kpi("bar-chart-fill", "gold", sprintf("%.1f×", ratio_ns), "Best vs. worst region", "players per birth, London vs. South West"),
      kpi("signpost-split-fill", "red", sprintf("−%.0f%%", dist_pct), "Per 10 km from a club", "fewer players than births predict")
    ),
    layout_columns(
      col_widths = c(7, 5),
      card(card_header("Players relative to births",
                       info("Smoothed standardised ratio by Travel to Work Area: red = more players than births predict, blue = fewer.")),
           leafletOutput("ov_map", height = 470)),
      div(class = "finding-grid",
          finding("compass", "navy", "A north-west belt",
                  "Merseyside, Lancashire, Greater Manchester, South Yorkshire, the North East and London produce the most players per birth.",
                  "go_map2", "Explore the map"),
          finding("signpost-split", "red", "Clubs nearby matter",
                  sprintf("About %.0f%% fewer players for every extra 10 km to a professional club — more so since 1990.", dist_pct),
                  "go_why2", "See the evidence"),
          finding("mortarboard", "gold", "Not elite academies",
                  "Distance to a Category 1 academy, deprivation and urbanisation do not explain the pattern once region is included.",
                  "go_why3", "Model results"),
          finding("globe2", "teal", "Half born abroad",
                  "About half the players were born outside England; Ireland, Scotland, Wales and Iceland supply the most per head.",
                  "go_world", "World view"))
    ),
    layout_columns(
      col_widths = c(4, 4, 4),
      card(card_header("Highest and lowest areas", info("Smoothed players-vs-births ratio, Travel to Work Areas expecting at least 5 players.")),
           div(class = "glance-sub", "Most players per birth"), glance_rows(ov_top, "#d6604d"),
           div(class = "glance-sub", "Fewest players per birth"), glance_rows(ov_bottom, "#4393c3")),
      card(card_header("By region", info("Players per 10,000 boys born, 1975–2005.")),
           tags$ul(class = "glance-list", lapply(order(-reg$per_10k_births), function(i) tags$li(
             span(class = "rk", if (reg$p_value[i] < 0.05) "✓" else ""), span(reg$region[i]),
             plain_bar(reg$per_10k_births[i], 5, if (reg$SR[i] > 1) "#d6604d" else "#4393c3", digits = 2)))),
           p(class = "note mt-2 mb-0", sprintf("✓ = significantly different from the England average (%.2f).", sum(reg$players) / sum(reg$births) * 1e4))),
      card(card_header("How it works"),
           tags$ol(class = "steps",
                   tags$li(strong("Find the players"), "Men born 1975–2005 with a Premier League or second-tier league appearance, and their birthplaces (Wikidata, Wikipedia)."),
                   tags$li(strong("Set the baseline"), "Count the boys born in every area in the same years (ONS) to work out how many players each area would produce if talent were spread evenly."),
                   tags$li(strong("Compare and test"), "Players ÷ expected = the ratio on the map. Spatial statistics test where areas cluster and models test why.")),
           p(class = "note mb-0", bs_icon("question-circle"), " More detail: Guide (top bar) and About."))
    )
  )
}
