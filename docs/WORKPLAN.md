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

| Step | Name | Week | Milestone |
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

- [ ] Build the **club–season–tier table**: which clubs were in each division in each season from 1992/93.
  - [ ] Seasons 1992/93–2015/16 from `engsoccerdata`.
  - [ ] **Compile 2016/17–2025/26 by hand** (≈10 seasons × 92 clubs) from published league tables and Wikidata season items. Budget a few hours for this.
  - [ ] Cross-check promotions and relegations for every compiled season.
- [ ] Map each club to its Wikidata ID.
- [ ] Write `python/01_fetch_wikidata.py`: query players by batches of clubs, pulling birthplace, coordinates, birth date, position, club start/end dates and matches played.
- [ ] Save each batch to `data/raw/` as a dated Parquet snapshot.
- [ ] Write down the **season assignment rule** *before* looking at the data:
  - year-only **start** year Y → season beginning August Y (2004 → 2004/05)
  - year-only **end** year Y → season ending May Y (2004 → 2003/04)
  - full dates → the season that contains them (June/July → next season)
  - eligibility that depends on a year-only date in a promotion/relegation season → flag `season_ambiguous`
- [ ] Keep players whose club membership overlaps a tier 1–2 season for that club; flag the Premier League subset.
- [ ] Clean the data:
  - [ ] keep birth years 1975–2005
  - [ ] remove duplicates
  - [ ] remove points in the sea or in the wrong country
  - [ ] log every removed record with the reason
- [ ] Split into **English-born** (main analysis) and **foreign / other UK-born** (descriptive).
- [ ] Geocode the few birthplaces missing coordinates (`python/02_geocode_fallback.py`).
- [ ] **Validate eligibility:** check 200 random players against published season squad lists, including how often the season rule gets ambiguous cases wrong.

✅ **Output:** `players_clean.parquet` plus a **data quality report** (players per season and club, % with coordinates, English-born share, records removed, % ambiguous, validation error rate). ← **Milestone M1**

🔎 **Decision point:** if the validation error rate is high, tighten the eligibility rule (e.g. require matches played) before continuing.

---

## Step 3: Download and attach English area data (Week 2, days 1–3)

**Goal:** population, deprivation, urbanisation and club/academy distances for English areas.

- [ ] Download from the ONS Open Geography Portal: local authority district, MSOA and LSOA boundaries for England.
- [ ] Download ONS **live births by local authority and year** (male births where available) — the **primary baseline**.
  - [ ] Record which years/areas lack births data on current boundaries.
- [ ] Download ONS mid-year population estimates for local authorities, 1981 onward (Nomis) — **fallback baseline** and sensitivity analysis.
- [ ] Download the English Indices of Deprivation (IMD) at LSOA level.
- [ ] Download the ONS Rural-Urban Classification.
- [ ] Download GHS-POP 1 km grids for England (population surface for point-pattern analysis).
- [ ] Build club ground locations (Wikidata home venue coordinates) for **all professional clubs by season**, and the list of Category 1 academies (2012 onward).
- [ ] Use `R/03_area_covariates.R` to calculate per area:
  - [ ] population-weighted IMD score
  - [ ] urban share
  - [ ] cohort-weighted distance to the nearest professional club **in the season each cohort was aged 12** (all cohorts)
  - [ ] distance to nearest Category 1 academy (**players born 1996–2005 only**, i.e. aged ≤16 when EPPP began)
  - all distances in EPSG:27700

✅ **Output:** an enriched area table for England.

---

## Step 4: Build analysis units and expected counts (Week 2, days 4–5)

**Goal:** observed vs. expected player counts for each area.

- [ ] Create the 10 km and 20 km hexagon grids in British National Grid (EPSG:27700).
- [ ] Load everything into PostGIS (`sql/` scripts) with GiST indexes.
- [ ] For each unit (local authority, both hexagon grids; MSOA *(optional)*), calculate:
  - **O** = players born there
  - **E** = Σ over birth years of **area births** × England's player rate per birth that year
  - **SR** = O / E
- [ ] Where births are missing, use the population fallback (1981 estimates for 1975–1980) and record `baseline_type`.
- [ ] Run the checks:
  - [ ] local authority births sum to the England total (within 1%)
  - [ ] every English-born point falls inside England

✅ **Output:** an analysis-ready database. ← **Milestone M2**

---

## Step 5: RQ1, is there clustering beyond population? (Week 3)

- [ ] Map players per 100,000 population by region and local authority.
- [ ] Make KDE maps of players and of population, plus a relative risk surface.
- [ ] Run inhomogeneous Ripley's K/L within England, with 999 simulations.
- [ ] Run the **null test**: simulate players placed only by population, which should show **no** clustering.

✅ **Output:** clustering plots and maps, with a short written interpretation.

---

## Step 6: RQ2, where are the hotspots? (Week 4)

- [ ] Apply Empirical Bayes smoothing to the SR.
- [ ] Calculate global EB Moran's I (999 permutations).
- [ ] Run local Getis-Ord Gi\* and LISA, with FDR correction (q = 0.05).
- [ ] Repeat at every core scale (local authority, 10 km, 20 km) and neighbour definition.
- [ ] *(optional)* Repeat at MSOA level.

✅ **Output:** England hotspot and coldspot maps plus a ranked list of top hotspots. ← **Milestone M3**

---

## Step 7: RQ3 explaining the hotspots, and RQ4 foreign-born supply (Week 5)

**RQ3**
- [ ] Fit the **main** negative binomial model (all cohorts): counts with an offset for expected counts, plus IMD, urban share, distance to nearest professional club, and region effects.
- [ ] Fit the **academy-era sub-model** (born 1996–2005 only): add distance to nearest Category 1 academy.
- [ ] Compare the club-distance effect before vs. after EPPP.
- [ ] Test the residuals for spatial autocorrelation, then fit a Spatial Error or Spatial Lag model as needed.
- [ ] *(optional)* Fit a BYM2 model with R-INLA.
- [ ] Run all the robustness checks:
  - [ ] cohort split (1975–1989 vs. 1990–2005, i.e. before / after EPPP)
  - [ ] Premier League subset vs. all study players
  - [ ] excluding the biggest cities (London, Birmingham, Manchester, Liverpool, Leeds)
  - [ ] truncating the cohort at 2002
  - [ ] other spatial scales and neighbour definitions
  - [ ] total-population baseline instead of births
  - [ ] excluding `season_ambiguous` players

**RQ4**
- [ ] Count foreign-born and other UK-born players by country of birth.
- [ ] Calculate players per million national population (UN World Population Prospects).
- [ ] Compare the 1975–1989 and 1990–2005 cohorts.

✅ **Output:** results tables (rate ratios, confidence intervals, AIC), a robustness summary, and a foreign-born supply map. ← **Milestone M4**

---

## Step 8: Dashboard, write-up and release (Week 6)

- [ ] Build the Shiny app (`app/`):
  - [ ] England hotspot map
  - [ ] density explorer
  - [ ] drivers panel (deprivation, distances)
  - [ ] foreign-born world map
  - [ ] filters (league, cohort, position, region)
- [ ] Deploy it to shinyapps.io.
- [ ] Write the final report: methods, results, limitations.
- [ ] Clean up the repo:
  - [ ] a README that explains how to rerun everything
  - [ ] the data dictionary
  - [ ] the exclusion log and eligibility validation report
  - [ ] tests passing
- [ ] Tag the release as `v1.0`.

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
