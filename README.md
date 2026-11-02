# football-talent-hotspots

**Where do England's Premier League and Championship footballers come from?**

A spatial analysis of the birthplaces of players born 1975–2005 who played in the top two English divisions. The main analysis asks whether English-born players come from particular areas of England **more often than the number of births there would predict**, where the significant hotspots and coldspots are, and whether deprivation, urbanisation and distance to professional clubs and academies help explain them. A secondary, descriptive analysis maps the countries that supply foreign-born players.

Author: **Dennis Wambua**

## Documents

| File | What it is |
|---|---|
| [Technical Research Proposal (PDF)](docs/Talent_Hotspots_Technical_Research_Proposal.pdf) | Full research design (v2.1) |
| [WORKPLAN.md](docs/WORKPLAN.md) | Step-by-step tasks and progress |
| [STATISTICAL_METHODS.md](docs/STATISTICAL_METHODS.md) | Plain-language guide to the methods |

## Running the project

Everything runs in Docker, so the same environment works on a laptop and in GitHub Codespaces.

### Option A: GitHub Codespaces
Open the repo → **Code → Codespaces → Create codespace**. The dev container builds R, Python and PostGIS automatically. A `.env` file is created from `.env.example` on first start.

### Option B: Local machine (Docker required)
```bash
cp .env.example .env          # then change the password
docker compose up -d --build  # starts the app and PostGIS containers
docker compose exec app bash  # open a shell inside the app container
```

### Check the environment
Inside the app container:
```bash
Rscript R/tests/test_environment.R   # R packages, coordinate round-trip, PostGIS from R
pytest tests/                        # Python packages, PostGIS from Python
Rscript R/00_setup.R                 # (re)write renv.lock with exact R package versions
```

### Connecting to the database
| From | Host | Port |
|---|---|---|
| Inside the app container | `db` | `5432` |
| Your own machine | `localhost` | `5433` (`POSTGRES_HOST_PORT`) |

## Repository structure
```
├── .devcontainer/     Dev container (R 4.5.1 + GDAL/GEOS/PROJ, Python venv)
├── app/               R Shiny dashboard
├── data/raw/          Dated raw downloads (not in Git)
├── data/processed/    Cleaned and derived data (not in Git)
├── data/manual/       Small hand-compiled inputs (in Git)
├── docs/              Proposal, work plan, methods guide, reports
├── python/            Data acquisition (Wikidata, geocoding)
├── R/                 Spatial processing, statistics, modelling
├── sql/               PostGIS schema and queries
├── tests/             Python tests (R tests in R/tests/)
├── docker-compose.yml App + PostGIS services
├── DESCRIPTION        R dependencies (read by renv)
├── renv.lock          Exact R package versions
└── requirements.txt   Exact Python package versions
```

## Conventions
- Coordinates are **stored** in EPSG:4326, **measured** (distances, areas, grids) in EPSG:27700 (British National Grid), and **displayed** in EPSG:3857.
- Raw downloads are saved as dated snapshots, e.g. `data/raw/wikidata_2026-11-02.parquet`.
- Every record removed during cleaning is logged with a reason.
- All simulations, permutations and jitter use fixed random seeds.

## Data sources and licences
| Data | Source | Licence |
|---|---|---|
| Players, clubs, birthplaces | Wikidata | CC0 |
| Club division by season (to 2015/16) | engsoccerdata (J. Curley) | Open source |
| Club division by season (2016/17–2025/26) | Compiled from league tables / Wikidata | Public / CC0 |
| Live births and population estimates | Office for National Statistics | Open Government Licence v3.0 |
| Boundaries (LAD, MSOA, LSOA) | ONS Open Geography Portal | Open Government Licence v3.0 |
| English Indices of Deprivation | MHCLG | Open Government Licence v3.0 |
| Rural-Urban Classification | ONS | Open Government Licence v3.0 |
| Population grid | GHS-POP, EU JRC | CC BY 4.0 |
| Country populations | UN World Population Prospects | CC BY 3.0 IGO |

Contains public sector information licensed under the Open Government Licence v3.0.

## Licence
Code: [MIT](LICENSE). Derived aggregated data: CC BY 4.0, with attribution to the sources above.
