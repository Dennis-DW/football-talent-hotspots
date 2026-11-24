# Download buttons.
# Sourced inside server() with local = TRUE, so it shares input, output, session and the reactives.

output$dl_players <- downloadHandler(
  filename = function() "players.csv",
  content = function(f) write.csv(players |> select(-fine), f, row.names = FALSE)
)
output$dl_areas <- downloadHandler(
  filename = function() "area_results_all_players.csv",
  content = function(f) {
    out <- lapply(names(units), function(l) st_drop_geometry(units[[l]]) |>
                    left_join(compute_sr(l, players, YEARS), by = "unit") |> mutate(level = l))
    write.csv(bind_rows(out), f, row.names = FALSE)
  }
)
