#!/usr/bin/env bash
# Run the full pipeline (Steps 2–8) inside the app container:
#   docker compose up -d
#   docker compose exec app bash run_all.sh
#
# Network access is needed (Wikidata, Wikipedia, ONS, Nomis, World Bank). Total run time is
# roughly 1–1.5 hours, mostly the Wikidata and Wikipedia downloads. The IMD 2025 file must be
# in data/raw/imd/ (see README). Fixed seeds make the statistical results reproducible;
# re-downloading Wikidata/Wikipedia creates new dated snapshots, which may differ slightly.
set -euo pipefail
cd "$(dirname "$0")"
step() { echo; echo "=== $* ==="; }

step "Step 2: players and league eligibility"
Rscript R/01_club_tiers_engsoc.R
(cd python && python 01_league_tables_wikipedia.py && python 02_club_qids.py \
  && python 03_fetch_wikidata.py && python 04_eligibility.py && python 04b_appearance_evidence.py \
  && python 05_geocode_fallback.py)
Rscript R/02_birth_country.R
(cd python && python 07_quality_report.py)

step "Step 3: area data"
(cd python && python 09_club_grounds.py && python 10_births_baseline.py && python 11_ons_boundaries.py)
Rscript R/03_area_covariates.R
(cd python && python 12_step3_report.py)

step "Step 4: units and expected counts"
Rscript R/04_expected_counts.R

step "Step 5: clustering (RQ1)"
Rscript R/05_clustering.R 999

step "Step 6: hotspots (RQ2)"
Rscript R/06_hotspots.R 999 9999

step "Step 7: models (RQ3) and foreign-born (RQ4)"
Rscript R/07_models.R
(cd python && python 13_category1_academies.py && python 14_country_population.py)
Rscript R/07b_academy_model.R
Rscript R/08_foreign_born.R

step "Step 8: dashboard data"
Rscript R/09_app_data.R

step "Tests"
pytest -q tests/
Rscript R/tests/test_environment.R
Rscript R/tests/test_app.R
echo; echo "Done. Start the dashboard with: Rscript -e 'shiny::runApp(\"app\", host = \"0.0.0.0\", port = 3838)'"
