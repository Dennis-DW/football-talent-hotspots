# Step 7 RQ4 (descriptive): where do players born outside England come from?
#
# All study players (Step 2) by birth country / UK nation (Natural Earth map units).
# Players per million: mean national population 1975–2005 (World Bank; ONS for
# England/Scotland/Wales; none for Northern Ireland). Cohorts 1975–1989 vs 1990–2005.
# No hotspot inference: players born abroad are a selected subset of each country's
# footballers (recruitment by English clubs), not a measure of talent production.
#
# Outputs: data/processed/step8_rq4_countries.csv, step8_rq4_continents.csv,
#          docs/reports/figures/rq4_world_per_million.png, rq4_top_countries.png
# Usage (inside the app container): Rscript R/08_foreign_born.R

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(arrow)
  library(ggplot2)
})
sf_use_s2(FALSE)

units <- read_sf("/vsizip/data/raw/naturalearth/ne_10m_admin_0_map_units.zip") |>
  select(birth_unit = GEOUNIT, admin = ADMIN, adm0 = ADM0_A3,
         continent = CONTINENT, region_un = REGION_UN, subregion = SUBREGION)
pop <- read_csv("data/processed/country_population.csv", show_col_types = FALSE)
uk_nations <- c("England", "Scotland", "Wales", "Northern Ireland")
# Group by sovereign country (Natural Earth ADMIN), except the four UK nations.
# Natural Earth country codes that differ from World Bank codes:
code_fix <- c(KOS = "XKX", SDS = "SSD", PSX = "PSE")
p <- read_parquet("data/processed/players_eligible.parquet") |>
  mutate(cohort = ifelse(birth_year <= 1989, "1975–1989", "1990–2005"),
         country = case_when(is.na(birth_unit) ~ "(unknown)",
                             birth_unit %in% uk_nations ~ birth_unit,
                             TRUE ~ birth_country))
# one row per country: prefer the main unit (GEOUNIT == ADMIN, e.g. mainland France rather
# than French Guiana) so the continent is that of the main territory
key <- st_drop_geometry(units) |> arrange(desc(birth_unit == admin)) |>
  distinct(admin, .keep_all = TRUE) |>
  transmute(country = admin, adm0, continent, subregion)
key_uk <- tibble(country = uk_nations, adm0 = uk_nations, continent = "Europe",
                 subregion = "Northern Europe")
key <- bind_rows(key |> filter(country != "United Kingdom"), key_uk)
cnt <- p |>
  count(country, cohort) |>
  pivot_wider(names_from = cohort, values_from = n, values_fill = 0) |>
  mutate(total = `1975–1989` + `1990–2005`) |>
  left_join(key, by = "country") |>
  mutate(pop_code = ifelse(adm0 %in% names(code_fix), code_fix[adm0], adm0)) |>
  left_join(pop |> select(pop_code = code, pop_mean), by = "pop_code") |>
  mutate(per_million = total / (pop_mean / 1e6)) |>
  arrange(desc(total))
write_csv(cnt, "data/processed/step8_rq4_countries.csv")

study_n <- nrow(p)
by_cohort <- p |> mutate(group = case_when(country == "England" ~ "England",
                                           country %in% uk_nations ~ "Other UK nations",
                                           country == "(unknown)" ~ "Unknown", TRUE ~ "Outside UK")) |>
  count(cohort, group) |> group_by(cohort) |> mutate(share = n / sum(n)) |> ungroup()
cont <- p |> filter(!country %in% c(uk_nations, "(unknown)")) |>
  left_join(key |> select(country, continent), by = "country") |>
  count(cohort, continent) |> group_by(cohort) |> mutate(share = n / sum(n)) |> ungroup()
write_csv(cont, "data/processed/step8_rq4_continents.csv")

# --- figures ---------------------------------------------------------------------------
world <- units |>
  mutate(country = ifelse(birth_unit %in% uk_nations, birth_unit, admin)) |>
  left_join(cnt |> select(country, total, per_million), by = "country")
pw <- ggplot(world) +
  geom_sf(aes(fill = per_million), colour = "grey60", linewidth = 0.05) +
  scale_fill_viridis_c(trans = "log10", option = "plasma", na.value = "grey92",
                       name = "players per\nmillion people") +
  coord_sf(crs = "+proj=robin", datum = NA) +
  labs(title = "Premier League / Championship players born 1975–2005, by country of birth",
       subtitle = "Per million national population (mean 1975–2005). Grey: no study player or no population data.",
       caption = "Descriptive: reflects recruitment by English clubs, not talent production in each country.") +
  theme_void(base_size = 10)
ggsave("docs/reports/figures/rq4_world_per_million.png", pw, width = 10, height = 5.5, dpi = 150, bg = "white")

top <- cnt |> filter(country != "England", country != "(unknown)") |> slice_max(total, n = 20) |>
  select(country, `1975–1989`, `1990–2005`) |>
  pivot_longer(-country, names_to = "cohort", values_to = "players")
pt <- ggplot(top, aes(players, reorder(country, players, sum), fill = cohort)) +
  geom_col() + scale_fill_manual(values = c("1975–1989" = "#92c5de", "1990–2005" = "#2166ac")) +
  labs(x = "study players", y = NULL, fill = "born",
       title = "Top 20 birth countries outside England") +
  theme_minimal(base_size = 10)
ggsave("docs/reports/figures/rq4_top_countries.png", pt, width = 7, height = 6, dpi = 150, bg = "white")

# --- summary -------------------------------------------------------------------------------
cat(sprintf("Study players: %d | birth countries/nations: %d\n", study_n,
            sum(cnt$country != "(unknown)")))
cat("By cohort:\n"); print(by_cohort |> mutate(share = round(100 * share, 1)))
cat("\nTop 20 outside England (total, per million):\n")
print(cnt |> filter(country != "England") |> slice_head(n = 21) |>
        transmute(country, `1975–1989`, `1990–2005`, total, per_million = round(per_million, 2)), n = 21)
cat("\nHighest per million (>= 10 players):\n")
print(cnt |> filter(total >= 10) |> arrange(desc(per_million)) |> slice_head(n = 10) |>
        transmute(country, total, per_million = round(per_million, 2)))
cat("\nContinents outside the UK (share %):\n")
print(cont |> mutate(share = round(100 * share, 1)) |> select(-n) |>
        pivot_wider(names_from = cohort, values_from = share))
miss <- cnt |> filter(is.na(pop_mean), country != "(unknown)")
cat("\nNo population match:", paste(miss$country, collapse = ", "), "\n")
