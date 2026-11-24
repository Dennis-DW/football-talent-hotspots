# Area covariates for English local authority districts (LAD 2021).
#
#   imd_score     population-weighted mean IMD 2025 score of the LAD's LSOAs
#   urban_share   share of the population living in urban LSOAs (RUC 2021)
#   dist_club_km  births-weighted distance to the nearest professional club (tiers 1–4)
#                 in the season each birth cohort was aged 12:
#                   d_i(s)       = population-weighted mean over the LAD's LSOA centroids
#                                  of the distance to the nearest club ground in season s
#                   dist_club_i  = sum_y B_iy * d_i(y + 12) / sum_y B_iy,  y = 1975..2005
#
# All distances in EPSG:27700 (British National Grid). LSOA population weights: IoD 2025
# denominators (mid-2022), the only LSOA-level population consistent with 2021 LSOAs.
#
# Inputs : data/raw/ons/*.geojson, data/raw/ons/lsoa21_lad21_lookup_*.csv,
#          data/raw/imd/File_7_IoD2025_*.csv, data/processed/club_season_ground.csv,
#          data/processed/births_lad_year.csv
# Outputs: data/processed/lad21_england.gpkg        LAD 2021 polygons (EPSG:27700)
#          data/processed/lsoa21_england.csv        LSOA attributes (+ BNG centroid)
#          data/processed/lad21_covariates.csv      one row per LAD
#          data/processed/lad21_season_dist_club.csv distance by LAD and season
#
# Usage (inside the app container): Rscript analysis/prepare/03_area_covariates.R

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
  library(tidyr)
})

latest <- function(pattern, dir) {
  f <- sort(list.files(dir, pattern = pattern, full.names = TRUE))
  stopifnot(length(f) > 0)
  tail(f, 1)
}

# --- LAD 2021 boundaries (England) ----------------------------------------------
lad <- read_sf(latest("^lad21_uk_bgc_.*geojson$", "data/raw/ons")) |>
  filter(startsWith(LAD21CD, "E")) |>
  select(lad21cd = LAD21CD, lad21nm = LAD21NM) |>
  st_transform(27700) |>
  st_make_valid()
births <- read_csv("data/processed/births_lad_year.csv", show_col_types = FALSE)
stopifnot(setequal(lad$lad21cd, unique(births$lad21cd)))
write_sf(lad, "data/processed/lad21_england.gpkg", delete_dsn = TRUE, quiet = TRUE)

# --- LSOA attributes: RUC, IMD, population, LAD ----------------------------------
lsoa_geo <- read_sf(latest("^lsoa21_ew_bsc_ruc_.*geojson$", "data/raw/ons")) |>
  st_drop_geometry() |>
  transmute(lsoa21cd = LSOA21CD, bng_e = BNG_E, bng_n = BNG_N,
            ruc21cd = RUC21CD, urban = Urban_rura == "Urban")
lookup <- read_csv(latest("^lsoa21_lad21_lookup_.*csv$", "data/raw/ons"),
                   show_col_types = FALSE) |>
  transmute(lsoa21cd = LSOA21CD, lad21cd = LAD21CD)
imd <- read_csv(latest("^File_7_IoD2025.*csv$", "data/raw/imd"),
                show_col_types = FALSE) |>
  transmute(lsoa21cd = `LSOA code (2021)`,
            imd_score = `Index of Multiple Deprivation (IMD) Score`,
            pop2022 = `Total population: mid 2022`)
lsoa <- lsoa_geo |>
  inner_join(lookup, by = "lsoa21cd") |>
  inner_join(imd, by = "lsoa21cd")
cat(sprintf("LSOAs: %d boundaries, %d matched to LAD and IMD\n",
            nrow(lsoa_geo), nrow(lsoa)))
stopifnot(nrow(lsoa) == nrow(lsoa_geo), all(lsoa$lad21cd %in% lad$lad21cd))
# Travel to Work Area 2011 of each LSOA (point-in-polygon of the LSOA centroid; centroids
# just outside the generalised coastline go to the nearest TTWA). TTWAs are the main
# analysis unit (they contain a town and its catchment, absorbing the hospital effect).
lsoa_pts <- st_as_sf(lsoa, coords = c("bng_e", "bng_n"), crs = 27700, remove = FALSE)
ttwa_all <- read_sf(latest("^ttwa11_uk_gcb_.*geojson$", "data/raw/ons")) |>
  transmute(ttwa_id = TTWA11CD, ttwa_nm = TTWA11NM) |>
  st_transform(27700) |> st_make_valid()
hit <- sapply(st_intersects(lsoa_pts, ttwa_all),
              function(x) if (length(x)) x[1] else NA_integer_)
hit[is.na(hit)] <- st_nearest_feature(lsoa_pts[is.na(hit), ], ttwa_all)
lsoa$ttwa <- ttwa_all$ttwa_id[hit]
ttwa <- ttwa_all |> filter(ttwa_id %in% lsoa$ttwa)
write_sf(ttwa, "data/processed/ttwa11_england.gpkg", delete_dsn = TRUE, quiet = TRUE)
write_csv(lsoa, "data/processed/lsoa21_england.csv")

# --- Distance to nearest professional club, by LSOA and season --------------------
grounds <- read_csv("data/processed/club_season_ground.csv", show_col_types = FALSE) |>
  filter(!is.na(lon), tier %in% 1:4)
seasons <- (1975 + 12):(2005 + 12)
lsoa_births <- lsoa |>
  group_by(lad21cd) |> mutate(w = pop2022 / sum(pop2022)) |> ungroup() |>
  select(lsoa21cd, lad21cd, ttwa, w) |>
  inner_join(births, by = "lad21cd", relationship = "many-to-many") |>
  mutate(b = births_male * w)

dist_lsoa <- list()
dist_lad <- lapply(seasons, function(s) {
  g <- grounds |> filter(season == s) |>
    st_as_sf(coords = c("lon", "lat"), crs = 4326) |> st_transform(27700)
  nn <- st_nearest_feature(lsoa_pts, g)
  d_km <- as.numeric(st_distance(lsoa_pts, g[nn, ], by_element = TRUE)) / 1000
  dist_lsoa[[as.character(s)]] <<- tibble(lsoa21cd = lsoa$lsoa21cd, season = s, d = d_km)
  lsoa |>
    mutate(d = d_km) |>
    group_by(lad21cd) |>
    summarise(dist_club_km = weighted.mean(d, pop2022), .groups = "drop") |>
    mutate(season = s, n_clubs = nrow(g))
}) |> bind_rows()
write_csv(dist_lad, "data/processed/lad21_season_dist_club.csv")

cohort_dist <- births |>
  mutate(season = birth_year + 12) |>
  inner_join(dist_lad, by = c("lad21cd", "season")) |>
  group_by(lad21cd) |>
  summarise(dist_club_km = sum(births_male * dist_club_km) / sum(births_male),
            .groups = "drop")

# --- LAD covariates --------------------------------------------------------------
cov <- lsoa |>
  group_by(lad21cd) |>
  summarise(imd_score = weighted.mean(imd_score, pop2022),
            urban_share = sum(pop2022 * urban) / sum(pop2022),
            pop2022 = sum(pop2022), n_lsoa = n(), .groups = "drop") |>
  left_join(cohort_dist, by = "lad21cd") |>
  left_join(st_drop_geometry(lad), by = "lad21cd") |>
  mutate(area_km2 = as.numeric(st_area(lad)[match(lad21cd, lad$lad21cd)]) / 1e6) |>
  relocate(lad21nm, .after = lad21cd)
stopifnot(nrow(cov) == nrow(lad), !anyNA(cov))
write_csv(cov, "data/processed/lad21_covariates.csv")

# --- TTWA covariates (main unit) ----------------------------------------------------
dist_ttwa <- bind_rows(dist_lsoa) |>
  inner_join(select(lsoa, lsoa21cd, ttwa, pop2022), by = "lsoa21cd") |>
  group_by(ttwa, season) |>
  summarise(dist_club_km = weighted.mean(d, pop2022), .groups = "drop")
write_csv(dist_ttwa, "data/processed/ttwa_season_dist_club.csv")
ttwa_births <- lsoa_births |> group_by(ttwa, birth_year) |>
  summarise(b = sum(b), .groups = "drop")
ttwa_dist <- ttwa_births |>
  mutate(season = birth_year + 12) |>
  inner_join(dist_ttwa, by = c("ttwa", "season")) |>
  group_by(ttwa) |>
  summarise(dist_club_km = sum(b * dist_club_km) / sum(b), .groups = "drop")
cov_ttwa <- lsoa |>
  group_by(ttwa) |>
  summarise(imd_score = weighted.mean(imd_score, pop2022),
            urban_share = sum(pop2022 * urban) / sum(pop2022),
            pop2022 = sum(pop2022), n_lsoa = n(), .groups = "drop") |>
  left_join(ttwa_dist, by = "ttwa") |>
  left_join(st_drop_geometry(ttwa), by = c("ttwa" = "ttwa_id")) |>
  rename(ttwa_id = ttwa) |>
  relocate(ttwa_nm, .after = ttwa_id)
stopifnot(nrow(cov_ttwa) == nrow(ttwa), !anyNA(cov_ttwa))
write_csv(cov_ttwa, "data/processed/ttwa_covariates.csv")
cat(sprintf("TTWAs (England): %d\n", nrow(cov_ttwa)))
print(summary(select(cov_ttwa, imd_score, urban_share, dist_club_km, pop2022)))

cat(sprintf("LADs: %d | seasons for club distance: %d–%d (%d–%d clubs per season)\n",
            nrow(cov), min(seasons), max(seasons),
            min(dist_lad$n_clubs), max(dist_lad$n_clubs)))
cat("Summary of LAD covariates:\n")
print(summary(select(cov, imd_score, urban_share, dist_club_km, pop2022)))
