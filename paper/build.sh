#!/usr/bin/env bash
# Build paper/main.pdf. Run from the repository root on the host:
#   bash paper/build.sh            regenerate numbers/tables/figures, then compile
#   bash paper/build.sh --tex-only compile only
set -euo pipefail
if [[ "${1:-}" != "--tex-only" ]]; then
  docker compose exec -T app Rscript analysis/paper/11_paper_inputs.R
fi
run_tex() { docker compose exec -T -w /workspaces/football-talent-hotspots/paper app "$@"; }
tex() { run_tex pdflatex -interaction=nonstopmode -halt-on-error main.tex >/dev/null ||
        { run_tex sh -c 'grep -A5 "^!" main.log'; exit 1; }; }
tex
run_tex bibtex main >/dev/null || { run_tex cat main.blg; exit 1; }
tex
tex
run_tex sh -c 'grep -E "undefined|Overfull|Warning" main.log | grep -v "Font shape" || true'
docker compose exec -T app chown -R "$(id -u):$(id -g)" /workspaces/football-talent-hotspots/paper
docker compose exec -T app Rscript analysis/site/12_build_site.R   # project page uses the new PDF and figures
docker compose exec -T app chown -R "$(id -u):$(id -g)" /workspaces/football-talent-hotspots/site
echo "Built paper/main.pdf and site/"
