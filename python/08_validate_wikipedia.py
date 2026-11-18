"""Validate eligibility for the 200-player sample against English Wikipedia infoboxes.

Wikidata club memberships record contracts, not appearances. The Wikipedia infobox
("Senior career") lists each club spell with its years and **league appearances**
(caps), so it can tell whether a player actually played league football for a club.

For each spell at an English club with caps > 0, the spell's seasons are read generously
(year-only start Y -> from January Y, end Y -> to December Y, open end -> 2025/26) and
compared with the club's division in those seasons:
  certain   – every season of the spell was tier 1–2  -> the player played at that level
  possible  – only some seasons were tier 1–2         -> cannot attribute the caps
A player is "yes" with ≥1 certain spell, "unknown" with only possible spells (or no
infobox / no caps data), otherwise "no". The Premier League check works the same way
with tier 1 only.

Limitation: Wikipedia and Wikidata are both community-edited, so this is a check against
a second, largely separate source rather than a fully independent one.

Output: data/manual/validation_sample_claude.csv (same columns as the sample, filled in)
        data/raw/wikipedia_infobox_validation_<date>.json (raw parsed spells)
"""
from __future__ import annotations

import importlib
import re

import pandas as pd

from common import LAST_SEASON, MANUAL, PROCESSED, RAW, _get, save_json, today, wikipedia
from season_rule import YEAR, WDate, membership_seasons
import datetime as dt

title_to_qid = importlib.import_module("02_club_qids").title_to_qid


def enwiki_titles(qids: list[str]) -> dict[str, str]:
    out = {}
    for i in range(0, len(qids), 50):
        r = _get("https://www.wikidata.org/w/api.php",
                 {"action": "wbgetentities", "ids": "|".join(qids[i:i + 50]),
                  "props": "sitelinks", "sitefilter": "enwiki", "format": "json"}).json()
        for q, ent in r.get("entities", {}).items():
            sl = ent.get("sitelinks", {}).get("enwiki")
            if sl:
                out[q] = sl["title"]
    return out


def clean(value: str) -> str:
    value = re.sub(r"<!--.*?-->", "", value, flags=re.S)
    value = re.sub(r"<ref[^>]*/>", "", value)
    value = re.sub(r"<ref[^>]*>.*?</ref>", "", value, flags=re.S)
    return value.strip()


def parse_spells(wikitext: str) -> list[dict]:
    wt = re.sub(r"<!--.*?-->", "", wikitext, flags=re.S)
    params = {}
    for key, num, val in re.findall(r"\|\s*(years|clubs|caps)(\d+)\s*=\s*([^\n|]*(?:\[\[[^\]]*\]\][^\n|]*)*)", wt):
        params[(key, int(num))] = clean(val)
    spells = []
    for n in sorted({n for _, n in params}):
        years, club, caps = params.get(("years", n), ""), params.get(("clubs", n), ""), params.get(("caps", n), "")
        link = re.search(r"\[\[([^\]|#]+)", club)
        ys = re.findall(r"(\d{4})", years)
        c = re.search(r"\d+", caps)
        spells.append({
            "n": n, "years": years, "club_text": re.sub(r"\[\[(?:[^\]|]*\|)?([^\]]*)\]\]", r"\1", club),
            "club_title": link.group(1).strip() if link else None,
            "loan": "loan" in club.lower(),
            "start": int(ys[0]) if ys else None,
            "end": int(ys[1]) if len(ys) > 1 else (None if re.search(r"[–-]\s*$", years) else (int(ys[0]) if ys else None)),
            "open_end": bool(re.search(r"[–-]\s*$", years)),
            "caps": int(c.group()) if c else None,
        })
    return spells


def spell_seasons(sp: dict) -> list[int]:
    if sp["start"] is None:
        return []
    start = WDate(dt.date(sp["start"], 1, 1), YEAR)
    end = None if sp["open_end"] or sp["end"] is None else WDate(dt.date(sp["end"], 1, 1), YEAR)
    return membership_seasons(start, end, wide=True, open_end_season=LAST_SEASON)


def judge(spells: list[dict], tier_of: dict, tiers_wanted: set[int]) -> tuple[str, list[str]]:
    certain, possible, evidence = False, False, []
    for sp in spells:
        q = sp.get("club_qid")
        if not q or not sp["caps"]:
            continue
        seasons = [s for s in spell_seasons(sp) if s >= 1992]
        tiers = [tier_of.get((q, s)) for s in seasons]
        if not seasons or not any(t in tiers_wanted for t in tiers):
            continue
        label = f"{sp['club_text']} {sp['years']} ({sp['caps']} apps)"
        if all(t in tiers_wanted for t in tiers):
            certain = True
            evidence.append(label + " [certain]")
        else:
            possible = True
            evidence.append(label + " [club changed division]")
    return ("yes" if certain else "unknown" if possible else "no"), evidence


def main() -> None:
    sample = pd.read_csv(MANUAL / "validation_sample.csv")
    tiers = pd.read_csv(PROCESSED / "club_season_tier.csv")
    tier_of = {(r.club_qid, r.season): r.tier for r in tiers.itertuples()}

    titles = enwiki_titles(sample.player_qid.tolist())
    raw, spells_by_player = {}, {}
    for q, t in titles.items():
        res = wikipedia({"action": "parse", "page": t, "prop": "wikitext", "redirects": 1})
        sp = parse_spells(res["parse"]["wikitext"]) if "parse" in res else []
        spells_by_player[q] = sp
        raw[q] = {"title": t, "spells": sp}

    club_titles = sorted({s["club_title"] for sp in spells_by_player.values() for s in sp if s["club_title"]})
    club_qids = title_to_qid(club_titles)
    for sp in spells_by_player.values():
        for s in sp:
            s["club_qid"] = club_qids.get(s["club_title"])

    played, pl_truth, notes = [], [], []
    for r in sample.itertuples():
        sp = spells_by_player.get(r.player_qid)
        if r.player_qid not in titles:
            played.append("unknown"); pl_truth.append(None); notes.append("no English Wikipedia article")
            continue
        if not sp:
            played.append("unknown"); pl_truth.append(None); notes.append("no infobox club spells found")
            continue
        v12, ev12 = judge(sp, tier_of, {1, 2})
        v1, _ = judge(sp, tier_of, {1})
        played.append(v12)
        pl_truth.append(v1)
        notes.append("; ".join(ev12) if ev12 else "no league apps for a club in a tier 1–2 season")

    out = sample.copy()
    out["check_played_t12"] = played
    out["pl_truth"] = pl_truth
    is_inc = out.group == "included"
    pl_flag = out.premier_league.astype(str).str.lower() == "true"
    out["check_correct_pl"] = ""
    known = is_inc & out.pl_truth.isin(["yes", "no"])
    out.loc[known, "check_correct_pl"] = ((out.pl_truth == "yes") == pl_flag)[known].map({True: "yes", False: "no"})
    out["check_notes"] = notes
    out["checked_by"] = "claude: Wikipedia infobox " + today()
    out.drop(columns=["pl_truth"]).to_csv(MANUAL / "validation_sample_claude.csv", index=False)
    save_json({"retrieved": today(), "players": raw}, RAW / f"wikipedia_infobox_validation_{today()}.json")

    inc, exc = out[is_inc], out[~is_inc]
    def rate(df, bad):
        d = df[df.check_played_t12.isin(["yes", "no"])]
        return (d.check_played_t12 == bad).sum(), len(d)
    fi, fi_n = rate(inc, "no")
    fe, fe_n = rate(exc, "yes")
    pl_bad = (inc.check_correct_pl == "no").sum()
    pl_n = inc.check_correct_pl.isin(["yes", "no"]).sum()
    print("Included:", inc.check_played_t12.value_counts().to_dict())
    print("Excluded:", exc.check_played_t12.value_counts().to_dict())
    print(f"False-inclusion rate: {fi}/{fi_n} = {fi / fi_n:.1%}" if fi_n else "False-inclusion: n/a")
    print(f"False-exclusion rate: {fe}/{fe_n} = {fe / fe_n:.1%}" if fe_n else "False-exclusion: n/a")
    print(f"PL-flag error rate: {pl_bad}/{pl_n} = {pl_bad / pl_n:.1%}" if pl_n else "PL flag: n/a")


if __name__ == "__main__":
    main()
