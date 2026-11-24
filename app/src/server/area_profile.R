# Map Explorer: area profile.
# Sourced inside server() with local = TRUE, so it shares input, output, session and the reactives.

output$area_panel <- renderUI({
  d <- st_drop_geometry(sr())
  id <- selected()
  if (is.null(id) || !id %in% d$unit) {
    top <- d |> filter(E >= 3) |> arrange(desc(SR_EB)) |> head(5)
    return(tagList(
      div(class = "empty-profile", bs_icon("hand-index-thumb", size = "1.6rem"),
          p(strong("Click an area"), br(), span(class = "note", "on the map or in the ranking table to see its profile."))),
      div(class = "glance-sub", "Highest smoothed ratio"),
      tags$ul(class = "glance-list", lapply(seq_len(nrow(top)), function(i) tags$li(
        span(class = "rk", i), actionLink(paste0("pick_", i), top$name[i]),
        plain_bar(top$SR_EB[i], 2.5, "#d6604d", digits = 2))))
    ))
  }
  a <- d[d$unit == id, ]
  rk <- ranked()$rank[ranked()$unit == id]
  pl <- sel()
  if (level() != "ttwa") pl <- pl[pl$fine, ]
  pl <- pl[!is.na(pl[[level()]]) & pl[[level()]] == id, ]
  pl <- pl[order(pl$birth_year), ]
  pctile <- function(x, v) round(100 * mean(x <= v, na.rm = TRUE))
  ratio_cls <- if (is.na(a$SR)) "" else if (a$SR >= 1) "up-big" else "down-big"
  dec <- table(factor(paste0(pl$birth_year %/% 10 * 10, "s"), levels = c("1970s", "1980s", "1990s", "2000s")))
  hot_txt <- switch(GI_TAG[[a$gi_class]],
                    hot2 = "Part of a significant hot cluster", hot1 = "Part of a hot cluster (weak evidence)",
                    hot0 = "In a hot cluster (exploratory)", cold2 = "Part of a significant cold cluster",
                    cold1 = "Part of a cold cluster (weak evidence)", cold0 = "In a cold cluster (exploratory)",
                    none = "Not part of a significant cluster")
  tagList(
    div(class = "d-flex justify-content-between align-items-start",
        div(p(class = "area-title", a$name),
            div(class = "d-flex gap-1 flex-wrap mb-2",
                if (!is.na(a$region)) span(class = "chip", short_region(a$region)),
                span(class = "chip chip-dark", sprintf("#%d of %d", rk, nrow(d))))),
        actionLink("clear_area", bs_icon("x-lg"), title = "Back to England")),
    div(class = "ratio-big", span(class = ratio_cls, sprintf("%.2f×", a$SR)), span(class = "note", " expected")),
    div(class = "stats stats-3",
        div(class = "stat", div(class = "v", fmt_int(a$O)), div(class = "l", "Players")),
        div(class = "stat", div(class = "v", sprintf("%.1f", a$E)), div(class = "l", "Expected")),
        div(class = "stat", div(class = "v", sprintf("%.2f", a$SR_EB)), div(class = "l", "Smoothed"))),
    div(class = "hot-line", tag_span(GI_TAG[[a$gi_class]], if (a$gi_class == "Not significant") "No cluster" else GI_SHORT[[a$gi_class]]),
        span(hot_txt)),
    if (!is.na(a$imd_score)) tagList(
      div(class = "glance-sub", "Compared with all ", LEVEL_NOUN[[level()]]),
      pct_bar("Deprivation", sprintf("%.1f", a$imd_score), pctile(d$imd_score, a$imd_score),
              sprintf("more deprived than %d%% of areas", pctile(d$imd_score, a$imd_score))),
      pct_bar("Urban population", sprintf("%.0f%%", 100 * a$urban_share), pctile(d$urban_share, a$urban_share),
              sprintf("more urban than %d%% of areas", pctile(d$urban_share, a$urban_share))),
      pct_bar("Nearest club at age 12", sprintf("%.1f km", a$dist_club_km), 100 - pctile(d$dist_club_km, a$dist_club_km),
              sprintf("closer than %d%% of areas", 100 - pctile(d$dist_club_km, a$dist_club_km)))
    ),
    if (nrow(pl)) tagList(
      div(class = "glance-sub", "Players by birth decade"),
      tags$ul(class = "glance-list", lapply(names(dec), function(k) tags$li(
        span(class = "rk", ""), span(k), plain_bar(as.numeric(dec[[k]]), max(dec), "#1f3a5f", digits = 0))))
    ),
    div(class = "glance-sub d-flex justify-content-between",
        span(sprintf("Players born here (%d)", nrow(pl))), span(sprintf("%d Premier League", sum(pl$premier_league)))),
    if (nrow(pl)) reactable(
      data.frame(Player = sprintf("<a href='https://www.wikidata.org/wiki/%s' target='_blank'>%s</a>", pl$player_qid, htmlEscape(pl$label)),
                 Born = pl$birth_year, Pos = coalesce(names(POSITIONS)[match(pl$position, POSITIONS)], "—"),
                 PL = pl$premier_league),
      compact = TRUE, searchable = nrow(pl) > 8, defaultPageSize = 8, borderless = TRUE,
      theme = reactableTheme(headerStyle = HEADER_STYLE),
      columns = list(Player = colDef(html = TRUE, minWidth = 140), Born = colDef(width = 55), Pos = colDef(width = 45),
                     PL = colDef("", width = 40, cell = function(v) if (v) tag_span("pl", "PL") else ""))
    ) else p(class = "note", "None with the current filters.")
  )
})
# quick links in the empty profile
lapply(1:5, function(i) observeEvent(input[[paste0("pick_", i)]], {
  d <- st_drop_geometry(sr()) |> filter(E >= 3) |> arrange(desc(SR_EB)) |> head(5)
  if (i <= nrow(d)) {
    selected(d$unit[i])
    bb <- st_bbox(sr()[sr()$unit == d$unit[i], ])
    leafletProxy("map") |> flyToBounds(bb[["xmin"]], bb[["ymin"]], bb[["xmax"]], bb[["ymax"]], options = list(maxZoom = 9))
  }
}))
observeEvent(input$clear_area, {
  selected(NULL)
  leafletProxy("map") |> england_view()
})
