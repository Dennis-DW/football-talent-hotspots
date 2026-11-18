"""Write the Step 2 data quality report: docs/reports/data_quality_step2.md"""
from __future__ import annotations

import pandas as pd

from common import PROCESSED, RAW, REPORTS, latest, today


def table(df: pd.DataFrame) -> str:
    cols = list(df.columns)
    lines = ["| " + " | ".join(map(str, cols)) + " |", "|" + "---|" * len(cols)]
    for r in df.itertuples(index=False):
        lines.append("| " + " | ".join("" if pd.isna(v) else str(v) for v in r) + " |")
    return "\n".join(lines)


def validation_section(elig, n) -> str:
    from common import MANUAL
    path = MANUAL / "validation_sample_claude.csv"
    if not path.exists():
        return "Validation not run yet."
    s = pd.read_csv(path)
    inc, exc = s[s.group == "included"], s[s.group == "excluded"]
    d_inc = inc[inc.check_played_t12.isin(["yes", "no"])]
    d_exc = exc[exc.check_played_t12.isin(["yes", "no"])]
    fi, fe = int((d_inc.check_played_t12 == "no").sum()), int((d_exc.check_played_t12 == "yes").sum())
    pl = inc[inc.check_correct_pl.isin(["yes", "no"])]
    plb = int((pl.check_correct_pl == "no").sum())
    src = elig.evidence_source.value_counts().to_dict()
    return f"""**Validation of the first rule (Wikidata memberships only).** A seeded sample of 200
players (150 included, 50 excluded) was checked against English Wikipedia infoboxes, which
list league appearances per club spell (`python/08_validate_wikipedia.py`,
`data/manual/validation_sample_claude.csv`).

| Measure | Result |
|---|---|
| False-inclusion rate (included, but no tier 1–2 league appearance) | {fi}/{len(d_inc)} = {pct(fi, len(d_inc))} |
| False-exclusion rate (excluded, but did play at tier 1–2) | {fe}/{len(d_exc)} = {pct(fe, len(d_exc))} |
| Premier League flag wrong | {plb}/{len(pl)} = {pct(plb, len(pl))} |
| Undecidable (club changed division during the spell, or no article) | {int((s.check_played_t12 == "unknown").sum())} of 200 |

Almost all false inclusions were players under contract, often academy players, who never
made a league appearance for the club. Because the false-inclusion rate was well above
10%, the eligibility rule was tightened (WORKPLAN decision point,
`python/04b_appearance_evidence.py`):

- **certain**: ≥1 league appearance (infobox caps) in a spell at a club that was tier 1–2 in
  every season of the spell;
- **probable**: league appearances in a spell at a club that was tier 1–2 in only some of
  its seasons (the caps cannot be split by season), or, without a Wikipedia infobox,
  Wikidata matches played > 0 at a club with a dated tier 1–2 season;
- otherwise excluded.

The main analysis uses certain + probable; a sensitivity analysis uses certain only.
Evidence source for study players: {src}.

*Limitation:* Wikipedia and Wikidata are both community-edited, so this check uses a second,
largely separate source rather than a fully independent one. The tightened rule rests on
infobox appearance counts, which by convention are league appearances."""


def pct(a, b):
    return f"{100 * a / b:.1f}%" if b else "–"


def main() -> None:
    mem_file = latest("wikidata_memberships_*.parquet")
    players_raw = pd.read_parquet(latest("wikidata_players_*.parquet"))
    mem = pd.read_parquet(mem_file)
    elig = pd.read_parquet(PROCESSED / "players_eligible.parquet")
    seasons = pd.read_parquet(PROCESSED / "membership_seasons.parquet")
    log = pd.read_csv(PROCESSED / "exclusion_log.csv")
    tiers = pd.read_csv(PROCESSED / "club_season_tier.csv")

    n = len(elig)
    n_cert = int((elig.status == "certain").sum())
    n_prob = int((elig.status == "probable").sum())
    n_cert_pl = int(elig.premier_league_certain.sum())
    eng = elig[elig.english_born]
    spatial = eng[eng.geo_level.isin(["town", "admin"])]
    t12 = tiers[(tiers.season >= 1992) & (tiers.tier <= 2)]

    dated = mem[["start", "end"]].notna()
    year_only = (pd.to_numeric(mem.startPrec, errors="coerce") <= 9) | (pd.to_numeric(mem.endPrec, errors="coerce") <= 9)

    per_season = (seasons[seasons.date_basis == "dated"]
                         .drop_duplicates(["player_qid", "season", "tier"])
                         .groupby(["season", "tier"]).player_qid.nunique()
                         .unstack(fill_value=0).rename(columns={1: "Premier League", 2: "Second tier"})
                         .reset_index())
    per_season["season"] = per_season.season.astype(str) + "/" + ((per_season.season + 1) % 100).astype(str).str.zfill(2)

    mem["apps"] = pd.to_numeric(mem.get("apps"), errors="coerce")
    qual = seasons[["player_qid", "club_qid"]].drop_duplicates().merge(
        mem[["player_qid", "club_qid", "apps"]], on=["player_qid", "club_qid"], how="left")
    apps_pos = qual[qual.apps > 0].player_qid.nunique()

    validation_md = validation_section(elig, n)

    units = (elig.birth_unit.fillna("(not assigned)").value_counts().head(15)
                 .rename_axis("Birth country / UK nation").reset_index(name="Players"))
    reasons = log.reason.value_counts().rename_axis("Reason").reset_index(name="Players")
    geo = (elig.groupby(["geo_level", "geo_source"], dropna=False).size()
               .reset_index(name="Players"))

    md = f"""# Data Quality Report — Step 2

*Generated {today()} by `python/07_quality_report.py`. Source snapshot: `{mem_file.name}`.*

## Summary

| Measure | Value |
|---|---|
| Clubs in tier 1–2 at least once, 1992/93–2025/26 | {t12.club_qid.nunique()} |
| Player memberships fetched (players born 1970+) | {len(mem):,} |
| Distinct players fetched | {players_raw.player_qid.nunique():,} |
| **Study players** (men born 1975–2005 with evidence of ≥1 tier 1–2 league appearance) | **{n:,}** |
| – certain appearance evidence | {n_cert:,} ({pct(n_cert, n)}) |
| – probable appearance evidence | {n_prob:,} ({pct(n_prob, n)}) |
| – season-ambiguous on Wikidata dates (kept, flagged) | {int(elig.season_ambiguous.sum()):,} |
| Premier League subset (certain + probable) | {int(elig.premier_league.sum()):,} ({pct(int(elig.premier_league.sum()), n)}) |
| – Premier League, certain only | {n_cert_pl:,} |
| **English-born** | **{len(eng):,}** ({pct(len(eng), n)}) |
| English-born with a town/admin-level birthplace (usable for spatial analysis) | {len(spatial):,} |
| Study players with birthplace coordinates | {int(elig.lon.notna().sum()):,} ({pct(int(elig.lon.notna().sum()), n)}) |

## Validation and eligibility rule

{validation_md}

## Membership dates in Wikidata

| Measure | Memberships | Share |
|---|---|---|
| With a start date | {int(dated.start.sum()):,} | {pct(int(dated.start.sum()), len(mem))} |
| With an end date | {int(dated.end.sum()):,} | {pct(int(dated.end.sum()), len(mem))} |
| With neither (undated) | {int((~dated.start & ~dated.end).sum()):,} | {pct(int((~dated.start & ~dated.end).sum()), len(mem))} |
| With a year-only start or end | {int(year_only.sum()):,} | {pct(int(year_only.sum()), len(mem))} |

## Birthplace resolution

{table(geo)}

Country-level birthplaces (e.g. "England") cannot be placed on a local map and are excluded
from the spatial analyses; they remain in the descriptive analysis (RQ4).

## Birth country (top 15)

{table(units)}

## Exclusions

{table(reasons)}

Full list: `data/processed/exclusion_log.csv`.

## Study players per season

Distinct players with a **dated** membership overlapping each season, by tier.

These counts are higher than the number of players who actually appeared in a season
(about 500–550 in the Premier League). A Wikidata membership marks a contract, not an
appearance: loanees remain members of their parent club, and squad players who never
played are included. Player-level eligibility is less affected (a player needs only one
qualifying season); the validation sample measures the remaining false-inclusion rate.

{table(per_season)}

## Matches-played evidence

Study players whose qualifying memberships record matches played (P1350) > 0:
{int(apps_pos):,} ({pct(int(apps_pos), n)}). The rest have no matches-played value in
Wikidata, so their appearance cannot be confirmed from Wikidata alone.

## Next checks

- Manual validation of 200 players: `data/manual/validation_sample.csv`.
- Players with several birth dates in Wikidata: {int(elig.multiple_birth_dates.sum())}; several birthplaces: {int(elig.multiple_birth_places.sum())}.
"""
    REPORTS.mkdir(parents=True, exist_ok=True)
    out = REPORTS / "data_quality_step2.md"
    out.write_text(md)
    print(f"Wrote {out}")


if __name__ == "__main__":
    main()
