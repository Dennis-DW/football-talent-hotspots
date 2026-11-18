"""Write the Step 3 data quality report: docs/reports/data_quality_step3.md"""
from __future__ import annotations

import pandas as pd

from common import MANUAL, PROCESSED, REPORTS, today


def md_table(df: pd.DataFrame) -> str:
    lines = ["| " + " | ".join(map(str, df.columns)) + " |", "|" + "---|" * len(df.columns)]
    for r in df.itertuples(index=False):
        lines.append("| " + " | ".join(str(v) for v in r) + " |")
    return "\n".join(lines)


def main() -> None:
    cov = pd.read_csv(PROCESSED / "lad21_covariates.csv")
    births = pd.read_csv(PROCESSED / "births_lad_year.csv")
    grounds = pd.read_csv(PROCESSED / "club_season_ground.csv")
    lsoa = pd.read_csv(PROCESSED / "lsoa21_england.csv")
    acad = pd.read_csv(MANUAL / "category1_academies.csv")

    tot = births.groupby("birth_year").births_male.sum().round().astype(int)
    years = [1975, 1978, 1981, 1985, 1990, 1995, 2000, 2005]
    births_tbl = pd.DataFrame({"Birth year": years, "Male births (proxy)": [f"{tot[y]:,}" for y in years]})
    method = births.groupby("baseline_method").birth_year.agg(["min", "max"]).reset_index()
    method.columns = ["Method", "From", "To"]

    summ = cov[["imd_score", "urban_share", "dist_club_km", "pop2022"]].describe().T
    summ = summ[["min", "25%", "50%", "75%", "max"]].round(2).reset_index().rename(columns={"index": "Variable"})
    basis = grounds.venue_basis.value_counts().rename_axis("Ground location basis").reset_index(name="Club-seasons")
    far = cov.nlargest(5, "dist_club_km")[["lad21nm", "dist_club_km"]].round(1)
    close = cov.nsmallest(5, "dist_club_km")[["lad21nm", "dist_club_km"]].round(1)

    md = f"""# Data Quality Report — Step 3

*Generated {today()} by `python/12_step3_report.py`.*

## Summary

| Item | Value |
|---|---|
| Spatial unit | Local authority districts, April/December 2021 boundaries (England) |
| Local authorities | {len(cov)} |
| LSOAs (2021) | {len(lsoa):,} (all matched to a LAD and to IMD 2025) |
| Births baseline | Male infants, ONS mid-year estimates (Nomis NM_31_1), birth years 1975–2005 |
| Deprivation | English Indices of Deprivation 2025, IMD score (LSOA 2021) |
| Urbanisation | Rural-Urban Classification 2021 (LSOA) |
| Club grounds | {grounds.club_qid.nunique()} clubs, seasons {grounds.season.min()}/{str(grounds.season.min() + 1)[-2:]}–{grounds.season.max()}/{str(grounds.season.max() + 1)[-2:]} |
| Category 1 academies | {len(acad)} entries compiled (to be completed before the Step 7 sub-model) |

## Births baseline

ONS local-authority live births on Nomis start only in 2013, so the baseline uses ONS
mid-year population estimates for males on April 2021 LAD boundaries (back-cast to 1981):

{md_table(method)}

England totals, selected years:

{md_table(births_tbl)}

These are surviving resident infants (births net of infant deaths and migration). They are
close to registered male births and follow the known trend (late-1970s low, 1990 peak).

## Local authority covariates

{md_table(summ)}

- `imd_score`: population-weighted mean IMD 2025 score (higher = more deprived).
- `urban_share`: share of the population in urban LSOAs.
- `dist_club_km`: births-weighted distance from the LAD's population to the nearest
  professional club ground (tiers 1–4) in the season each birth cohort was aged 12.

Furthest from a club: {", ".join(f"{r.lad21nm} ({r.dist_club_km} km)" for r in far.itertuples())}.
Closest: {", ".join(f"{r.lad21nm} ({r.dist_club_km} km)" for r in close.itertuples())}.

## Club grounds

{md_table(basis)}

Wikidata records only the current ground for most clubs. Moves within the same town have
little effect at LAD level; the long temporary moves (Brighton, Bristol Rovers, Charlton,
Coventry) are corrected in `data/manual/club_ground_overrides.csv`. Maidstone United
(1989/90–1991/92, tier 4) has no ground in Wikidata and is omitted for those seasons.

## Limitations

1. The births baseline is a proxy (male infants at mid-year), not registered births.
2. LSOA population weights are mid-2022, not contemporary with the birth cohorts.
3. IMD 2025 measures deprivation now, not when the players were born.
4. Club grounds are mostly current grounds applied to all seasons (see above).
5. Category 1 academy list still to be compiled with a source per club.
"""
    out = REPORTS / "data_quality_step3.md"
    out.write_text(md)
    print(f"Wrote {out}")


if __name__ == "__main__":
    main()
