# Step 8: prepare compact data for the Shiny dashboard (app/data/*.rds).
#
# Geometries are simplified (in EPSG:27700) and transformed to EPSG:4326 for Leaflet.
# Births by unit and year are stored so the app can recompute observed / expected counts
# for any filter (birth years, Premier League only, certain evidence only, position).
#
# Usage (inside the app container): Rscript analysis/dashboard/09_app_data.R

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
  library(arrow)
  library(spatstat)
  library(terra, exclude = c("rescale", "density", "area", "shift", "rotate", "flip", "union", "intersect"))
})
dir.create("app/data", showWarnings = FALSE, recursive = TRUE)
simp <- function(x, tol) st_simplify(x, dTolerance = tol, preserveTopology = TRUE) |> st_transform(4326)

# --- units ---------------------------------------------------------------------------
lad <- read_sf("data/processed/lad21_england.gpkg") |> transmute(unit = lad21cd, name = lad21nm)
ttwa <- read_sf("data/processed/ttwa11_england.gpkg") |> transmute(unit = ttwa_id, name = ttwa_nm)
hex <- read_sf("data/processed/hex20_england.gpkg") |> transmute(unit = hex_id, name = hex_id)
res <- function(level, w) read_csv(sprintf("data/processed/step6_%s_%s.csv", level, w), show_col_types = FALSE) |>
  select(unit, Gi_z, Gi_p, Gi_q, Gi_q_norm, gi_class, lisa_class)
# area profile: region and covariates (TTWA region = region holding most of its population)
latest <- function(pattern, dir) tail(sort(list.files(dir, pattern, full.names = TRUE)), 1)
lad_region <- read_csv(latest("^lad21_rgn21_lookup_.*csv$", "data/raw/ons"), show_col_types = FALSE) |>
  transmute(unit = LAD21CD, region = RGN21NM)
prof_lad <- read_csv("data/processed/lad21_covariates.csv", show_col_types = FALSE) |>
  transmute(unit = lad21cd, imd_score, urban_share, dist_club_km) |> left_join(lad_region, by = "unit")
prof_ttwa <- read_csv("data/processed/ttwa_covariates.csv", show_col_types = FALSE) |>
  transmute(unit = ttwa_id, imd_score, urban_share, dist_club_km) |>
  left_join(read_csv("data/processed/step7_model_data_ttwa.csv", show_col_types = FALSE) |>
              select(unit, region), by = "unit")
units <- list(
  ttwa = simp(ttwa, 300) |> left_join(res("ttwa", "queen"), by = "unit") |> left_join(prof_ttwa, by = "unit"),
  lad21 = simp(lad, 200) |> left_join(res("lad21", "queen"), by = "unit") |> left_join(prof_lad, by = "unit"),
  hex20 = st_transform(hex, 4326) |> left_join(res("hex20", "knn6"), by = "unit") |>
    mutate(imd_score = NA_real_, urban_share = NA_real_, dist_club_km = NA_real_, region = NA_character_)
)
saveRDS(units, "app/data/units.rds")

# --- births by unit and year (for live O/E) --------------------------------------------
lsoa <- read_csv("data/processed/lsoa21_england.csv", show_col_types = FALSE)
births <- read_csv("data/processed/births_lad_year.csv", show_col_types = FALSE)
hexmap <- read_csv("data/processed/player_units.csv", show_col_types = FALSE)  # (players only)
hex_pts <- st_as_sf(lsoa, coords = c("bng_e", "bng_n"), crs = 27700)
lsoa$hex20 <- hex$unit[sapply(st_intersects(hex_pts, hex), function(i) if (length(i)) i[1] else NA)]
bl <- lsoa |> group_by(lad21cd) |> mutate(w = pop2022 / sum(pop2022)) |> ungroup() |>
  inner_join(births |> select(lad21cd, birth_year, births_male), by = "lad21cd", relationship = "many-to-many") |>
  mutate(b = births_male * w)
bu <- bind_rows(
  births |> transmute(level = "lad21", unit = lad21cd, birth_year, b = births_male),
  bl |> group_by(level = "ttwa", unit = ttwa, birth_year) |> summarise(b = sum(b), .groups = "drop"),
  bl |> filter(!is.na(hex20)) |> group_by(level = "hex20", unit = hex20, birth_year) |>
    summarise(b = sum(b), .groups = "drop")
)
saveRDS(bu, "app/data/births_unit_year.rds")

# --- players ---------------------------------------------------------------------------
pe <- read_parquet("data/processed/players_eligible.parquet")
pos_group <- function(s) {
  if (is.na(s) || s == "") return(NA_character_)
  l <- tolower(strsplit(s, "\\|")[[1]])
  score <- c(
    Goalkeeper = sum(grepl("goalkeeper", l)),
    Defender = sum(grepl("defender|full-back|centre-back|wing-back|sweeper|libero", l)),
    Midfielder = sum(grepl("midfielder|wing half|playmaker", l)),
    Forward = sum(grepl("forward|striker|winger", l))
  )
  if (all(score == 0)) NA_character_ else names(which.max(score))
}
pu <- read_csv("data/processed/player_units.csv", show_col_types = FALSE)
players <- pu |>
  left_join(pe |> select(player_qid, positions, place_label, status_pe = status), by = "player_qid") |>
  mutate(position = vapply(positions, pos_group, ""),
         hex20 = hex$unit[sapply(st_intersects(st_transform(st_as_sf(pu, coords = c("lon", "lat"), crs = 4326), 27700), hex),
                                 function(i) if (length(i)) i[1] else NA)]) |>
  transmute(player_qid, label, birth_year, premier_league, certain = status == "certain", position,
            place_label, fine, lad21 = lad21cd, ttwa, hex20, lon, lat)
saveRDS(players, "app/data/players.rds")

# --- relative-risk raster (as in Step 5, sigma = 15 km) ---------------------------------
eng <- st_union(read_sf("data/processed/lad21_england.gpkg")) |> st_simplify(dTolerance = 500)
W <- spatstat.geom::rescale(as.owin(st_geometry(eng)), 1000, "km")
fine <- players |> filter(fine)
xy <- st_coordinates(st_transform(st_as_sf(fine, coords = c("lon", "lat"), crs = 4326), 27700)) / 1000
X <- ppp(xy[, 1], xy[, 2], window = W, check = FALSE)[W]
lb <- bl |> group_by(lsoa21cd, bng_e, bng_n) |> summarise(b = sum(b), .groups = "drop")
Bp <- ppp(lb$bng_e / 1000, lb$bng_n / 1000, window = W, check = FALSE)
ins <- inside.owin(Bp$x, Bp$y, W)
fp <- density(X, sigma = 15, eps = 2, positive = TRUE); fp <- fp / integral(fp)
fb <- density(Bp[ins], sigma = 15, weights = lb$b[ins] / sum(lb$b[ins]), eps = 2, positive = TRUE); fb <- fb / integral(fb)
rr <- eval.im(fp / pmax(fb, 1e-12))
m <- as.matrix(rr)
r <- terra::rast(nrows = nrow(m), ncols = ncol(m), xmin = rr$xrange[1] * 1000, xmax = rr$xrange[2] * 1000,
          ymin = rr$yrange[1] * 1000, ymax = rr$yrange[2] * 1000, crs = "EPSG:27700")
terra::values(r) <- as.vector(t(m[nrow(m):1, ]))
terra::writeRaster(r, "app/data/relative_risk.tif", overwrite = TRUE)

# --- tables from Steps 5–7 and RQ4 -------------------------------------------------------
tabs <- list(
  regions = read_csv("data/processed/step5_regions.csv", show_col_types = FALSE),
  lenv = read_csv("data/processed/step5_linhom_envelope.csv", show_col_types = FALSE),
  ltests = read_csv("data/processed/step5_tests.csv", show_col_types = FALSE),
  global = read_csv("data/processed/step6_global.csv", show_col_types = FALSE),
  rr = read_csv("data/processed/step7_rate_ratios.csv", show_col_types = FALSE),
  region_fx = read_csv("data/processed/step7_region_effects.csv", show_col_types = FALSE),
  model_data = read_csv("data/processed/step7_model_data_ttwa.csv", show_col_types = FALSE) |>
    left_join(read_csv("data/processed/step6_ttwa_queen.csv", show_col_types = FALSE) |> select(unit, gi_class), by = "unit"),
  academy = read_csv("data/processed/step7b_academy_rate_ratios.csv", show_col_types = FALSE),
  countries = read_csv("data/processed/step8_rq4_countries.csv", show_col_types = FALSE)
)
saveRDS(tabs, "app/data/tables.rds")

uk <- c("England", "Scotland", "Wales", "Northern Ireland")
# one feature per Natural Earth map unit, labelled with its country (no union: merging units
# that cross the date line creates stripes across the map)
sf_use_s2(FALSE)
world <- read_sf("/vsizip/data/raw/naturalearth/ne_10m_admin_0_map_units.zip") |>
  transmute(country = ifelse(GEOUNIT %in% uk, GEOUNIT, ADMIN)) |>
  st_simplify(dTolerance = 0.05, preserveTopology = TRUE)
saveRDS(world, "app/data/world.rds")

sizes <- file.size(list.files("app/data", full.names = TRUE))
cat(sprintf("app/data: %d files, %.1f MB total\n", length(sizes), sum(sizes) / 1e6))
cat("Players:", nrow(players), "| positions:", paste(names(table(players$position, useNA = "ifany")),
                                                   table(players$position, useNA = "ifany"), collapse = ", "), "\n")
