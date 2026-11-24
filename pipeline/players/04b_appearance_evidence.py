"""Tighten eligibility: require evidence of league appearances (validation decision).

The 200-player validation (pipeline/validation/08_validate_wikipedia.py) found that ~19% of players
included on Wikidata memberships alone never played league football at tier 1–2: they
held a contract (often as academy players) but made no appearances. Following the
WORKPLAN decision point, eligibility now requires appearance evidence.

Candidates: every man born 1975–2005 with a Wikidata membership at one of the 78 clubs
(the study players from 04_eligibility.py plus those it excluded for membership reasons).

Evidence, from the English Wikipedia infobox ("Senior career": years, club, league caps):
  certain  – a spell with caps > 0 at a club that was tier 1–2 in every season of the spell
  probable – caps > 0 at a club that was tier 1–2 in only some seasons of the spell
             (the club changed division, so the caps cannot be split by season); or,
             with no Wikipedia article/infobox, Wikidata matches played (P1350) > 0 at a
             club with a dated tier 1–2 season
  none     – excluded
The same is computed for tier 1 only (Premier League evidence).

Main analysis: certain + probable. Sensitivity analysis: certain only.

Updates: data/processed/players_eligible.parquet, data/processed/exclusion_log.csv
Raw: data/raw/wikipedia_infoboxes_<date>.parquet
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # pipeline/: common, season_rule


import pandas as pd

from common import PROCESSED, RAW, latest, today, wikipedia, load_script

v = load_script("validation/08_validate_wikipedia.py")
e4 = load_script("players/04_eligibility.py")

RECONSIDER = {"no Premier League / second-tier season",
              "only undated memberships at clubs that changed division",
              "only memberships with 0 matches played"}


def fetch_wikitext(titles: list[str]) -> dict[str, str]:
    """Title -> wikitext, 50 pages per request (follows redirects)."""
    out = {}
    for i in range(0, len(titles), 50):
        batch = titles[i:i + 50]
        res = wikipedia({"action": "query", "prop": "revisions", "rvprop": "content",
                         "rvslots": "main", "redirects": 1, "titles": "|".join(batch)})["query"]
        alias = {t: t for t in batch}
        for key in ("normalized", "redirects"):
            for n in res.get(key, []):
                alias = {k: (n["to"] if val == n["from"] else val) for k, val in alias.items()}
        text = {p["title"]: p["revisions"][0]["slots"]["main"]["content"]
                for p in res["pages"] if p.get("revisions")}
        for orig, final in alias.items():
            if final in text:
                out[orig] = text[final]
        if (i // 50) % 20 == 0:
            print(f"  wikitext {min(i + 50, len(titles))}/{len(titles)}", flush=True)
    return out


def level(verdict: str) -> str:
    return {"yes": "certain", "unknown": "probable"}.get(verdict, "none")


def main() -> None:
    elig = pd.read_parquet(PROCESSED / "players_eligible.parquet")
    log = pd.read_csv(PROCESSED / "exclusion_log.csv")
    raw_players = pd.read_parquet(latest("wikidata_players_*.parquet"))
    mem = pd.read_parquet(latest("wikidata_memberships_*.parquet"))
    seasons = pd.read_parquet(PROCESSED / "membership_seasons.parquet")
    tiers = pd.read_csv(PROCESSED / "club_season_tier.csv")
    tier_of = {(r.club_qid, r.season): r.tier for r in tiers.itertuples()}

    reconsider = log[log.reason.isin(RECONSIDER)].player_qid
    cand_ids = sorted(set(elig.player_qid) | set(reconsider))
    print(f"Candidates: {len(elig)} previously eligible + {len(reconsider)} previously excluded")

    titles = v.enwiki_titles(cand_ids)
    wikitext = fetch_wikitext(sorted(set(titles.values())))
    spells = {q: v.parse_spells(wikitext[t]) for q, t in titles.items() if t in wikitext}
    club_titles = sorted({s["club_title"] for sp in spells.values() for s in sp if s["club_title"]})
    club_qid = v.title_to_qid(club_titles)
    rows = []
    for q, sp in spells.items():
        for s in sp:
            s["club_qid"] = club_qid.get(s["club_title"])
            rows.append({"player_qid": q, **s})
    pd.DataFrame(rows).to_parquet(RAW / f"wikipedia_infoboxes_{today()}.parquet", index=False)

    # Wikidata fallback: matches played > 0 at a club with a dated tier 1–2 season
    mem["apps"] = pd.to_numeric(mem.get("apps"), errors="coerce")
    dated = seasons[seasons.date_basis == "dated"]
    wd_pos = dated.merge(mem[mem.apps > 0][["player_qid", "club_qid"]].drop_duplicates(),
                         on=["player_qid", "club_qid"])
    wd_t12 = set(wd_pos.player_qid)
    wd_t1 = set(wd_pos[wd_pos.tier == 1].player_qid)

    ev = []
    for q in cand_ids:
        sp = spells.get(q)
        if sp:
            v12, ev12 = v.judge(sp, tier_of, {1, 2})
            v1, _ = v.judge(sp, tier_of, {1})
            ev.append({"player_qid": q, "evidence_source": "wikipedia_infobox",
                       "evidence_t12": level(v12), "evidence_pl": level(v1),
                       "evidence_detail": "; ".join(ev12)})
        else:
            ev.append({"player_qid": q, "evidence_source": "wikidata_P1350",
                       "evidence_t12": "probable" if q in wd_t12 else "none",
                       "evidence_pl": "probable" if q in wd_t1 else "none",
                       "evidence_detail": "no Wikipedia infobox" + ("; Wikidata matches played > 0" if q in wd_t12 else "")})
    ev = pd.DataFrame(ev)

    # Rebuild player table for all candidates (previously excluded ones need their details)
    base = e4.one_row_per_player(raw_players).drop(columns=["birth_wd"])
    keep_cols = [c for c in elig.columns if c not in base.columns or c == "player_qid"]
    cand = base[base.player_qid.isin(cand_ids)].merge(elig[keep_cols], on="player_qid", how="left")
    cand = cand.merge(ev, on="player_qid", how="left")
    cand["wikidata_status"] = cand["status"].fillna("excluded")
    cand["season_ambiguous"] = cand["season_ambiguous"].fillna(False).astype(bool)
    final = cand[cand.evidence_t12.isin(["certain", "probable"])].copy()
    final["status"] = final["evidence_t12"]
    final["premier_league"] = final.evidence_pl.isin(["certain", "probable"])
    final["premier_league_certain"] = final.evidence_pl == "certain"
    final = final.drop(columns=[c for c in ["birth_unit", "birth_country", "birth_iso3", "country_match",
                                            "english_born", "geo_level", "geo_source"] if c in final])
    final.to_parquet(PROCESSED / "players_eligible.parquet", index=False)

    dropped = cand[~cand.evidence_t12.isin(["certain", "probable"])]
    new_log = pd.concat([
        log[~log.player_qid.isin(cand_ids)],
        pd.DataFrame({"player_qid": dropped.player_qid, "label": dropped.label,
                      "reason": "no evidence of a tier 1–2 league appearance",
                      "birth_date": dropped.birth_date}),
    ], ignore_index=True)
    new_log.to_csv(PROCESSED / "exclusion_log.csv", index=False)

    print(f"English Wikipedia article: {len(titles)} | infobox with club spells: {len(spells)}")
    print("Evidence (all candidates):", ev.evidence_t12.value_counts().to_dict())
    was = cand.set_index("player_qid").wikidata_status
    print("Previously eligible/ambiguous -> now excluded:",
          int((dropped.player_qid.map(was) != "excluded").sum()))
    print("Previously excluded -> now included:",
          int((final.player_qid.map(was) == "excluded").sum()))
    print(f"Study players: {len(final)} (certain {int((final.status == 'certain').sum())}, "
          f"probable {int((final.status == 'probable').sum())}) | Premier League: "
          f"{int(final.premier_league.sum())} (certain {int(final.premier_league_certain.sum())})")


if __name__ == "__main__":
    main()
