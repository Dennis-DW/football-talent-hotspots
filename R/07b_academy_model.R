# Step 7b: academy-era sub-model (proposal 6.8d; WORKPLAN Step 7).
#
# Cohort: English-born study players born 1996–2005 (aged <= 16 when EPPP began, 2012/13).
# Unit: 155 TTWAs. Outcome O (players of this cohort), offset log E (expected from male
# births 1996–2005). Distances (EPSG:27700, from LSOA centroids, population-weighted to
# TTWA, then births-weighted over birth years y):
#   dist_club    nearest professional (tier 1–4) club ground in season y + 12
#   dist_academy nearest Category 1 academy club ground in season max(2012, y + 12)
#                (data/manual/category1_academies.csv; club stadium used as a proxy for
#                 the academy / training-ground location)
# Models (negative binomial, + IMD, urban share, region fixed effects):
#   A1 dist_club only   A2 dist_academy only   A3 both
#
# Outputs: data/processed/step7b_academy_rate_ratios.csv, step7b_academy_fit.csv
# Usage (inside the app container): Rscript R/07b_academy_model.R

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
  library(MASS, exclude = "select")
})
latest <- function(pattern, dir) tail(sort(list.files(dir, pattern, full.names = TRUE)), 1)
Y <- 1996:2005

lsoa <- read_csv("data/processed/lsoa21_england.csv", show_col_types = FALSE)
births <- read_csv("data/processed/births_lad_year.csv", show_col_types = FALSE) |> filter(birth_year %in% Y)
grounds <- read_csv("data/processed/club_season_ground.csv", show_col_types = FALSE) |> filter(!is.na(lon))
acad <- read_csv("data/manual/category1_academies.csv", show_col_types = FALSE)
players <- read_csv("data/processed/player_units.csv", show_col_types = FALSE) |> filter(birth_year %in% Y)
cov_t <- read_csv("data/processed/ttwa_covariates.csv", show_col_types = FALSE) |>
  transmute(unit = ttwa_id, name = ttwa_nm, imd10 = imd_score / 10, urban10 = urban_share * 10)
reg <- read_csv("data/processed/step7_model_data_ttwa.csv", show_col_types = FALSE) |> select(unit, region)

# births by LSOA and year -> TTWA
bl <- lsoa |> group_by(lad21cd) |> mutate(w = pop2022 / sum(pop2022)) |> ungroup() |>
  select(lsoa21cd, lad21cd, ttwa, pop2022, w, bng_e, bng_n) |>
  inner_join(births |> select(lad21cd, birth_year, births_male), by = "lad21cd",
             relationship = "many-to-many") |>
  mutate(b = births_male * w)
bt <- bl |> group_by(unit = ttwa, birth_year) |> summarise(b = sum(b), .groups = "drop")

# distance from every LSOA to the nearest point of a set, by season
pts_l <- st_as_sf(lsoa, coords = c("bng_e", "bng_n"), crs = 27700)
nearest_km <- function(g) {
  g <- st_as_sf(g, coords = c("lon", "lat"), crs = 4326) |> st_transform(27700)
  as.numeric(st_distance(pts_l, g[st_nearest_feature(pts_l, g), ], by_element = TRUE)) / 1000
}
season_club <- Y + 12
season_acad <- pmin(pmax(2012, Y + 12), 2021)
d_club <- lapply(unique(season_club), function(s) tibble(lsoa21cd = lsoa$lsoa21cd, season = s,
                 d = nearest_km(filter(grounds, season == s, tier %in% 1:4)))) |> bind_rows()
d_acad <- lapply(unique(season_acad), function(s) {
  g <- grounds |> filter(season == s) |> semi_join(filter(acad, season == s), by = "club_qid")
  stopifnot(nrow(g) == sum(acad$season == s))
  tibble(lsoa21cd = lsoa$lsoa21cd, season = s, d = nearest_km(g))
}) |> bind_rows()

ttwa_dist <- function(dl, season_of_year) {
  map <- tibble(birth_year = Y, season = season_of_year)
  bl |> select(lsoa21cd, ttwa, birth_year, b) |>
    inner_join(map, by = "birth_year") |>
    inner_join(dl, by = c("lsoa21cd", "season")) |>
    group_by(unit = ttwa) |> summarise(dist = sum(b * d) / sum(b), .groups = "drop")
}
dist <- ttwa_dist(d_club, season_club) |> rename(dist_club = dist) |>
  inner_join(ttwa_dist(d_acad, season_acad) |> rename(dist_academy = dist), by = "unit")

# observed / expected for the cohort
n_y <- players |> count(birth_year, name = "N")
rate <- bt |> group_by(birth_year) |> summarise(B = sum(b), .groups = "drop") |>
  left_join(n_y, by = "birth_year") |> mutate(N = coalesce(N, 0L), r = N / B)
E <- bt |> inner_join(rate, by = "birth_year") |> group_by(unit) |> summarise(E = sum(b * r), .groups = "drop")
O <- players |> count(unit = ttwa, name = "O")
d <- cov_t |> inner_join(reg, by = "unit") |> inner_join(dist, by = "unit") |>
  inner_join(E, by = "unit") |> left_join(O, by = "unit") |>
  mutate(O = coalesce(O, 0L), club10 = dist_club / 10, acad10 = dist_academy / 10,
         region = relevel(factor(region), ref = "West Midlands"))
stopifnot(nrow(d) == 155, abs(sum(d$O) - sum(d$E)) < 1e-6)

base <- O ~ imd10 + urban10 + region + offset(log(E))
a1 <- glm.nb(update(base, . ~ . + club10), data = d)
a2 <- glm.nb(update(base, . ~ . + acad10), data = d)
a3 <- glm.nb(update(base, . ~ . + club10 + acad10), data = d)
rr <- function(m, label) {
  co <- summary(m)$coefficients
  k <- rownames(co) %in% c("club10", "acad10", "imd10", "urban10")
  ci <- suppressMessages(confint.default(m))[k, , drop = FALSE]
  tibble(model = label, term = rownames(co)[k], RR = exp(co[k, 1]), lo = exp(ci[, 1]),
         hi = exp(ci[, 2]), p = co[k, 4])
}
tab <- bind_rows(rr(a1, "A1 club distance"), rr(a2, "A2 academy distance"), rr(a3, "A3 both"))
fit <- tibble(model = c("A1 club distance", "A2 academy distance", "A3 both"),
              AIC = c(AIC(a1), AIC(a2), AIC(a3)), theta = c(a1$theta, a2$theta, a3$theta))
write_csv(tab, "data/processed/step7b_academy_rate_ratios.csv")
write_csv(fit, "data/processed/step7b_academy_fit.csv")
write_csv(d |> select(unit, name, region, O, E, dist_club, dist_academy), "data/processed/step7b_academy_data.csv")

cat(sprintf("Cohort 1996–2005: %d players in %d TTWAs | Category 1 academies per season: %s\n",
            sum(d$O), nrow(d), paste(range(table(acad$season)), collapse = "–")))
cat(sprintf("Distance (km), median: club %.1f, academy %.1f | correlation %.2f\n",
            median(d$dist_club), median(d$dist_academy), cor(d$dist_club, d$dist_academy)))
print(fit |> mutate(across(where(is.numeric), ~ round(.x, 1))))
print(tab |> filter(term %in% c("club10", "acad10")) |>
        mutate(across(c(RR, lo, hi), ~ round(.x, 3)), p = signif(p, 2)))
