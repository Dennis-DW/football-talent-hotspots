# "World" page.

page_world <- function() {
  nav_panel(
    "World", icon = bs_icon("globe2"),
    div(class = "page-intro",
        h4("Players born outside England"),
        p(class = "note mb-0", bs_icon("info-circle"), " Descriptive only: players born abroad reflect recruitment by English clubs, ",
          "not how much talent each country produces.")),
    layout_column_wrap(
      width = "230px", fill = FALSE, class = "mb-3",
      kpi("flag-fill", "navy", w_n_countries, "Countries & UK nations", "outside England"),
      kpi("airplane-fill", "teal", fmt_int(w_outside), "Players born outside England",
          sprintf("%.0f%% of all %s players", 100 * w_outside / n_study, fmt_int(n_study))),
      kpi("trophy-fill", "gold", fmt_int(w_top$total), sprintf("Top supplier: %s", w_top$country),
          sprintf("%.0f%% of players born outside England", 100 * w_top$total / w_outside)),
      kpi("person-arms-up", "red", sprintf("%.0f", w_head$per_million), sprintf("Most per head: %s", w_head$country),
          "players per million people (≥10 players)")
    ),
    layout_columns(
      col_widths = c(8, 4),
      card(card_header(span("Where they were born"),
                       div(class = "d-flex gap-2 flex-wrap",
                           seg_group("wmeasure", NULL, c("Per million people" = "per_million", "Players" = "total"), "per_million"),
                           seg_group("wcohort", NULL, c("All" = "total", "1975–89" = "1975–1989", "1990–2005" = "1990–2005"), "total"))),
           leafletOutput("wmap", height = 470)),
      card(card_header("By continent", info("Share of players born outside England, by birth cohort.")),
           plotOutput("wcont", height = 300),
           p(class = "note mb-0", "Europe's share grew and Africa's fell between the two cohorts; Scotland, Wales and Northern Ireland supplied far fewer of the younger players."))
    ),
    layout_columns(
      col_widths = c(6, 6),
      card(card_header("Biggest rises", info("Change in players from the 1975–89 to the 1990–2005 birth cohort.")),
           change_rows(w_risers, TRUE)),
      card(card_header("Biggest falls", info("The 1990–2005 cohort is younger and still incomplete, so some falls partly reflect players not yet recorded.")),
           change_rows(w_fallers, FALSE))
    ),
    card(card_header(span("All countries", span(class = "hint", " — click a row to zoom the map")),
                     div(class = "d-flex gap-2 align-items-center",
                         selectInput("wcontinent", NULL, c("All continents" = "all", W_GROUPS), width = "220px"),
                         downloadButton("dl_world", "CSV", class = "btn-sm btn-outline-secondary"))),
         reactableOutput("wtable"),
         p(class = "note mt-2 mb-0", "Per million = players per million people (mean national population 1975–2005). ",
           "Countries with fewer than 10 players are greyed: their rates rest on very few players. ",
           "Northern Ireland has no population figure."))
  )
}
