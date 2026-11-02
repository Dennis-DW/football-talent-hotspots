# Agent Prompt — Football Talent Hotspots (England)

Copy the **Master prompt** into a new AI coding session (e.g. Claude Code) opened in the repo root. Then use the **Step prompts** one at a time.

---

## Master prompt

```
You are helping me build a research project called football-talent-hotspots.

CONTEXT
- Read docs/Talent_Hotspots_Technical_Research_Proposal.pdf (v2.1) and docs/WORKPLAN.md first.
  They are the source of truth. If anything I ask conflicts with them, point it out before acting.
- Research question: where in England are Premier League and Championship players born,
  beyond what births predict? (RQ1 clustering, RQ2 hotspots, RQ3 explanatory factors,
  RQ4 descriptive map of foreign-born supply.)
- Study population: men who played for a club during a season when it was in the
  Premier League or second tier, born 1975-01-01 to 2005-12-31.
  Main analysis = English-born players; foreign/other UK-born = descriptive only.

TECH STACK
- R (sf, terra, spatstat, spdep >= 1.3, spatialreg, MASS, engsoccerdata, tidyverse, shiny, leaflet), locked with renv.
- Python 3.11+ (pandas, pyarrow, requests, SPARQLWrapper, geopy, pytest), pinned in requirements.txt.
- PostgreSQL 16 + PostGIS 3 via docker-compose.
- Runs in GitHub Codespaces (.devcontainer).

RULES
1. Work one WORKPLAN step at a time. Do not start the next step until I confirm.
2. Before writing code, give me a short plan (files to create, what each does). Wait for "go".
3. Coordinate systems: store EPSG:4326; measure distances, areas and grids in EPSG:27700;
   use EPSG:3857 for map display only.
4. Raw downloads go in data/raw/ as dated snapshots (e.g. wikidata_2026-11-02.parquet).
   Processed outputs go in data/processed/. Neither is committed to Git.
5. Every record removed during cleaning is written to an exclusion log with a reason.
6. Use fixed random seeds for any simulation, permutation or jitter.
7. Respect API limits: Wikidata SPARQL in small batches with retries and a descriptive
   User-Agent; Nominatim max 1 request/second.
8. Write tests for anything that transforms data (pytest for Python, testthat for R).
9. Never invent data, IDs, URLs or package functions. If unsure, say so and check.
10. End every step with: what was done, files changed, how to run it, test results,
    and anything I need to decide.
```

---

## Step prompts

### Step 1 — Project setup

```
Do WORKPLAN Step 1 (Project setup).

Create:
- Folder structure: data/raw, data/processed, R/, python/, sql/, app/, docs/, tests/
  (add .gitkeep in empty folders).
- README.md: project title, one-paragraph summary, how to open in Codespaces,
  how to run each step, data sources and licences, author Dennis Wambua.
- LICENSE (MIT, Dennis Wambua, 2026).
- .gitignore: data/raw/*, data/processed/*, .Rhistory, .RData, renv/library,
  __pycache__, .env, *.gpkg, *.tif (keep .gitkeep files).
- .env.example with POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB, POSTGRES_PORT.
- docker-compose.yml: postgis/postgis:16-3.4 service, named volume, healthcheck,
  credentials read from .env.
- .devcontainer/devcontainer.json (+ Dockerfile if needed): R, Python, GDAL/GEOS/PROJ,
  docker-in-docker or compose integration, forwards port 5432 and 3838.
- requirements.txt with pinned versions.
- R/00_setup.R that installs the R packages listed in the master prompt and runs renv::snapshot().
- sql/00_init.sql: CREATE EXTENSION postgis; create schema talent.
- tests/test_environment.py: checks Python imports and that PostGIS answers
  SELECT PostGIS_Version().
- R/tests/test_environment.R: checks R packages load and that a point round-trips
  EPSG:4326 -> 27700 -> 4326 within 1 m.

Then show me the exact commands to start PostGIS and run both tests.
```

### Step 2 — Player data and league eligibility

```
Do WORKPLAN Step 2.

1. R/01_club_tiers.R: build data/processed/club_season_tier.csv
   (club, season, tier) from engsoccerdata for 1992/93–2015/16.
   Create data/manual/club_season_tier_2016_2026.csv as a template for the seasons I
   will compile by hand (2016/17–2025/26). Merge both and check every season has the
   right number of clubs per tier.
2. python/01_club_qids.py: map each club name to its Wikidata QID; write unmatched
   clubs to a list for me to fix manually.
3. python/02_fetch_wikidata.py: for batches of club QIDs, fetch players (P106=Q937857,
   P21=Q6581097) with birth date, birthplace, coordinates, position, and P54 memberships
   with start (P580), end (P582) and matches played (P1350). Save dated Parquet snapshots.
4. python/03_eligibility.py: apply the season assignment rule from the proposal
   (section 6.6) exactly, flag season_ambiguous, keep players with a tier 1–2 season,
   flag the Premier League subset, filter births 1975–2005, deduplicate on QID,
   split English-born vs others, and write the exclusion log.
5. python/04_geocode_fallback.py: only for missing coordinates; town -> county -> country.
6. python/05_validation_sample.py: draw a seeded random sample of 200 players to a CSV
   for my manual check against squad lists.
7. Produce docs/reports/data_quality_step2.md with counts per season, % with coordinates,
   English-born share, % ambiguous, and exclusions by reason.

Unit-test the season assignment rule with the examples in the proposal.
```

### Steps 3–8

```
Do WORKPLAN Step <N>. Follow the proposal sections referenced in that step,
give me the plan first, then implement, test, and report as per the rules.
```

---

## Tips

- Start each session with: *"Read docs/WORKPLAN.md and tell me which steps are ticked."*
- After a step is verified, tick its boxes in `WORKPLAN.md` and commit:
  `git commit -m "Step N: <summary>"`.
- If the agent proposes changing the method, ask it to update the proposal and work plan too, so the documents stay in sync with the code.
