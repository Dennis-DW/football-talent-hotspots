# Step 4: analysis units, observed and expected counts, Standardised Ratios.
#
# Units:  309 LADs (2021) and regular hexagon grids of 10 km and 20 km over England
#         (EPSG:27700; sf hexagons with `cellsize` = distance between opposite edges).
# Players: English-born study players with a town-level birthplace (Step 2).
# Births:  male births by LAD and year (Step 3). For hexagons, each LAD's births are
#          shared out to its LSOAs in proportion to LSOA population (mid-2022), and each
#          LSOA is assigned to the hexagon containing its centroid.
#
# Expected count for unit i, variant v (proposal section 6.4):
#   E_iv = sum_y B_iy * N_vy / B_England,y
# where N_vy = number of players of variant v born in year y (only players placed on the
# map, so that sum O = sum E). SR = O / E.
#
# Variants (robustness checks, Step 7):
#   main          certain + probable appearance evidence
#   certain       certain evidence only
#   premier       Premier League subset (certain + probable)
#   cohort_75_89  born 1975–1989            cohort_90_05  born 1990–2005
#   no_ambiguous  excluding season-ambiguous players
#   pop_baseline  main players, total population (all ages) instead of male births
#
# Outputs: data/processed/hex10_england.gpkg, hex20_england.gpkg
#          data/processed/player_units.csv              player -> LAD, hex10, hex20
#          data/processed/counts_{lad21,hex10,hex20}.csv  unit x variant: O, E, SR
#          PostGIS schema `talent`: lad21, hex10, hex20, players, counts_* (GiST indexes)
#          docs/reports/figures/step4_sr_lad21_main.png
#
# Usage (inside the app container): Rscript R/04_expected_counts.R

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(arrow)
  library(ggplot2)
  library(DBI)
})
set.seed(20261118)

lad <- read_sf("data/processed/lad21_england.gpkg")
lsoa <- read_csv("data/processed/lsoa21_england.csv", show_col_types = FALSE)
births <- read_csv("data/processed/births_lad_year.csv", show_col_types = FALSE)
popl <- read_csv("data/processed/population_lad_year.csv", show_col_types = FALSE)

# --- hexagon grids ---------------------------------------------------------------
england <- st_union(lad)
lsoa_pts <- st_as_sf(lsoa, coords = c("bng_e", "bng_n"), crs = 27700, remove = FALSE)
make_hex <- function(km) {
  g <- st_make_grid(england, cellsize = km * 1000, square = FALSE) |>
    st_sf(geometry = _) |>
    mutate(hex_id = sprintf("H%02d_%05d", km, row_number()))
  # keep hexagons that contain at least one LSOA centroid (i.e. have population)
  g[lengths(st_intersects(g, lsoa_pts)) > 0, ]
}
hex10 <- make_hex(10)
hex20 <- make_hex(20)
write_sf(hex10, "data/processed/hex10_england.gpkg", delete_dsn = TRUE, quiet = TRUE)
write_sf(hex20, "data/processed/hex20_england.gpkg", delete_dsn = TRUE, quiet = TRUE)

# Travel to Work Areas 2011: LSOA -> TTWA assignment and polygons come from Step 3
# (R/03_area_covariates.R).
ttwa <- read_sf("data/processed/ttwa11_england.gpkg")
stopifnot("ttwa" %in% names(lsoa), all(lsoa$ttwa %in% ttwa$ttwa_id))

lsoa$hex10 <- hex10$hex_id[sapply(st_intersects(lsoa_pts, hex10), `[`, 1)]
lsoa$hex20 <- hex20$hex_id[sapply(st_intersects(lsoa_pts, hex20), `[`, 1)]
stopifnot(!anyNA(lsoa$hex10), !anyNA(lsoa$hex20))

# --- births by unit and year -----------------------------------------------------
share <- lsoa |>
  group_by(lad21cd) |>
  mutate(w = pop2022 / sum(pop2022)) |>
  ungroup() |>
  select(lsoa21cd, lad21cd, ttwa, hex10, hex20, w)
births_lsoa <- births |>
  select(lad21cd, birth_year, births_male) |>
  inner_join(share, by = "lad21cd", relationship = "many-to-many") |>
  mutate(b = births_male * w)
base_births <- list(
  lad21 = births |> transmute(unit = lad21cd, birth_year, b = births_male),
  ttwa = births_lsoa |> group_by(unit = ttwa, birth_year) |> summarise(b = sum(b), .groups = "drop"),
  hex10 = births_lsoa |> group_by(unit = hex10, birth_year) |> summarise(b = sum(b), .groups = "drop"),
  hex20 = births_lsoa |> group_by(unit = hex20, birth_year) |> summarise(b = sum(b), .groups = "drop")
)

# total-population baseline (1975–1980 use 1981)
pop_y <- expand_grid(lad21cd = unique(popl$lad21cd), birth_year = 1975:2005) |>
  mutate(year = pmax(birth_year, 1981)) |>
  left_join(popl, by = c("lad21cd", "year"))
stopifnot(!anyNA(pop_y$population))
pop_lsoa <- pop_y |>
  inner_join(share, by = "lad21cd", relationship = "many-to-many") |>
  mutate(b = population * w)
base_pop <- list(
  lad21 = pop_y |> transmute(unit = lad21cd, birth_year, b = population),
  ttwa = pop_lsoa |> group_by(unit = ttwa, birth_year) |> summarise(b = sum(b), .groups = "drop"),
  hex10 = pop_lsoa |> group_by(unit = hex10, birth_year) |> summarise(b = sum(b), .groups = "drop"),
  hex20 = pop_lsoa |> group_by(unit = hex20, birth_year) |> summarise(b = sum(b), .groups = "drop")
)

# --- players -> units ------------------------------------------------------------
players <- read_parquet("data/processed/players_eligible.parquet") |>
  filter(english_born, geo_level %in% c("town", "region"), !is.na(lon)) |>
  mutate(fine = geo_level == "town") |>
  select(player_qid, label, birth_year, status, premier_league, season_ambiguous, fine, lon, lat)
# Town-level birthplaces are used at every level. Region-level birthplaces (e.g. "London",
# data/manual/multi_lad_places.csv) are used only at TTWA level, where the whole region
# lies inside one unit (the London TTWA covers all 33 boroughs).
pts <- st_as_sf(players, coords = c("lon", "lat"), crs = 4326, remove = FALSE) |>
  st_transform(27700)

assign_unit <- function(pts, polys, id, max_m = 5000) {
  hit <- sapply(st_intersects(pts, polys), function(x) if (length(x)) x[1] else NA_integer_)
  miss <- is.na(hit)
  near <- rep(NA_integer_, length(hit))
  if (any(miss)) {
    nn <- st_nearest_feature(pts[miss, ], polys)
    d <- as.numeric(st_distance(pts[miss, ], polys[nn, ], by_element = TRUE))
    near[miss] <- ifelse(d <= max_m, nn, NA_integer_)
  }
  list(id = polys[[id]][ifelse(miss, near, hit)], snapped = miss & !is.na(near))
}
a_lad <- assign_unit(pts, lad, "lad21cd")
a_ttwa <- assign_unit(pts, ttwa, "ttwa_id")
a_h10 <- assign_unit(pts, hex10, "hex_id")
a_h20 <- assign_unit(pts, hex20, "hex_id")
players <- players |>
  mutate(lad21cd = a_lad$id, ttwa = a_ttwa$id, hex10 = a_h10$id, hex20 = a_h20$id,
         snapped_to_land = a_lad$snapped)
unplaced <- players |> filter(is.na(lad21cd) | is.na(ttwa) | is.na(hex10) | is.na(hex20))
players <- players |> filter(!is.na(lad21cd), !is.na(ttwa), !is.na(hex10), !is.na(hex20))
write_csv(players, "data/processed/player_units.csv")

# --- observed, expected, SR --------------------------------------------------------
variants <- list(
  main = function(p) p,
  certain = function(p) filter(p, status == "certain"),
  premier = function(p) filter(p, premier_league),
  cohort_75_89 = function(p) filter(p, birth_year <= 1989),
  cohort_90_05 = function(p) filter(p, birth_year >= 1990),
  no_ambiguous = function(p) filter(p, !season_ambiguous),
  pop_baseline = function(p) p
)

counts_for <- function(level) {
  units <- switch(level, lad21 = lad$lad21cd, ttwa = ttwa$ttwa_id, hex10 = hex10$hex_id, hex20 = hex20$hex_id)
  bind_rows(lapply(names(variants), function(v) {
    p <- variants[[v]](players)
    if (level != "ttwa") p <- filter(p, fine)
    base <- if (v == "pop_baseline") base_pop[[level]] else base_births[[level]]
    tot <- base |> group_by(birth_year) |> summarise(B = sum(b), .groups = "drop")
    n_y <- p |> count(birth_year, name = "N")
    rate <- tot |> left_join(n_y, by = "birth_year") |> mutate(N = coalesce(N, 0L), r = N / B)
    E <- base |> inner_join(rate, by = "birth_year") |>
      group_by(unit) |> summarise(E = sum(b * r), births = sum(b), .groups = "drop")
    col <- c(lad21 = "lad21cd", ttwa = "ttwa", hex10 = "hex10", hex20 = "hex20")[[level]]
    O <- p |> count(unit = .data[[col]], name = "O")
    tibble(unit = units) |>
      left_join(E, by = "unit") |>
      left_join(O, by = "unit") |>
      mutate(O = coalesce(O, 0L), E = coalesce(E, 0), births = coalesce(births, 0),
             SR = ifelse(E > 0, O / E, NA_real_), variant = v)
  }))
}
counts <- lapply(c(lad21 = "lad21", ttwa = "ttwa", hex10 = "hex10", hex20 = "hex20"), counts_for)
for (lv in names(counts)) write_csv(counts[[lv]], sprintf("data/processed/counts_%s.csv", lv))

# --- integrity checks ----------------------------------------------------------------
chk <- bind_rows(lapply(names(counts), function(lv) {
  counts[[lv]] |> group_by(variant) |>
    summarise(level = lv, sum_O = sum(O), sum_E = sum(E), .groups = "drop")
}))
stopifnot(all(abs(chk$sum_O - chk$sum_E) < 1e-6))
b_tot <- sum(births$births_male)
stopifnot(abs(sum(base_births$ttwa$b) - b_tot) / b_tot < 1e-9,
          abs(sum(base_births$hex10$b) - b_tot) / b_tot < 1e-9,
          abs(sum(base_births$hex20$b) - b_tot) / b_tot < 1e-9)

# --- PostGIS ---------------------------------------------------------------------------
con <- dbConnect(RPostgres::Postgres(),
                 host = Sys.getenv("POSTGRES_HOST", "db"),
                 port = as.integer(Sys.getenv("POSTGRES_PORT", "5432")),
                 dbname = Sys.getenv("POSTGRES_DB"), user = Sys.getenv("POSTGRES_USER"),
                 password = Sys.getenv("POSTGRES_PASSWORD"))
put <- function(x, table) {
  invisible(st_write(x, con, Id(schema = "talent", table = table), delete_layer = TRUE, quiet = TRUE))
  geom <- attr(x, "sf_column")
  invisible(dbExecute(con, sprintf("CREATE INDEX ON talent.%s USING GIST (%s)", table, geom)))
}
put(lad, "lad21")
put(ttwa, "ttwa11")
put(hex10, "hex10")
put(hex20, "hex20")
put(st_as_sf(players, coords = c("lon", "lat"), crs = 4326, remove = FALSE), "players")
for (lv in names(counts)) {
  dbWriteTable(con, Id(schema = "talent", table = paste0("counts_", lv)), counts[[lv]],
               overwrite = TRUE)
}
n_db <- dbGetQuery(con, "SELECT (SELECT count(*) FROM talent.lad21) AS lad,
                          (SELECT count(*) FROM talent.ttwa11) AS ttwa,
                          (SELECT count(*) FROM talent.hex10) AS hex10,
                          (SELECT count(*) FROM talent.hex20) AS hex20,
                          (SELECT count(*) FROM talent.players) AS players")
dbDisconnect(con)

# --- first map ---------------------------------------------------------------------------
dir.create("docs/reports/figures", recursive = TRUE, showWarnings = FALSE)
m <- lad |> left_join(filter(counts$lad21, variant == "main"), by = c("lad21cd" = "unit"))
p <- ggplot(m) +
  geom_sf(aes(fill = pmin(pmax(SR, 0.25), 4)), colour = "grey40", linewidth = 0.05) +
  scale_fill_gradient2(trans = "log2", low = "#2166ac", mid = "#f7f7f7", high = "#b2182b",
                       midpoint = 0, breaks = c(0.25, 0.5, 1, 2, 4),
                       labels = c("≤0.25", "0.5", "1", "2", "≥4"), name = "SR (O/E)") +
  labs(title = "Standardised Ratio by local authority (raw, unsmoothed)",
       subtitle = "English-born PL/Championship players born 1975–2005 vs. male births",
       caption = "Raw SR: small areas are noisy. Smoothing and significance tests follow in Step 6.") +
  theme_void(base_size = 10)
ggsave("docs/reports/figures/step4_sr_lad21_main.png", p, width = 7, height = 8, dpi = 150, bg = "white")

mt <- ttwa |> left_join(filter(counts$ttwa, variant == "main"), by = c("ttwa_id" = "unit"))
pt <- p %+% mt + labs(title = "Standardised Ratio by Travel to Work Area (raw, unsmoothed)")
ggsave("docs/reports/figures/step4_sr_ttwa_main.png", pt, width = 7, height = 8, dpi = 150, bg = "white")

# --- summary -----------------------------------------------------------------------------
cat(sprintf("Hexagons with population: 10 km = %d, 20 km = %d (hex area %.1f / %.1f km2)\n",
            nrow(hex10), nrow(hex20),
            as.numeric(st_area(hex10[1, ])) / 1e6, as.numeric(st_area(hex20[1, ])) / 1e6))
cat(sprintf("Region-level birthplaces (TTWA only): %d\n", sum(!players$fine)))
cat(sprintf("Players placed: %d | snapped to land (<=5 km): %d | not placed: %d\n",
            nrow(players), sum(players$snapped_to_land), nrow(unplaced)))
cat("PostGIS rows:", paste(names(n_db), sapply(n_db, function(x) as.numeric(as.character(x))), collapse = ", "), "\n")
cat("Players per variant:\n")
print(chk |> filter(level == "lad21") |> select(variant, players = sum_O))
main <- counts$lad21 |> filter(variant == "main")
cat("\nLAD-level SR (main): \n")
print(summary(main$SR))
cat("LADs with O = 0:", sum(main$O == 0), "of", nrow(main), "\n")
cat("\nHighest raw SR (LADs with E >= 5):\n")
print(main |> filter(E >= 5) |> arrange(desc(SR)) |> head(10) |>
        left_join(st_drop_geometry(lad), by = c("unit" = "lad21cd")) |>
        transmute(lad21nm, O, E = round(E, 1), SR = round(SR, 2)))
cat("Lowest raw SR (LADs with E >= 5):\n")
print(main |> filter(E >= 5) |> arrange(SR) |> head(10) |>
        left_join(st_drop_geometry(lad), by = c("unit" = "lad21cd")) |>
        transmute(lad21nm, O, E = round(E, 1), SR = round(SR, 2)))

ttwa_main <- counts$ttwa |> filter(variant == "main") |>
  left_join(st_drop_geometry(ttwa), by = c("unit" = "ttwa_id"))
cat(sprintf("\nTTWAs (England): %d | SR summary:\n", nrow(ttwa)))
print(summary(ttwa_main$SR))
cat("Highest raw SR (TTWAs with E >= 5):\n")
print(ttwa_main |> filter(E >= 5) |> arrange(desc(SR)) |> head(12) |>
        transmute(ttwa_nm, O, E = round(E, 1), SR = round(SR, 2)))
cat("Lowest raw SR (TTWAs with E >= 5):\n")
print(ttwa_main |> filter(E >= 5) |> arrange(SR) |> head(12) |>
        transmute(ttwa_nm, O, E = round(E, 1), SR = round(SR, 2)))
