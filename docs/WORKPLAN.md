# Work Plan — Football Talent Hotspots (England)

**Project:** Where Do England's Premier League and Championship Footballers Come From? Detecting Birthplace Hotspots Across English Local Areas Beyond Population Density
**Author:** Dennis Wambua
**Study population:** Players with Premier League or Championship careers, born 1975–2005
**Main analysis:** English-born players across English local areas
**Secondary analysis:** Countries supplying foreign-born players (descriptive)
**Duration:** 6 weeks
**Reference:** [Technical Research Proposal v2.1](Talent_Hotspots_Technical_Research_Proposal.pdf)
**Last updated:** 2 November 2026 (v2.1: births baseline, academy-era sub-model, club-tier gap, season rule, optional extensions)

The project runs in **8 steps**. Each step ends with a concrete output that is checked before moving on.

> **Time budget:** about 135 hours (≈22 h/week × 6 weeks). The **core** uses local authorities and hexagon grids with spatial error/lag models. Two items are **optional extensions**, done only if the core is finished: the **MSOA-level analysis** and the **BYM2 (R-INLA) model**. They are marked *(optional)* below.

---

## Research questions

| Code | Question |
|---|---|
| RQ1 | Are English-born PL/Championship players' birthplaces more clustered than population alone would predict? |
| RQ2 | Where in England are the significant hotspots and coldspots? |
| RQ3 | Are hotspots linked to deprivation, urbanisation, or distance to professional clubs and academies? |
| RQ4 | Which countries supply foreign-born players to the two leagues? (descriptive) |

---

## Overview

| Step | Name | Week | Milestone |**Title:** Feature Release: Mobile UI Polish, GW11 Caches, Dream Team World XI & Guest Demo Mode

**Description:**
|---|---|---|---|
| 1 | Project setup | 1 (days 1–2) | — |
| 2 | Get the player data and league eligibility | 1 (days 3–5) | M1 |
| 3 | Download and attach English area data | 2 (days 1–3) | — |
| 4 | Build analysis units and expected counts | 2 (days 4–5) | M2 |
| 5 | RQ1: Clustering beyond population | 3 | — |
| 6 | RQ2: Hotspot location | 4 | M3 |
| 7 | RQ3: Explaining the hotspots + RQ4: foreign-born supply | 5 | M4 |
| 8 | Dashboard, write-up and release | 6 | M5 |

---

## Step 1: Project setup (Week 1, days 1–2)

**Goal:** a working environment where R, Python and PostGIS all run.

- [ ] Create the GitHub repo `football-talent-hotspots` and push the folder structure. *(local Git repo created; push pending)*
- [x] Add the starter files:
  - [x] `README.md`
  - [x] `LICENSE` (MIT)
  - [x] `.gitignore` (keeps large data files out of Git)
  - [x] `.devcontainer/` (Codespaces setup)
  - [x] `docker-compose.yml` (PostGIS)
- [x] Check the environment (tested locally in the same Docker setup Codespaces uses):
  - [x] R loads `sf`, `terra`, `spatstat`, `spdep` and `engsoccerdata`
  - [x] Python loads `pandas`, `SPARQLWrapper` and `geopy`
  - [x] PostGIS starts and accepts a connection
- [x] Lock package versions: `renv.lock` for R (176 packages, R 4.5.1) and `requirements.txt` for Python.
- [ ] Confirm the dev container also builds in GitHub Codespaces (after push).

✅ **Output:** an environment you can rebuild with one click.

---

## Step 2: Get the player data and league eligibility (Week 1, days 3–5)

**Goal:** a clean list of players born 1975–2005 who played in the Premier League or Championship, with birthplaces.

- [x] Build the **club–season–tier table**: which clubs were in each division in each season from 1992/93. → `data/processed/club_season_tier.csv` (1985/86–2025/26, tiers 1–4)
  - [x] Seasons 1985/86–2024/25 from `engsoccerdata` (`R/01_club_tiers_engsoc.R`) — the package now runs to 2024/25.
  - [x] Missing seasons (**2022/23 and 2025/26** only) from Wikipedia league tables (`python/01_league_tables_wikipedia.py`), no hand compilation needed.
  - [x] Cross-checked 2016/17–2024/25 against Wikipedia: 32 season-tiers, 0 mismatches.
- [x] Map each club to its Wikidata ID (`python/02_club_qids.py`): 117 clubs, 9 manual fixes in `data/manual/club_qid_overrides.csv`.
- [x] Query players by club (`python/03_fetch_wikidata.py`): birthplace, coordinates, birth date, position, club start/end dates (+ precision) and matches played.
- [x] Save to `data/raw/` as dated Parquet snapshots (`wikidata_*_2026-11-02.parquet`).
- [x] Write down the **season assignment rule** *before* looking at the data (`python/season_rule.py`, 13 unit tests):
  - year-only **start** year Y → season beginning August Y (2004 → 2004/05)
  - year-only **end** year Y → season ending May Y (2004 → 2003/04)
  - full dates → the season that contains them (June/July → next season)
  - eligibility that depends on a year-only date in a promotion/relegation season → flag `season_ambiguous`
- [x] Keep players whose club membership overlaps a tier 1–2 season for that club; flag the Premier League subset (`python/04_eligibility.py`).
- [x] Clean the data:
  - [x] keep birth years 1975–2005
  - [x] remove duplicates
  - [x] remove points in the sea or in the wrong country (snapped ≤10 km to coast, else flagged)
  - [x] log every removed record with the reason (`data/processed/exclusion_log.csv`)
- [x] Split into **English-born** (main analysis) and **foreign / other UK-born** (descriptive) (`R/02_birth_country.R`).
- [x] Geocode the few birthplaces missing coordinates (`python/05_geocode_fallback.py`) — only 1 needed; also flags country/county-level birthplaces.
- [x] **Validate eligibility:** 200 random players (150 included + 50 excluded) checked against English Wikipedia infobox league appearances (`python/08_validate_wikipedia.py` → `data/manual/validation_sample_claude.csv`).
  - Wikidata-only rule: **false inclusions 18.6%**, false exclusions 6.8%, Premier League flag wrong 18.6% — mostly contracted/academy players with 0 league appearances.
  - **Decision point triggered → rule tightened** (`python/04b_appearance_evidence.py`): eligibility now needs evidence of ≥1 tier 1–2 league appearance — *certain* (spell entirely in tier 1–2 seasons) or *probable* (club changed division during the spell). Main analysis = certain + probable; sensitivity = certain only.
  - Also added: **men only** filter (160 women's players had been linked to men's club items).
  - Result: **6,581 study players**, **3,081 English-born** (3,017 with a town-level birthplace).

**Pipeline order (Step 2):** `R/01_club_tiers_engsoc.R` → `python/01_…` → `02_…` → `03_fetch_wikidata.py` → `04_eligibility.py` → `04b_appearance_evidence.py` → `05_geocode_fallback.py` → `R/02_birth_country.R` → `06_validation_sample.py`* → `08_validate_wikipedia.py`* → `07_quality_report.py`   (*only to redraw/recheck the validation sample)

✅ **Output:** `players_clean.parquet` plus a **data quality report** (players per season and club, % with coordinates, English-born share, records removed, % ambiguous, validation error rate). ← **Milestone M1**

🔎 **Decision point:** if the validation error rate is high, tighten the eligibility rule (e.g. require matches played) before continuing.

---

## Step 3: Download and attach English area data (Week 2, days 1–3)

**Goal:** population, deprivation, urbanisation and club/academy distances for English areas.

- [x] Download from the ONS Open Geography Portal (`python/11_ons_boundaries.py`): **LAD 2021** (309 in England) and **LSOA 2021** boundaries, plus the LSOA→LAD 2021 lookup. MSOA skipped (optional extension).
  - LAD **2021** rather than current boundaries: the only LAD series back-cast to 1981 on Nomis.
- [x] Births baseline (`python/10_births_baseline.py`). **Change:** ONS LA live births on Nomis start in **2013**, so the baseline is **male infants aged under 1** from ONS mid-year estimates (NM_31_1, 1981→), averaged over two mid-years; 1976–80 from ages 1–4 in 1981, 1975 from ages 5–9 in 1981. No gaps for any of the 309 LADs.
- [x] ONS mid-year total population 1981–2005 saved for the total-population sensitivity analysis.
- [x] English Indices of Deprivation **2025** (LSOA 2021), File 7.
- [x] Rural-Urban Classification **2021** (LSOA), from the same ONS LSOA layer.
- [ ] GHS-POP 1 km grids — **moved to Step 5**, where the point-pattern intensity surface is built.
- [x] Club ground locations for all professional clubs by season (`python/09_club_grounds.py`): Wikidata home venues + 6 documented ground-share overrides (`data/manual/club_ground_overrides.csv`).
- [ ] Category 1 academy list (2012 onward) — **template only** (`data/manual/category1_academies.csv`); no authoritative list exists, so it is compiled club by club with a source URL before the Step 7 sub-model.
- [x] `R/03_area_covariates.R` per LAD (→ `data/processed/lad21_covariates.csv`):
  - [x] population-weighted IMD score
  - [x] urban share
  - [x] births-weighted distance to the nearest professional club **in the season each cohort was aged 12**
  - [ ] distance to nearest Category 1 academy — after the academy list is compiled
  - all distances in EPSG:27700
- Report: `docs/reports/data_quality_step3.md`

✅ **Output:** an enriched area table for England.

---

## Step 4: Build analysis units and expected counts (Week 2, days 4–5)

**Goal:** observed vs. expected player counts for each area.

All in `R/04_expected_counts.R`; tests in `tests/test_counts.py`.

- [x] Create the 10 km and 20 km hexagon grids in British National Grid (EPSG:27700): 1,551 and 439 populated hexagons.
- [x] **New unit: Travel to Work Areas 2011** (155 in England). Added because LAD results showed a strong **hospital effect** (birthplaces recorded at the maternity-hospital town: e.g. Oxford SR 3.68 while its four neighbouring districts are 0.00–0.60; Oxfordshire combined 0.92). TTWAs contain a town and its catchment. **Main unit for Steps 5–7 (decided 18 Nov 2026)**; LADs and 20 km hexagons kept for comparison, 10 km hexagons exploratory only (too sparse). TTWA covariates: `data/processed/ttwa_covariates.csv`. Report: `docs/reports/step4_report.md`.
- [x] **"London" birthplaces** (98 players; Wikidata point at Charing Cross) reclassified as region-level (`data/manual/multi_lad_places.csv`): used at TTWA level only (London TTWA covers all boroughs).
- [x] Load everything into PostGIS (schema `talent`: lad21, ttwa11, hex10, hex20, players, counts_*) with GiST indexes.
- [x] For each unit (LAD, TTWA, both hexagon grids; MSOA skipped), calculate O, E (male-births baseline), SR — for 7 variants: main, certain, premier, cohort_75_89, cohort_90_05, no_ambiguous, pop_baseline.
- [x] No missing births (Step 3), so no fallback needed; total-population baseline computed as the `pop_baseline` variant.
- [x] Run the checks (all pass, 34 tests):
  - [x] births fully allocated to every unit type; ΣO = ΣE for every level and variant
  - [x] every English-born point placed (1 snapped from the coast ≤5 km; 0 unplaced)
- Maps: `docs/reports/figures/step4_sr_lad21_main.png`, `step4_sr_ttwa_main.png`

✅ **Output:** an analysis-ready database. ← **Milestone M2**

---

## Step 5: RQ1, is there clustering beyond population? (Week 3)

All in `R/05_clustering.R` (outputs `data/processed/step5_*.csv`, `docs/reports/figures/step5_*.png`).

- [x] Players per 10,000 male births by region (9 English regions; Poisson test vs. births): London 4.56 (SR 1.44), North West 4.29 (1.36) … South East 2.13 (0.67), South West 1.87 (0.59); 7 of 9 regions differ significantly (p < 0.05). TTWA/LAD SR maps in Step 4.
- [x] KDE maps of players and of male births (σ = 15 km), plus a relative-risk surface (births instead of total population — consistent with the expected counts).
- [x] Inhomogeneous L-function within England (births intensity, σ = 2 km; border correction; r ≤ 60 km), **95% global envelope from 999 simulations**:
  - global tests, r 0–60 km: **MAD p = 0.032, DCLF p = 0.022**; r 20–60 km: MAD p = 0.051, DCLF p = 0.031
  - observed L(r) − r ≈ +6 km at all distances; above the 95% band only at 1–3 km (short range affected by shared town coordinates and the hospital effect)
- [x] **Null test** passed: births-only fake players, MAD p = 0.50 (0–60 km), 0.48 (20–60 km).
- **RQ1 answer:** yes — clear, highly significant **regional** differences in players per birth, plus **modest but significant** clustering beyond births at local–regional scales (DCLF p = 0.02–0.03).

✅ **Output:** clustering plots and maps, with a short written interpretation.

---

## Step 6: RQ2, where are the hotspots? (Week 4)

All in `R/06_hotspots.R` (outputs `data/processed/step6_*.csv`, `docs/reports/figures/step6_*.png`).

- [x] Apply Empirical Bayes smoothing to the SR (`spdep::EBest`).
- [x] Global EB Moran's I (999 permutations): **TTWA I = 0.27, p = 0.001** (queen and knn6); LAD 0.03–0.05 (p 0.04–0.21); 20 km hexagons 0.02–0.05 (p 0.02–0.22).
- [x] Local Getis-Ord Gi\* and LISA with FDR correction. **Change:** 9,999 permutations for local tests — with 999 the minimum p (0.001) can never pass FDR over 155+ units.
  - TTWA (queen): **no unit at FDR q < 0.05**; Warrington & Wigan q = 0.062; 7 hot (North West / Pennine belt) and 11 cold (South coast, Kent) at unadjusted p < 0.05.
  - Sensitivity, normal-theory p: 5 North West / Yorkshire hotspots pass FDR (Warrington & Wigan, Preston, Barnsley, Manchester…).
  - Results shown in evidence tiers (FDR q<0.05 / q<0.10 / exploratory p<0.05).
- [x] Repeat at LAD (queen, knn6) and 20 km hexagons (knn 4/6/8); queen vs knn6 at TTWA: 87% agreement, Gi\* z correlation 0.90. 10 km hexagons not used (too sparse, Step 4).
- [ ] *(optional)* MSOA level — not done.
- **RQ2 answer:** a broad, significant **north-west vs. south/south-east gradient** (global clustering strong) rather than sharp local hotspots; strongest candidate cluster around Warrington–Wigan–Preston–Manchester (between the Liverpool and Manchester high areas), coldest along the South coast and Kent.

✅ **Output:** England hotspot and coldspot maps plus a ranked list of top hotspots. ← **Milestone M3**

---

## Step 7: RQ3 explaining the hotspots, and RQ4 foreign-born supply (Week 5)

**RQ3**
All in `R/07_models.R` (outputs `data/processed/step7_*.csv`, `docs/reports/figures/step7_rate_ratios.png`). Unit: 155 TTWAs.

- [x] **Main** negative binomial model (offset log E; Poisson dispersion 2.28 → NB): IMD, urban share, distance to nearest professional club at age 12, + region fixed effects (VIF ≤ 1.8). Region effects improve fit (LR χ² = 24.8, df 8, p = 0.002).
  - **Distance to club: RR 0.86 per +10 km (95% CI 0.79–0.93, p = 0.0004)** — robust.
  - Deprivation: RR 1.14 per +10 IMD points without region (p = 0.03) → **0.95 (p = 0.46) with region**: the deprivation link is a proxy for the North.
  - Urban share: no effect (RR 1.04, p = 0.18).
  - Region RR vs. West Midlands: North West 1.39, North East 1.39, Yorkshire 1.17, London 1.10 … South East 0.78, South West 0.77.
- [x] **Category 1 academy list** (`python/13_category1_academies.py` → `data/manual/category1_academies.csv`): clubs in "League 1" of each season's U18 national league (Category 1 only), Wikipedia season articles with revision ids; 21–26 academies per season, 28 clubs in total, 2012/13–2021/22 (2012/13 and 2021/22 imputed from the nearest season — no article).
- [x] **Academy-era sub-model** (`R/07b_academy_model.R`; 594 players born 1996–2005): distance to any professional club **RR 0.74 per +10 km (p < 0.001)**; distance to a Category 1 academy **RR 1.00 (p = 0.93)**; both together 0.73 / 1.03 — proximity to *any* club matters, not to an elite academy. (Club stadium used as a proxy for the academy location.)
- [x] Club-distance effect before vs. after EPPP (cohorts): RR 0.91 (1975–89, p = 0.06) vs. **0.76 (1990–2005, p < 0.001)**.
- [x] Residual spatial autocorrelation: M1 Moran's I 0.17 (p = 0.002) → **M2 0.03 (p = 0.26)**: region effects absorb it. Robust LM tests all non-significant (p ≥ 0.30); spatial error (λ = 0.07, p = 0.56) and lag (ρ = 0.03, p = 0.77) models add nothing (OLS lowest AIC) and confirm the distance effect (p ≈ 0.015).
- [ ] *(optional)* BYM2 with R-INLA — not done.
- [x] Robustness checks (M2 rate ratio for distance per +10 km, all < 1):
  - [x] cohort split: 0.91 / 0.76
  - [x] Premier League subset: 0.86 (p = 0.006)
  - [x] excluding the 5 largest-city TTWAs: 0.85 (p < 0.001)
  - [ ] truncating the cohort at 2002 — not run (covered by the 1990–2005 cohort result)
  - [x] other scales: LAD 0.94 (p = 0.26; LAD estimates distorted by the hospital effect — IMD and urban turn positive there)
  - [x] total-population baseline: 0.84 (p < 0.001)
  - [x] excluding `season_ambiguous`: 0.86 (p = 0.001); certain-evidence only: 0.85 (p = 0.002)

**RQ4**
All in `R/08_foreign_born.R` (+ `python/14_country_population.py`); maps `docs/reports/figures/rq4_*.png`.

- [x] Count foreign-born and other UK-born players by country of birth: 6,581 study players from 143 countries/UK nations; 46.8% England, 6.7% other UK nations, 46.3% outside the UK. Top: France 372, Scotland 233, Ireland 223, Spain 222, Netherlands 161.
- [x] Players per million national population (mean 1975–2005): **World Bank WDI** (derived from UN WPP) instead of downloading UN WPP directly; ONS for England/Scotland/Wales; none for Northern Ireland. Highest (≥10 players): Iceland 106, England 64, Ireland 62, Scotland 46, Wales 41.
- [x] Cohorts 1975–1989 vs 1990–2005: England share 45% → 49%; other UK nations 8.1% → 4.6% (Scotland 179 → 54); outside UK ~46% both; within non-UK players Europe 63% → 67%, Africa 14% → 11%, Asia 3% → 4%.

✅ **Output:** results tables (rate ratios, confidence intervals, AIC), a robustness summary, and a foreign-born supply map. ← **Milestone M4**

---

## Step 8: Dashboard, write-up and release (Week 6)

- [x] Build the Shiny app (`app/app.R`, data from `R/09_app_data.R`, ~2 MB; tests `R/tests/test_app.R`):
  - [x] England hotspot map — TTWA / LAD / 20 km hexagons; smoothed SR, raw SR or Gi\* classes; popups with O, E, SR, Gi\*
  - [x] players map — clustered birthplaces with public Wikidata details
  - [x] density explorer — relative-risk raster, L-function with envelope, global tests, regional table
  - [x] drivers panel — rate-ratio forest plot, region effects, SR vs. club distance, academy sub-model
  - [x] foreign-born world map — per million / counts, by cohort, top-25 table
  - [x] filters — birth years, Premier League only, certain evidence only, position; O/E and Empirical Bayes SR recomputed live (region filter replaced by the map itself)
  - [x] About page — findings, how to read, limitations, sources and licence statements
- [ ] Deploy it to shinyapps.io — script ready (`R/10_deploy.R`); **needs your shinyapps.io account token in `.env`**.
- [x] Write the final report: methods, results, limitations → `docs/reports/final_report.md` (+ step reports 2–7).
- [x] Clean up the repo:
  - [x] a README that explains how to rerun everything (+ `run_all.sh` for the full pipeline)
  - [x] the data dictionary → `docs/DATA_DICTIONARY.md`
  - [x] the exclusion log and eligibility validation report → `data/processed/exclusion_log.csv`, `data/manual/validation_sample_claude.csv`, Step 2 report
  - [x] tests passing (34 Python, R environment, dashboard)
- [ ] Tag the release as `v1.0` — **yours** (commit, tag and push are done by you).

✅ **Output:** the public dashboard, final report and code release. ← **Milestone M5**

---

## Data sources (all free)

| Data | Source | Licence |
|---|---|---|
| Players, clubs, dates, birthplaces | Wikidata | CC0 |
| Club division by season, 1992/93–2015/16 | engsoccerdata (R) | Open source |
| Club division by season, 2016/17–2025/26 | Compiled from league tables / Wikidata | Public / CC0 |
| Live births by local authority (primary baseline) | ONS | Open Government Licence |
| Population estimates (fallback baseline) | ONS via Nomis | Open Government Licence |
| Boundaries (LAD, MSOA, LSOA) | ONS Open Geography Portal | Open Government Licence |
| Deprivation (IMD) | MHCLG | Open Government Licence |
| Rural-Urban Classification | ONS | Open Government Licence |
| Population grid | GHS-POP (EU JRC) | CC BY 4.0 |
| Country populations | UN World Population Prospects | CC BY 3.0 IGO |

---

## Working approach

- **One step at a time:** scripts are written, run and their output checked before moving on.
- **Every step ends with a check:** a report, a map or a test, so problems are caught early.
- **Commit to Git after each step**, so progress is saved and reversible.

## Repository structure

```
football-talent-hotspots/
├── .devcontainer/        # Codespaces configuration
├── app/                  # R Shiny dashboard
├── data/
│   ├── raw/              # Dated Wikidata snapshots, ONS downloads (not in Git)
│   └── processed/        # Cleaned and enriched data (not in Git)
├── docs/                 # Proposal, work plan, reports
├── python/               # Data acquisition and geocoding
├── R/                    # Spatial processing, statistics, modelling
├── sql/                  # PostGIS schema and queries
├── tests/                # Unit and integration tests
├── docker-compose.yml    # PostGIS service
├── LICENSE
└── README.md
```
