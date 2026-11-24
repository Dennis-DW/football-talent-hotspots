# "Map Explorer" page.

page_map_explorer <- function() {
  nav_panel(
    "Map Explorer", icon = bs_icon("map"),
    layout_sidebar(
      sidebar = explorer_sidebar, fillable = FALSE,
      div(class = "page-intro mt-0",
          h4("Explore where players were born"),
          p(class = "note mb-0", "Colour shows players born in each area compared with the number expected from boys born there. ",
            "Use the filters to focus on a group of players; click an area for its profile.")),
      uiOutput("me_kpis"),
      layout_columns(
        col_widths = c(8, 4),
        card(full_screen = TRUE,
             card_header(uiOutput("map_title", inline = TRUE),
                         info("Hover an area for its numbers; click it to open the area profile. The ⟲ button returns to England.")),
             leafletOutput("map", height = 600)),
        card(card_header("Area profile", info("Click an area on the map or a row in the table.")),
             div(style = "max-height:600px; overflow-y:auto;", uiOutput("area_panel")))
      ),
      card(card_header(span("Area ranking", span(class = "hint", " — click a row to zoom to the area")),
                       div(class = "d-flex gap-2 align-items-center flex-wrap",
                           seg_group("rank_filter", NULL, c("All" = "all", "Above expected" = "above", "Below expected" = "below"), "all"),
                           selectInput("rank_region", NULL, c("All regions" = "all"), width = "190px"),
                           downloadButton("dl_rank", "CSV", class = "btn-sm btn-outline-secondary"))),
           reactableOutput("rank_table"))
    )
  )
}
