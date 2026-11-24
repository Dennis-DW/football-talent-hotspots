"""Apply the season assignment rule and decide which players are in the study.

A player is in the study if they were born 1975-01-01 to 2005-12-31 and had a club
membership overlapping at least one season (1992/93–2025/26) in which that club was in
the Premier League (tier 1) or the second tier (tier 2).

Membership handling:
  * men only: players whose sex (P21) is not recorded as male are excluded;
  * memberships with matches played (P1350) = 0 are ignored;
  * dated memberships use the season rule (pipeline/season_rule.py); the "wide" reading of
    year-only dates is also computed, to flag ambiguous players;
  * a membership with a start but no end is treated as continuing, at most until the
    player is 38 or the 2025/26 season;
  * undated memberships (no start and no end) count only if the club was in tier 1–2 in
    every season of the player's likely career window (ages 17–35, from 1992/93); then the
    membership is certain to overlap a tier 1–2 season whenever it happened.

Status per player:
  eligible   – eligible under the rule (or via a certain undated membership)
  ambiguous  – eligible only under the wide reading of year-only dates (kept, flagged)
  excluded   – written to the exclusion log with a reason

Outputs:
  data/processed/players_eligible.parquet       one row per eligible/ambiguous player
  data/processed/membership_seasons.parquet     one row per player × club × tier-1/2 season
  data/processed/exclusion_log.csv              one row per excluded player, with reason
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # pipeline/: common, season_rule

import datetime as dt
import re

import pandas as pd

from common import (BIRTH_MAX, BIRTH_MIN, FIRST_SEASON, LAST_SEASON, PROCESSED, RAW,
                    latest)
from season_rule import WDate, membership_seasons

CAREER_START_AGE, CAREER_END_AGE, OPEN_END_MAX_AGE = 17, 35, 38
MALE = "Q6581097"


def parse_date(value, precision) -> WDate | None:
    if not isinstance(value, str) or pd.isna(precision):
        return None
    m = re.match(r"^(-?\d+)-(\d\d)-(\d\d)", value)
    if not m:
        return None
    y, mo, d = (int(g) for g in m.groups())
    return WDate(dt.date(y, max(mo, 1), max(d, 1)), int(float(precision)))


def parse_point(wkt):
    if not isinstance(wkt, str):
        return (None, None)
    m = re.match(r"Point\(\s*([-0-9.eE]+)\s+([-0-9.eE]+)\s*\)", wkt)
    return (float(m.group(1)), float(m.group(2))) if m else (None, None)


def one_row_per_player(p: pd.DataFrame) -> pd.DataFrame:
    """Players can have several birth dates / places in Wikidata. Keep the most precise
    birth date and the first place with coordinates; flag players with several."""
    p = p.copy()
    p["birthPrec"] = pd.to_numeric(p["birthPrec"], errors="coerce")
    p["has_coord"] = p["coord"].notna()
    flags = p.groupby("player_qid").agg(n_birth=("birth", "nunique"), n_place=("place_qid", "nunique"))
    p = (p.sort_values(["player_qid", "birthPrec", "has_coord"], ascending=[True, False, False])
           .drop_duplicates("player_qid"))
    p = p.merge(flags, on="player_qid", how="left")
    p["multiple_birth_dates"] = p["n_birth"] > 1
    p["multiple_birth_places"] = p["n_place"] > 1
    lonlat = p["coord"].map(parse_point)
    p["lon"] = lonlat.map(lambda t: t[0])
    p["lat"] = lonlat.map(lambda t: t[1])
    p["birth_wd"] = [parse_date(b, pr) for b, pr in zip(p["birth"], p["birthPrec"])]
    p["birth_date"] = p["birth_wd"].map(lambda w: w.date if w else None)
    p["birth_precision"] = p["birthPrec"]
    p["birth_year"] = p["birth_wd"].map(lambda w: w.date.year if w else None)
    return p.drop(columns=["n_birth", "n_place", "has_coord", "birth", "birthPrec", "coord"])


def in_cohort(w: WDate | None) -> bool:
    if w is None:
        return False
    if w.year_only:
        return BIRTH_MIN.year <= w.date.year <= BIRTH_MAX.year
    return BIRTH_MIN <= w.date <= BIRTH_MAX


def main() -> None:
    mem = pd.read_parquet(latest("wikidata_memberships_*.parquet"))
    raw_players = pd.read_parquet(latest("wikidata_players_*.parquet"))
    tiers = pd.read_csv(PROCESSED / "club_season_tier.csv")
    tier_of = {(r.club_qid, r.season): r.tier for r in tiers.itertuples()}

    players = one_row_per_player(raw_players)
    log = []

    cohort_mask = players["birth_wd"].map(in_cohort)
    for r in players[~cohort_mask].itertuples():
        reason = "no birth date" if r.birth_wd is None else "born outside 1975–2005"
        log.append({"player_qid": r.player_qid, "label": r.label, "reason": reason})
    players = players[cohort_mask].copy()

    # Men only (proposal section 5). Some women's-team memberships are recorded against
    # the men's club item in Wikidata, so filter on the player's sex (P21).
    male = players["sex"] == MALE
    for r in players[~male].itertuples():
        reason = "sex not recorded" if not isinstance(r.sex, str) else "not male (women's football)"
        log.append({"player_qid": r.player_qid, "label": r.label, "reason": reason})
    players = players[male].copy()
    by_player = players.set_index("player_qid")

    mem = mem[mem.player_qid.isin(players.player_qid)].copy()
    mem["apps"] = pd.to_numeric(mem.get("apps"), errors="coerce")
    zero_apps = mem["apps"] == 0
    mem = mem[~zero_apps]

    season_rows, status = [], {}
    for pq, group in mem.groupby("player_qid"):
        by = int(by_player.at[pq, "birth_year"])
        window = range(max(FIRST_SEASON, by + CAREER_START_AGE), min(LAST_SEASON, by + CAREER_END_AGE) + 1)
        open_end = min(LAST_SEASON, by + OPEN_END_MAX_AGE)
        rule_seasons, wide_seasons, undated_ok, undated_unsure = set(), set(), False, False
        for r in group.itertuples():
            start = parse_date(r.start, r.startPrec)
            end = parse_date(r.end, r.endPrec)
            if start is None and end is None:
                tiers_in_window = [tier_of.get((r.club_qid, s)) for s in window]
                if window and all(t in (1, 2) for t in tiers_in_window):
                    undated_ok = True
                    rule_seasons |= {(r.club_qid, s, t, "undated") for s, t in zip(window, tiers_in_window)}
                elif any(t in (1, 2) for t in tiers_in_window):
                    undated_unsure = True
                continue
            for wide, target in ((False, rule_seasons), (True, wide_seasons)):
                for s in membership_seasons(start, end, wide=wide, open_end_season=open_end):
                    t = tier_of.get((r.club_qid, s))
                    if FIRST_SEASON <= s <= LAST_SEASON and t in (1, 2):
                        target.add((r.club_qid, s, t, "dated"))
        rule_keys = {(c, s) for c, s, _, _ in rule_seasons}
        wide_only = {x for x in wide_seasons if (x[0], x[1]) not in rule_keys}
        if rule_seasons:
            status[pq] = ("eligible", rule_seasons)
        elif wide_only:
            status[pq] = ("ambiguous", wide_only)
        else:
            reason = ("only undated memberships at clubs that changed division" if undated_unsure
                      else "no Premier League / second-tier season")
            log.append({"player_qid": pq, "label": by_player.at[pq, "label"], "reason": reason})

    no_membership = set(players.player_qid) - set(mem.player_qid)
    for pq in no_membership:
        log.append({"player_qid": pq, "label": by_player.at[pq, "label"],
                    "reason": "only memberships with 0 matches played"})

    out = []
    for pq, (st, seasons) in status.items():
        for club, s, t, kind in seasons:
            season_rows.append({"player_qid": pq, "club_qid": club, "season": s, "tier": t,
                                "date_basis": kind, "status": st})
        tiers_played = {t for _, _, t, _ in seasons}
        # season statistics use dated memberships only: an undated membership is spread
        # over the whole career window, so it says nothing about which seasons were played
        ss = sorted(s for _, s, _, k in seasons if k == "dated")
        out.append({"player_qid": pq, "status": st, "season_ambiguous": st == "ambiguous",
                    "premier_league": 1 in tiers_played,
                    "first_t12_season": ss[0] if ss else None,
                    "last_t12_season": ss[-1] if ss else None,
                    "n_t12_seasons": len(set(ss)) if ss else None,
                    "n_t12_clubs": len({c for c, _, _, _ in seasons}),
                    "undated_basis": not ss})
    elig = pd.DataFrame(out).merge(players.drop(columns=["birth_wd"]), on="player_qid", how="left")

    PROCESSED.mkdir(parents=True, exist_ok=True)
    elig.to_parquet(PROCESSED / "players_eligible.parquet", index=False)
    pd.DataFrame(season_rows).to_parquet(PROCESSED / "membership_seasons.parquet", index=False)
    log_df = pd.DataFrame(log).merge(
        one_row_per_player(raw_players)[["player_qid", "birth_date"]], on="player_qid", how="left")
    log_df.to_csv(PROCESSED / "exclusion_log.csv", index=False)

    print(f"Players fetched: {raw_players.player_qid.nunique()} | in 1975–2005 cohort: {len(players)}")
    print(f"Memberships with 0 matches ignored: {int(zero_apps.sum())}")
    print(elig["status"].value_counts().to_string())
    print(f"Premier League subset: {int(elig.premier_league.sum())}")
    print(f"Eligible only via undated memberships: {int(elig.undated_basis.sum())}")
    print("Exclusions:")
    print(pd.DataFrame(log)["reason"].value_counts().to_string())


if __name__ == "__main__":
    main()
