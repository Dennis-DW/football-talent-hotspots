"""Draw the 200-player manual validation sample (proposal section 6.6).

150 included players (eligible + ambiguous) estimate the false-inclusion rate;
50 players excluded for "no Premier League / second-tier season" or "only undated
memberships…" estimate the false-exclusion rate. Seeded, so the sample is reproducible.

Check each row against a published squad list (e.g. the club's season article on
Wikipedia, or the Premier League / EFL site) and fill in the last three columns:
  check_played_t12   yes / no   – did the player appear for a club in a tier 1–2 season?
  check_correct_pl   yes / no   – is the premier_league flag right?
  check_notes        free text

Output: data/manual/validation_sample.csv
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # pipeline/: common, season_rule

import pandas as pd

from common import MANUAL, PROCESSED

SEED = 20261102
N_INCLUDED, N_EXCLUDED = 150, 50


def main() -> None:
    elig = pd.read_parquet(PROCESSED / "players_eligible.parquet")
    seasons = pd.read_parquet(PROCESSED / "membership_seasons.parquet")
    tiers = pd.read_csv(PROCESSED / "club_season_tier.csv")
    club_name = tiers.drop_duplicates("club_qid").set_index("club_qid")["club_name"]
    log = pd.read_csv(PROCESSED / "exclusion_log.csv")

    inc = elig.sample(n=min(N_INCLUDED, len(elig)), random_state=SEED)
    claims = (seasons.assign(club=lambda d: d.club_qid.map(club_name),
                             s=lambda d: d.season.astype(str) + "/" + ((d.season + 1) % 100).astype(str).str.zfill(2)
                                         + " T" + d.tier.astype(str))
                     .groupby("player_qid")
                     .apply(lambda g: "; ".join(f"{c} {s}" for c, s in
                                                sorted(zip(g.club, g.s), key=lambda x: x[1])[:6]),
                            include_groups=False))
    inc = inc.assign(group="included", claimed_t12_seasons=inc.player_qid.map(claims))

    excl_pool = log[log.reason.isin(["no Premier League / second-tier season",
                                     "only undated memberships at clubs that changed division"])]
    exc = excl_pool.sample(n=min(N_EXCLUDED, len(excl_pool)), random_state=SEED)
    exc = exc.assign(group="excluded", status="excluded", premier_league=None,
                     claimed_t12_seasons=None, exclusion_reason=exc.reason)

    cols = ["group", "player_qid", "label", "birth_date", "status", "premier_league",
            "claimed_t12_seasons", "exclusion_reason"]
    inc = inc.assign(exclusion_reason=None)
    sample = pd.concat([inc.reindex(columns=cols), exc.reindex(columns=cols)], ignore_index=True)
    sample["wikidata_url"] = "https://www.wikidata.org/wiki/" + sample.player_qid
    sample["check_played_t12"] = ""
    sample["check_correct_pl"] = ""
    sample["check_notes"] = ""
    MANUAL.mkdir(parents=True, exist_ok=True)
    out = MANUAL / "validation_sample.csv"
    sample.to_csv(out, index=False)
    print(f"Wrote {out}: {len(inc)} included + {len(exc)} excluded players (seed {SEED})")


if __name__ == "__main__":
    main()
