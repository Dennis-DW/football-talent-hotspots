"""Club–season–tier table from Wikipedia league tables, 2016/17–2025/26.

Used to (a) fill seasons missing from engsoccerdata (2022/23 and 2025/26) and
(b) cross-check engsoccerdata and the club-to-Wikidata mapping for 2016/17–2024/25.

Each season article contains a league table built with the Sports table module:
`team_order=` lists the club codes and `name_XXX=[[Article title|Label]]` links each code
to the club's Wikipedia article, which we resolve to a Wikidata QID.

Output:
  data/raw/wikipedia_league_tables_<date>.json   (raw extracted tables)
  data/processed/club_season_tier_wiki.csv       (season, tier, club_title, club_qid)
"""
from __future__ import annotations

import csv
import re

from common import PROCESSED, RAW, save_json, today, wikipedia

LEAGUES = {1: "Premier League", 2: "EFL Championship", 3: "EFL League One", 4: "EFL League Two"}
EXPECTED = {1: 20, 2: 24, 3: 24, 4: 24}
SEASONS = range(2016, 2026)


def season_page(season: int, tier: int) -> str:
    return f"{season}–{str(season + 1)[-2:]} {LEAGUES[tier]}"


def strip_comments(wikitext: str) -> str:
    return re.sub(r"<!--.*?-->", "", wikitext, flags=re.S)


def page_wikitext(page: str) -> str | None:
    """Wikitext of a season page; follows a transcluded '{{<season> table}}' template if the
    league table is not written inline."""
    res = wikipedia({"action": "parse", "page": page, "prop": "wikitext", "redirects": 1})
    if "error" in res:
        return None
    wt = strip_comments(res["parse"]["wikitext"])
    if "team_order" not in wt and not re.search(r"\|\s*team1\s*=", wt):
        m = re.search(r"\{\{([^{}|]*table)\s*\}\}", wt)
        if m:
            res = wikipedia({"action": "parse", "page": f"Template:{m.group(1).strip()}",
                             "prop": "wikitext", "redirects": 1})
            if "error" not in res:
                wt = strip_comments(res["parse"]["wikitext"])
    return wt


def extract_table(wikitext: str) -> list[str]:
    """Article titles of the clubs in the (first) league table, in table order."""
    wikitext = strip_comments(wikitext)
    names = {}
    for code, title in re.findall(r"\|\s*name_([A-Za-z0-9_]+)\s*=\s*\[\[([^\]|]+)", wikitext):
        names.setdefault(code, title.strip())
    m = re.search(r"team_order\s*=\s*([^|}]+)", wikitext)
    if m:  # newer format: team_order=MCI, ARS, ...
        codes = [c.strip() for c in m.group(1).replace("\n", " ").split(",") if c.strip()]
    else:  # older format: |team1=MCI |team2=MUN ...
        numbered = re.findall(r"\|\s*team(\d+)\s*=\s*([A-Za-z0-9_]+)", wikitext)
        first: dict[int, str] = {}
        for n, code in numbered:
            first.setdefault(int(n), code)
        codes = [first[n] for n in sorted(first)]
    return [names[c] for c in codes if c in names]


def resolve_qids(titles: list[str]) -> dict[str, str]:
    """Wikipedia article title -> Wikidata QID (following redirects)."""
    out: dict[str, str] = {}
    for i in range(0, len(titles), 50):
        batch = titles[i : i + 50]
        res = wikipedia({"action": "query", "prop": "pageprops", "ppprop": "wikibase_item",
                         "redirects": 1, "titles": "|".join(batch)})
        q = res["query"]
        alias = {t: t for t in batch}
        for n in q.get("normalized", []):
            alias = {k: (n["to"] if v == n["from"] else v) for k, v in alias.items()}
        for r in q.get("redirects", []):
            alias = {k: (r["to"] if v == r["from"] else v) for k, v in alias.items()}
        by_title = {p["title"]: p.get("pageprops", {}).get("wikibase_item") for p in q["pages"]}
        for original, final in alias.items():
            if by_title.get(final):
                out[original] = by_title[final]
    return out


def main() -> None:
    raw, rows, problems = {}, [], []
    for season in SEASONS:
        for tier in LEAGUES:
            page = season_page(season, tier)
            wt = page_wikitext(page)
            if wt is None:
                problems.append(f"{page}: page not found")
                continue
            titles = extract_table(wt)
            raw[page] = titles
            if len(titles) != EXPECTED[tier]:
                problems.append(f"{page}: found {len(titles)} clubs, expected {EXPECTED[tier]}")
            for t in titles:
                rows.append({"season": season, "tier": tier, "club_title": t})

    qids = resolve_qids(sorted({r["club_title"] for r in rows}))
    for r in rows:
        r["club_qid"] = qids.get(r["club_title"], "")
        if not r["club_qid"]:
            problems.append(f"No QID for {r['club_title']}")

    save_json({"retrieved": today(), "tables": raw}, RAW / f"wikipedia_league_tables_{today()}.json")
    out = PROCESSED / "club_season_tier_wiki.csv"
    with out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["season", "tier", "club_title", "club_qid"])
        w.writeheader()
        w.writerows(rows)

    print(f"Wrote {out}: {len(rows)} rows, {len(qids)} clubs with QIDs")
    print("Problems:" if problems else "No problems found.")
    for p in sorted(set(problems)):
        print("  -", p)


if __name__ == "__main__":
    main()
