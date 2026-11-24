# Assign each study player's country of birth from their birthplace coordinates.
#
# Uses Natural Earth Admin-0 "map units" (1:10m), which split the United Kingdom into
# England, Scotland, Wales and Northern Ireland. Points just off the coastline (common
# for coastal towns at this resolution) are snapped to the nearest unit within 10 km.
# English-born = birthplace inside England. Players without coordinates stay unassigned
# (see pipeline/players/05_geocode_fallback.py).
#
# Input:  data/processed/players_eligible.parquet
# Output: data/processed/players_eligible.parquet (adds birth-country columns)
#
# Usage (inside the app container): Rscript analysis/prepare/02_birth_country.R

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(arrow)
})
sf_use_s2(TRUE)

ne_dir <- "data/raw/naturalearth"
ne_zip <- file.path(ne_dir, "ne_10m_admin_0_map_units.zip")
ne_url <- paste0("https://naciscdn.org/naturalearth/10m/cultural/",
                 "ne_10m_admin_0_map_units.zip")
if (!file.exists(ne_zip)) {
  dir.create(ne_dir, recursive = TRUE, showWarnings = FALSE)
  download.file(ne_url, ne_zip, mode = "wb", quiet = TRUE)
}
units <- read_sf(paste0("/vsizip/", ne_zip)) |>
  transmute(birth_unit = GEOUNIT, birth_country = ADMIN, birth_iso3 = ADM0_A3) |>
  st_make_valid()

players <- read_parquet("data/processed/players_eligible.parquet") |>
  select(-any_of(c("birth_unit", "birth_country", "birth_iso3", "country_match",
                   "english_born")))
has_xy <- !is.na(players$lon) & !is.na(players$lat)
pts <- st_as_sf(players[has_xy, c("player_qid", "lon", "lat")],
                coords = c("lon", "lat"), crs = 4326)

inside <- st_join(pts, units, join = st_within, left = TRUE) |>
  distinct(player_qid, .keep_all = TRUE)
miss <- is.na(inside$birth_unit)
inside$country_match <- ifelse(miss, NA_character_, "within")
if (any(miss)) {
  near <- st_nearest_feature(inside[miss, ], units)
  dist_km <- as.numeric(st_distance(inside[miss, ], units[near, ],
                                    by_element = TRUE)) / 1000
  ok <- dist_km <= 10
  idx <- which(miss)
  inside$birth_unit[idx[ok]] <- units$birth_unit[near[ok]]
  inside$birth_country[idx[ok]] <- units$birth_country[near[ok]]
  inside$birth_iso3[idx[ok]] <- units$birth_iso3[near[ok]]
  inside$country_match[idx[ok]] <- "nearest <= 10 km"
  inside$country_match[idx[!ok]] <- "no unit within 10 km"
}

assigned <- st_drop_geometry(inside)
out <- players |>
  left_join(assigned, by = "player_qid") |>
  mutate(
    country_match = ifelse(is.na(lon) | is.na(lat), "no coordinates", country_match),
    english_born = !is.na(birth_unit) & birth_unit == "England"
  )

write_parquet(out, "data/processed/players_eligible.parquet")

cat("Country assignment:\n")
print(table(out$country_match, useNA = "ifany"))
cat(sprintf("English-born: %d of %d study players (%.1f%%)\n",
            sum(out$english_born), nrow(out), 100 * mean(out$english_born)))
cat("Top birth units:\n")
print(head(sort(table(out$birth_unit), decreasing = TRUE), 12))
