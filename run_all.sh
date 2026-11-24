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
Rscript analysis/prepare/01_club_tiers_engsoc.R
python pipeline/clubs/01_league_tables_wikipedia.py
python pipeline/clubs/02_club_qids.py
python pipeline/players/03_fetch_wikidata.py
python pipeline/players/04_eligibility.py
python pipeline/players/04b_appearance_evidence.py
python pipeline/players/05_geocode_fallback.py
Rscript analysis/prepare/02_birth_country.R
python pipeline/reports/07_quality_report.py

step "Step 3: area data"
python pipeline/clubs/09_club_grounds.py
python pipeline/areas/10_births_baseline.py
python pipeline/areas/11_ons_boundaries.py
Rscript analysis/prepare/03_area_covariates.R
python pipeline/reports/12_step3_report.py

step "Step 4: units and expected counts"
Rscript analysis/prepare/04_expected_counts.R

step "Step 5: clustering (RQ1)"
Rscript analysis/models/05_clustering.R 999

step "Step 6: hotspots (RQ2)"
Rscript analysis/models/06_hotspots.R 999 9999

step "Step 7: models (RQ3) and foreign-born (RQ4)"
Rscript analysis/models/07_models.R
python pipeline/clubs/13_category1_academies.py
python pipeline/countries/14_country_population.py
Rscript analysis/models/07b_academy_model.R
Rscript analysis/models/08_foreign_born.R

step "Step 8: dashboard data"
Rscript analysis/dashboard/09_app_data.R

step "Step 9: research paper"
Rscript analysis/paper/11_paper_inputs.R
(cd paper && pdflatex -interaction=nonstopmode -halt-on-error main.tex >/dev/null && bibtex main >/dev/null &&
  pdflatex -interaction=nonstopmode -halt-on-error main.tex >/dev/null &&
  pdflatex -interaction=nonstopmode -halt-on-error main.tex >/dev/null)

step "Step 10: project page (site/)"
Rscript analysis/site/12_build_site.R

step "Tests"
pytest -q tests/
Rscript analysis/tests/test_environment.R
Rscript analysis/tests/test_app.R
echo; echo "Done. Start the dashboard with: Rscript -e 'shiny::runApp(\"app\", host = \"0.0.0.0\", port = 3838)'"
