# football-talent-hotspots

**Where do England's Premier League and Championship footballers come from?**

A spatial analysis of the birthplaces of **6,581 men born 1975–2005** who made at least one league appearance in the Premier League or the second tier (1992/93–2025/26). The main analysis compares the **3,081 English-born** players with **9.5 million male births** across England's 155 Travel to Work Areas, to find where players come from **more often than births predict**, and why.

Author: **Dennis Wambua**

## Main findings

1. **A north-west vs. south/south-east gradient.** London and the North West produce about **2.4×** as many players per birth as the South West. The strongest cluster is the **Merseyside–Lancashire–Greater Manchester belt** (Liverpool: 2.2× expected).
2. **Proximity to a professional club matters.** Each extra 10 km to the nearest league club at age 12 means **~14% fewer players** (rate ratio 0.86, 95% CI 0.79–0.93), more so for players born since 1990.
3. **Elite academies don't.** Distance to a Category 1 academy has no effect (rate ratio 1.00).
4. **Deprivation and urbanisation don't explain the pattern** once region is taken into account.
5. **About half the players were born outside England.** Ireland, Scotland, Wales and Iceland supply the most per head.

Full write-up: **[Final report](docs/reports/final_report.md)**.

## Documents

| Document | What it is |
|---|---|
| [Final report](docs/reports/final_report.md) | Findings, methods, limitations, changes from the proposal |
| Step reports: [2](docs/reports/step2_report.md) · [3](docs/reports/step3_report.md) · [4](docs/reports/step4_report.md) · [5](docs/reports/step5_report.md) · [6](docs/reports/step6_report.md) · [7](docs/reports/step7_report.md) | Detailed process, challenges and decisions for each step |
| [Data quality: Step 2](docs/reports/data_quality_step2.md) · [Step 3](docs/reports/data_quality_step3.md) | Generated data quality reports |
| [Technical Research Proposal (PDF)](docs/Talent_Hotspots_Technical_Research_Proposal.pdf) | Original research design (v2.1) |
| [Work plan](docs/WORKPLAN.md) | Task checklist with results and decisions |
| [Statistical methods guide](docs/STATISTICAL_METHODS.md) | Plain-language explanation of every method |
| [Data dictionary](docs/DATA_DICTIONARY.md) | Variables in the output files |

## Dashboard

An R Shiny + Leaflet dashboard (`app/`): hotspot maps at three scales with live filters (birth years, Premier League only, certain evidence, position), player birthplaces, clustering results, model results and the foreign-born world map.

```bash
docker compose up -d
docker compose exec app Rscript -e 'shiny::runApp("app", host = "0.0.0.0", port = 3838)'
# open http://localhost:3838
```

Deploying to shinyapps.io: add your account token to `.env` (see `.env.example`), then `docker compose exec app Rscript R/10_deploy.R`.

## Running the project

Everything runs in Docker, so the same environment works on a laptop and in GitHub Codespaces (R 4.5.1 with GDAL/GEOS/PROJ, Python 3.12, PostgreSQL 16 + PostGIS 3.5).

### Setup
```bash
cp .env.example .env          # then set a database password
docker compose up -d --build  # app + PostGIS containers
```
Or open the repository in **GitHub Codespaces**; the dev container is built automatically.

One manual download: **English Indices of Deprivation 2025, File 7** (CSV) from
[GOV.UK](https://www.gov.uk/government/statistics/english-indices-of-deprivation-2025), saved to `data/raw/imd/`.

### Full pipeline
```bash
docker compose exec app bash run_all.sh    # ~1–1.5 hours, needs internet access
```

| Step | Scripts | Output |
|---|---|---|
| 2 Players & eligibility | `R/01_club_tiers_engsoc.R`, `python/01`–`05`, `04b`, `R/02_birth_country.R`, `python/07` | `players_eligible.parquet`, exclusion log, quality report |
| 2 Validation | `python/06_validation_sample.py`, `python/08_validate_wikipedia.py` | 200-player validation |
| 3 Area data | `python/09`–`12`, `R/03_area_covariates.R` | births, IMD, urban share, club distance |
| 4 Expected counts | `R/04_expected_counts.R` | O, E, SR for 4 unit types × 7 variants; PostGIS |
| 5 Clustering (RQ1) | `R/05_clustering.R` | L-function, regional table, maps |
| 6 Hotspots (RQ2) | `R/06_hotspots.R` | EB Moran's I, Gi\*, LISA, maps |
| 7 Models (RQ3) & foreign-born (RQ4) | `R/07_models.R`, `python/13`–`14`, `R/07b_academy_model.R`, `R/08_foreign_born.R` | rate ratios, robustness, academy model, world map |
| 8 Dashboard | `R/09_app_data.R`, `app/app.R`, `R/10_deploy.R` | Shiny app |

### Tests
```bash
docker compose exec app pytest tests/                      # season rule, count integrity (34 tests)
docker compose exec app Rscript R/tests/test_environment.R # packages, CRS round-trip, PostGIS
docker compose exec app Rscript R/tests/test_app.R         # every dashboard output renders
```

### Database
| From | Host | Port |
|---|---|---|
| Inside the app container | `db` | `5432` |
| Your own machine | `localhost` | `5433` |

Schema `talent`: `lad21`, `ttwa11`, `hex10`, `hex20`, `players`, `counts_*` (GiST-indexed).

## Repository structure
```
├── .devcontainer/     Dev container (R 4.5.1 + spatial libraries, Python venv)
├── app/               Shiny dashboard (app.R, about.md, data/)
├── data/raw/          Dated raw downloads (not in Git)
├── data/processed/    Derived data (not in Git)
├── data/manual/       Small hand-checked inputs: overrides, academy list, validation (in Git)
├── docs/              Proposal, work plan, methods guide, data dictionary, reports, figures
├── python/            Data acquisition, eligibility, validation, reports
├── R/                 Spatial processing, statistics, models, dashboard data, tests
├── sql/               PostGIS initialisation
├── tests/             Python tests
├── docker-compose.yml App + PostGIS services
├── run_all.sh         Full pipeline
├── DESCRIPTION / renv.lock / requirements.txt   Exact package versions
```

## Conventions
- Coordinates **stored** in EPSG:4326, **measured** in EPSG:27700 (British National Grid), **displayed** in EPSG:3857.
- Raw downloads are dated snapshots (e.g. `wikidata_players_2026-11-02.parquet`).
- Every excluded player is logged with a reason (`data/processed/exclusion_log.csv`).
- All simulations and permutations use fixed seeds.

## Data sources and licences

| Data | Source | Licence |
|---|---|---|
| Players, clubs, birthplaces | Wikidata | CC0 |
| League appearances, league tables, U18 leagues | English Wikipedia | CC BY-SA 4.0 |
| Club divisions to 2024/25 | engsoccerdata (J. Curley) | GPL (≥ 2) |
| Population estimates (births proxy), boundaries, Rural-Urban Classification, TTWAs | Office for National Statistics | Open Government Licence v3.0 |
| English Indices of Deprivation 2025 | MHCLG | Open Government Licence v3.0 |
| Country populations | World Bank WDI | CC BY 4.0 |
| World boundaries | Natural Earth | Public domain |

Contains public sector information licensed under the Open Government Licence v3.0. Contains OS data © Crown copyright and database right.

## Licence
Code: [MIT](LICENSE). Derived aggregated data: CC BY 4.0, with attribution to the sources above.
