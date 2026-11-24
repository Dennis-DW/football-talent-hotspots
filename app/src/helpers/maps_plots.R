# Map colours, base maps and the ggplot theme.

sr_pal <- colorNumeric(SR_COLS, domain = c(-2, 2), na.color = "#dddddd")

# Background maps that need no API key: Esri Light Gray Canvas (default) and OpenStreetMap
base_tiles <- function(map) {
  map |>
    addProviderTiles(providers$Esri.WorldGrayCanvas, group = "Light grey") |>
    addTiles(group = "OpenStreetMap") |>
    addLayersControl(baseGroups = c("Light grey", "OpenStreetMap"),
                     position = "topright", options = layersControlOptions(collapsed = TRUE))
}
england_view <- function(map) setView(map, -1.9, 52.8, 6)

theme_dash <- function(base = 12) {
  theme_minimal(base_size = base) +
    theme(panel.grid.minor = element_blank(), plot.title.position = "plot",
          axis.title = element_text(colour = "grey35"), strip.text = element_text(face = "bold", hjust = 0))
}
