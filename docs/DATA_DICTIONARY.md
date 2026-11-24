# Data Dictionary

Variables in the main output files. All files are created by the pipeline (see [README](../README.md)).
`data/raw/` and `data/processed/` are not in Git; `data/manual/` is.

**Conventions**
- Seasons are identified by their **start year** (`2004` = 2004/05).
- Tiers: 1 = Premier League (from 1992/93), 2 = First Division to 2003/04 / Championship from 2004/05, 3–4 = lower Football League divisions.
- Wikidata identifiers (`Q…`) can be opened at `https://www.wikidata.org/wiki/<QID>`.
- Coordinates are stored in WGS 84 (`lon`, `lat`); distances and areas are computed in British National Grid (EPSG:27700).

---

## Players

### `data/processed/players_eligible.parquet`: one row per study player (6,581)

| Variable | Type | Description |
|---|---|---|
| `player_qid` | text | Wikidata ID of the player |
| `label` | text | Player name (English label) |
| `sex` | text | Wikidata sex (Q6581097 = male; all study players) |
| `birth_date`, `birth_year` | date, int | Date / year of birth (1975–2005) |
| `birth_precision` | int | Wikidata precision of the birth date (9 = year, 10 = month, 11 = day) |
| `place_qid`, `place_label` | text | Wikidata place of birth |
| `place_country_qid` | text | Country of the birthplace in Wikidata |
| `lon`, `lat` | number | Birthplace coordinates (Wikidata, or Nominatim fallback) |
| `geo_source` | text | `wikidata` / `nominatim` / missing |
| `geo_level` | text | Birthplace precision: `town`, `admin` (county/region), `region` (e.g. "London"), `country`, `no birthplace`, `no coordinates` |
| `birth_unit` | text | Natural Earth map unit of the birthplace (England / Scotland / Wales / Northern Ireland, or country) |
| `birth_country`, `birth_iso3` | text | Sovereign country and its Natural Earth code |
| `country_match` | text | `within` a country polygon, `nearest <= 10 km` (coast), or `no coordinates` |
| `english_born` | bool | Birthplace in England (main analysis) |
| `positions` | text | Wikidata positions, separated by `\|` |
| `status` | text | Appearance evidence: `certain` or `probable` |
| `evidence_t12`, `evidence_pl` | text | Evidence level for tier 1–2 / Premier League appearances |
| `evidence_source` | text | `wikipedia_infobox` or `wikidata_P1350` (matches played) |
| `evidence_detail` | text | Infobox spells supporting the evidence |
| `premier_league` | bool | At least one Premier League appearance (certain or probable) |
| `premier_league_certain` | bool | Premier League appearance with certain evidence |
| `season_ambiguous` | bool | Eligibility on Wikidata dates depends on a year-only date in a promotion/relegation season |
| `wikidata_status` | text | Result of the first, Wikidata-only rule (before validation) |
| `first_t12_season`, `last_t12_season`, `n_t12_seasons`, `n_t12_clubs` | int | Tier 1–2 seasons/clubs from dated Wikidata memberships |
| `undated_basis` | bool | First-rule eligibility based only on undated memberships |
| `multiple_birth_dates`, `multiple_birth_places` | bool | Wikidata has conflicting values |

### `data/processed/player_units.csv`: English-born players placed on the map (3,017)

| Variable | Description |
|---|---|
| `fine` | `TRUE` = town-level birthplace (used at every level); `FALSE` = region-level ("London"), used at TTWA level only |
| `lad21cd`, `ttwa`, `hex10`, `hex20` | Area codes the birthplace falls in |
| `snapped_to_land` | Point moved ≤ 5 km from the sea onto land |
| other columns | as in `players_eligible` |

### `data/processed/exclusion_log.csv`: every excluded player
`player_qid`, `label`, `birth_date`, `reason` (no evidence of a tier 1–2 league appearance / born outside 1975–2005 / not male / sex not recorded).

---

## Clubs and academies

| File | Variables |
|---|---|
| `data/processed/club_season_tier.csv` | `season`, `tier` (1–4), `club_qid`, `club_name`, `source` (`engsoccerdata` / `wikipedia`) |
| `data/processed/club_season_ground.csv` | `season`, `tier`, `club_qid`, `club_name`, `venue_qid`, `venue_label`, `lon`, `lat`, `venue_basis` (`dated` / `undated` / `manual override` / `missing`) |
| `data/manual/club_qids.csv` | engsoccerdata club name → `club_qid`, with season range and matching `method` |
| `data/manual/club_qid_overrides.csv` | Manual club ID corrections (with notes) |
| `data/manual/club_ground_overrides.csv` | Temporary ground-shares (with notes) |
| `data/manual/category1_academies.csv` | `season`, `club_qid`, `club_name`, `basis` (from Wikipedia or imputed), `source_url`, `source_revid` |
| `data/manual/multi_lad_places.csv` | Birthplaces that span several local authorities (London) |

---

## Areas

### `data/processed/births_lad_year.csv`
| Variable | Description |
|---|---|
| `lad21cd`, `lad21nm` | Local authority district (April 2021 boundaries) |
| `birth_year` | 1975–2005 |
| `births_male` | Estimated male births (ONS mid-year estimates, boys aged under 1) |
| `baseline_method` | How the estimate was derived for that year |

### `data/processed/lad21_covariates.csv` and `ttwa_covariates.csv`
| Variable | Description |
|---|---|
| `lad21cd` / `ttwa_id`, `lad21nm` / `ttwa_nm` | Area code and name |
| `imd_score` | Population-weighted IMD 2025 score (higher = more deprived) |
| `urban_share` | Share of residents in urban LSOAs (RUC 2021), 0–1 |
| `dist_club_km` | Births-weighted distance (km) to the nearest tier 1–4 club ground in the season each birth cohort was aged 12 |
| `pop2022`, `n_lsoa`, `area_km2` | Population (mid-2022), number of LSOAs, area |

### `data/processed/lsoa21_england.csv`
`lsoa21cd`, `lad21cd`, `ttwa`, `bng_e`, `bng_n` (centroid, metres), `ruc21cd`, `urban`, `imd_score`, `pop2022`.

---

## Counts and results

### `data/processed/counts_{ttwa,lad21,hex10,hex20}.csv`
| Variable | Description |
|---|---|
| `unit` | Area code |
| `variant` | `main`, `certain`, `premier`, `cohort_75_89`, `cohort_90_05`, `no_ambiguous`, `pop_baseline` |
| `O` | Observed players born in the area |
| `E` | Expected players from births (or total population for `pop_baseline`) |
| `births` | Male births (or population) in the area, summed over 1975–2005 |
| `SR` | O / E |

### `data/processed/step6_{level}_{weights}.csv`: hotspot results per area
`O`, `E`, `SR`, `SR_EB` (Empirical Bayes-smoothed SR), `Gi_z` (Getis-Ord Gi\* z), `Gi_p` / `Gi_q` (permutation p / FDR q), `Gi_p_norm` / `Gi_q_norm` (normal-theory), `LISA_I`, `LISA_p`, `LISA_q`, `gi_class`, `lisa_class`, `level`, `weights`.

### Model outputs
| File | Contents |
|---|---|
| `step5_regions.csv` | Players, births, per 10,000 births, SR and Poisson p by region |
| `step5_tests.csv`, `step5_linhom_envelope.csv` | L-function tests and curve |
| `step6_global.csv` | EB Moran's I and counts of significant areas by level and weights |
| `step7_rate_ratios.csv` | `model`, `term` (`imd10`, `urban10`, `dist10`), `RR`, `lo`, `hi`, `p` |
| `step7_region_effects.csv` | Region rate ratios vs. West Midlands |
| `step7_spatial_*.csv`, `step7_model_fit.csv` | Spatial models, LM tests, AIC |
| `step7b_academy_*.csv` | Academy-era sub-model |
| `step8_rq4_countries.csv`, `step8_rq4_continents.csv` | Foreign-born counts, per million, by cohort |

---

## Dashboard data (`app/data/`)
Built by `analysis/dashboard/09_app_data.R`: `units.rds` (simplified areas + hotspot results), `births_unit_year.rds`, `players.rds`, `relative_risk.tif`, `tables.rds`, `world.rds`.
