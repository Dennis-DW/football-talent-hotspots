"""Category 1 academies by season, from the national U18 league.

Under the Elite Player Performance Plan (EPPP, from 2012/13) only Category 1 academies
play in the top national U18 league ("League 1" of the Professional U18 Development
League, later the U18 Premier League); Category 2 academies play in League 2 and
Category 3 in League 3. The Wikipedia season article "<season> Professional U18
Development League" has one section per league, so the clubs in the League 1 section
are that season's Category 1 academies.

For each season the League 1 section (text before the first League 2 / Professional
Development League 2 heading) is parsed for team links (Sports table `name_XXX=` entries
and Fb-style team links); academy articles (e.g. "Arsenal F.C. Under-23s and Academy")
are mapped to the parent club. Each row keeps the article URL and revision id as source.

Output: data/manual/category1_academies.csv
        (season, club_qid, club_name, basis, source_url, source_revid)
Raw:    data/raw/wikipedia_u18_league_<date>.json
"""
from __future__ import annotations

import importlib
import re

import pandas as pd

from common import MANUAL, PROCESSED, RAW, save_json, today, wikipedia

title_to_qid = importlib.import_module("02_club_qids").title_to_qid
SEASONS = range(2012, 2022)  # 2012/13 (EPPP start) .. 2021/22 (cohort born 2005 aged 16)
LEAGUE2 = re.compile(r"\n=+\s*(League 2|(U18 )?Professional Development League 2)\s*=+", re.I)
# Trailing parts of academy / youth-team article titles, removed repeatedly:
# "Arsenal F.C. Academy", "Manchester City F.C. EDS and Academy",
# "Southampton F.C. B team and Academy", "Leeds United F.C. Reserves and Youth Team"
ACADEMY_TAIL = re.compile(r"\s+(and\s+)?(Academy|Youth Team)$", re.I)
SQUAD_TAIL = re.compile(r"\s+(Under-\d+s?|U\d+s?|Reserves|EDS|B team|Development Squad|"
                        r"Professional Development Squad)$", re.I)


def section_league1(wikitext: str) -> str:
    wt = re.sub(r"<!--.*?-->", "", wikitext, flags=re.S)
    m = LEAGUE2.search(wt)
    return wt[: m.start()] if m else wt


def team_titles(section: str) -> list[str]:
    titles = re.findall(r"\|\s*name_[A-Za-z0-9_]+\s*=\s*\[\[([^\]|#]+)", section)
    titles += re.findall(r"\{\{\s*Fb cl[^}]*?\|\s*t\s*=\s*\[\[([^\]|#]+)", section, flags=re.I)
    return sorted({t.strip() for t in titles})


def parent_title(t: str) -> str:
    prev = None
    while prev != t:
        prev = t
        t = SQUAD_TAIL.sub("", ACADEMY_TAIL.sub("", t)).strip()
    return t


def main() -> None:
    tiers = pd.read_csv(PROCESSED / "club_season_tier.csv")
    names = tiers.drop_duplicates("club_qid").set_index("club_qid").club_name
    raw, rows, problems = {}, [], []
    for s in SEASONS:
        page = f"{s}–{str(s + 1)[-2:]} Professional U18 Development League"
        res = wikipedia({"action": "parse", "page": page, "prop": "wikitext|revid", "redirects": 1})
        if "error" in res:
            problems.append(f"{page}: not found")
            continue
        titles = team_titles(section_league1(res["parse"]["wikitext"]))
        raw[page] = {"revid": res["parse"].get("revid"), "titles": titles}
        url = "https://en.wikipedia.org/wiki/" + page.replace(" ", "_")
        for t in titles:
            rows.append({"season": s, "team_title": t, "club_title": parent_title(t),
                         "source_url": url, "source_revid": res["parse"].get("revid")})
    df = pd.DataFrame(rows)
    q = title_to_qid(sorted(df.club_title.unique()))
    df["club_qid"] = df.club_title.map(q)
    unknown = df[df.club_qid.isna() | ~df.club_qid.isin(names.index)]
    for r in unknown.drop_duplicates("club_title").itertuples():
        problems.append(f"not an English league club in the tier table: {r.team_title} -> {r.club_title} ({r.club_qid})")
    df = df[df.club_qid.isin(names.index)].copy()
    df["club_name"] = df.club_qid.map(names)
    df["basis"] = "Wikipedia U18 League 1 section"
    out = df[["season", "club_qid", "club_name", "basis", "source_url", "source_revid"]].drop_duplicates(["season", "club_qid"])
    # No Wikipedia article exists for 2012/13 or 2021/22: impute from the nearest season.
    # 2012/13 excludes Leicester City, which the 2013–14 article records as joining League 1
    # after promotion to Category One (source: LCFC, https://www.lcfc.com/news/434967).
    imputed = []
    if 2012 not in set(out.season):
        x = out[(out.season == 2013) & (out.club_name != "Leicester City")].copy()
        x["season"], x["basis"] = 2012, "imputed from 2013/14 (minus Leicester City, promoted 2013)"
        imputed.append(x)
    if 2021 not in set(out.season):
        x = out[out.season == 2020].copy()
        x["season"], x["basis"] = 2021, "imputed from 2020/21"
        imputed.append(x)
    out = pd.concat([out] + imputed, ignore_index=True)
    out = out.sort_values(["season", "club_name"])
    out.to_csv(MANUAL / "category1_academies.csv", index=False)
    save_json({"retrieved": today(), "pages": raw}, RAW / f"wikipedia_u18_league_{today()}.json")

    per = out.groupby("season").size()
    print("Category 1 academies per season:", per.to_dict())
    allc = out.groupby("club_name").season.agg(lambda x: f"{x.min()}–{x.max()} ({len(x)})")
    print(f"Clubs ever Category 1: {len(allc)}")
    print(allc.to_string())
    print("Problems:" if problems else "No problems.")
    for p in problems:
        print("  -", p)


if __name__ == "__main__":
    main()
