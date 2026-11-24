# Export the club–season–tier table from engsoccerdata (English league, tiers 1–4).
#
# Seasons are identified by start year (1992 = 1992/93). We keep 1985–2024 because:
#   - eligibility needs tiers 1–2 from 1992/93 onward;
#   - the club-distance covariate needs all professional clubs in the season each
#     birth cohort was aged 12 (born 1975 -> 1987/88 ... born 2005 -> 2017/18).
# engsoccerdata has no 2022/23 season; that season and 2025/26 come from Wikipedia
# (pipeline/clubs/01_league_tables_wikipedia.py).
#
# Usage (inside the app container): Rscript analysis/prepare/01_club_tiers_engsoc.R

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
})

eng <- engsoccerdata::england

tiers <- eng |>
  filter(Season >= 1985, tier %in% 1:4) |>
  select(season = Season, tier, home, visitor) |>
  pivot_longer(c(home, visitor), values_to = "club") |>
  distinct(season, tier, club) |>
  arrange(season, tier, club)

out <- "data/processed/club_season_tier_engsoc.csv"
write.csv(tiers, out, row.names = FALSE)

counts <- tiers |> count(season, tier) |> pivot_wider(names_from = tier, values_from = n,
                                                     names_prefix = "tier")
missing <- setdiff(1985:max(tiers$season), unique(tiers$season))
cat(sprintf("Wrote %s: %d rows, %d clubs, seasons %d–%d\n", out, nrow(tiers),
            n_distinct(tiers$club), min(tiers$season), max(tiers$season)))
cat("Seasons missing from engsoccerdata:", paste(missing, collapse = ", "), "\n")
cat(sprintf("engsoccerdata version %s\n", as.character(packageVersion("engsoccerdata"))))
