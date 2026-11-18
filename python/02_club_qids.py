"""Map engsoccerdata club names to Wikidata QIDs and build the final club–season–tier table.

Matching, in order:
  1. manual overrides in data/manual/club_qid_overrides.csv (if present);
  2. the same name in the Wikipedia league tables (2016/17–2025/26);
  3. Wikipedia article title guesses ("<name> F.C.", "<name> A.F.C.", "<name>"),
     accepted only if the Wikidata item is an association football club.

Validation: for every season present in both sources, the set of QIDs per tier from
engsoccerdata must equal the set from Wikipedia.

Outputs:
  data/manual/club_qids.csv              engsoccerdata name -> QID (review and commit)
  data/processed/club_season_tier.csv    season, tier, club_qid, club_name, source
"""
from __future__ import annotations

import csv
import re
from collections import defaultdict

from common import MANUAL, PROCESSED, qid, sparql, wikipedia

FOOTBALL_CLUB = "Q476028"


def norm(name: str) -> str:
    n = name.lower().replace("&", "and")
    n = re.sub(r"\b(a\.?f\.?c\.?|f\.?c\.?)\b", "", n)
    n = re.sub(r"[^a-z0-9 ]", " ", n)
    return re.sub(r"\s+", " ", n).strip()


def read_csv(path):
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


def title_to_qid(titles: list[str]) -> dict[str, str]:
    out = {}
    for i in range(0, len(titles), 50):
        batch = titles[i : i + 50]
        res = wikipedia({"action": "query", "prop": "pageprops", "ppprop": "wikibase_item",
                         "redirects": 1, "titles": "|".join(batch)})["query"]
        alias = {t: t for t in batch}
        for key in ("normalized", "redirects"):
            for n in res.get(key, []):
                alias = {k: (n["to"] if v == n["from"] else v) for k, v in alias.items()}
        found = {p["title"]: p.get("pageprops", {}).get("wikibase_item")
                 for p in res["pages"] if not p.get("missing")}
        for orig, final in alias.items():
            if found.get(final):
                out[orig] = found[final]
    return out


def football_clubs(qids: set[str]) -> set[str]:
    """QIDs that are (subclasses of) association football clubs."""
    ok = set()
    qs = sorted(qids)
    for i in range(0, len(qs), 200):
        values = " ".join(f"wd:{q}" for q in qs[i : i + 200])
        rows = sparql(f"""SELECT DISTINCT ?c WHERE {{ VALUES ?c {{ {values} }}
                          ?c wdt:P31/wdt:P279* wd:{FOOTBALL_CLUB} . }}""")
        ok |= {qid(r["c"]) for r in rows}
    return ok


def main() -> None:
    engsoc = read_csv(PROCESSED / "club_season_tier_engsoc.csv")
    wiki = read_csv(PROCESSED / "club_season_tier_wiki.csv")
    names = sorted({r["club"] for r in engsoc})

    mapping: dict[str, tuple[str, str]] = {}  # name -> (qid, method)
    # Season-specific overrides: one engsoccerdata name can mean different clubs over time
    ranged: dict[str, list[tuple[int, int, str]]] = defaultdict(list)
    overrides_path = MANUAL / "club_qid_overrides.csv"
    if overrides_path.exists():
        for r in read_csv(overrides_path):
            lo = int(r["first_season"] or 0)
            hi = int(r["last_season"] or 9999)
            ranged[r["engsoc_name"]].append((lo, hi, r["club_qid"]))
            mapping.setdefault(r["engsoc_name"], (r["club_qid"], "manual"))

    def qid_for(name: str, season: int) -> str | None:
        for lo, hi, q in ranged.get(name, []):
            if lo <= season <= hi:
                return q
        return mapping[name][0] if name in mapping else None

    wiki_by_norm = {}
    for r in wiki:
        wiki_by_norm.setdefault(norm(r["club_title"]), r["club_qid"])
    for n in names:
        if n not in mapping and norm(n) in wiki_by_norm:
            mapping[n] = (wiki_by_norm[norm(n)], "wikipedia_table")

    todo = [n for n in names if n not in mapping]
    guesses = {n: [f"{n} F.C.", f"{n} A.F.C.", n] for n in todo}
    found = title_to_qid(sorted({t for ts in guesses.values() for t in ts}))
    clubs = football_clubs(set(found.values()))
    for n, ts in guesses.items():
        for t in ts:
            if found.get(t) in clubs:
                mapping[n] = (found[t], f"title_guess:{t}")
                break

    unmatched = [n for n in names if n not in mapping]

    # --- validation against Wikipedia tables -------------------------------------
    eng_sets, wiki_sets = defaultdict(set), defaultdict(set)
    for r in engsoc:
        q = qid_for(r["club"], int(r["season"]))
        if q:
            eng_sets[(int(r["season"]), int(r["tier"]))].add(q)
    for r in wiki:
        wiki_sets[(int(r["season"]), int(r["tier"]))].add(r["club_qid"])
    common_keys = sorted(set(eng_sets) & set(wiki_sets))
    mismatches = []
    for k in common_keys:
        if eng_sets[k] != wiki_sets[k]:
            mismatches.append((k, sorted(eng_sets[k] - wiki_sets[k]), sorted(wiki_sets[k] - eng_sets[k])))

    # --- outputs -----------------------------------------------------------------
    MANUAL.mkdir(parents=True, exist_ok=True)
    with (MANUAL / "club_qids.csv").open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["engsoc_name", "club_qid", "first_season", "last_season", "method"])
        for n in names:
            if n in ranged:
                for lo, hi, q in ranged[n]:
                    w.writerow([n, q, lo or "", hi if hi != 9999 else "", "manual"])
            else:
                q, m = mapping.get(n, ("", "UNMATCHED"))
                w.writerow([n, q, "", "", m])

    qid_name = {}
    for r in engsoc:
        q = qid_for(r["club"], int(r["season"]))
        if q:
            qid_name.setdefault(q, r["club"])
    for r in wiki:
        qid_name.setdefault(r["club_qid"], re.sub(r" A?\.?F\.C\.$", "", r["club_title"]))
    rows = {}
    for r in engsoc:
        q = qid_for(r["club"], int(r["season"]))
        if q:
            rows[(int(r["season"]), q)] = (int(r["tier"]), r["club"], "engsoccerdata")
    eng_seasons = {int(r["season"]) for r in engsoc}
    for r in wiki:
        s = int(r["season"])
        if s not in eng_seasons:
            rows[(s, r["club_qid"])] = (int(r["tier"]), qid_name[r["club_qid"]], "wikipedia")
    with (PROCESSED / "club_season_tier.csv").open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["season", "tier", "club_qid", "club_name", "source"])
        for (s, q), (t, n, src) in sorted(rows.items(), key=lambda x: (x[0][0], x[1][0], x[1][1])):
            w.writerow([s, t, q, n, src])

    methods = defaultdict(int)
    for _, m in mapping.values():
        methods[m.split(":")[0]] += 1
    print(f"Clubs: {len(names)} | matched: {len(mapping)} {dict(methods)} | unmatched: {len(unmatched)}")
    for n in unmatched:
        print("  UNMATCHED:", n)
    print(f"Validation: {len(common_keys)} season-tiers compared, {len(mismatches)} mismatches")
    for k, only_eng, only_wiki in mismatches:
        print(f"  {k}: only engsoccerdata {only_eng} | only Wikipedia {only_wiki}")
    dup = defaultdict(list)
    for n, (q, _) in mapping.items():
        dup[q].append(n)
    for q, ns in dup.items():
        if len(ns) > 1:
            print(f"  Same QID for several names: {q} {ns}")
    seasons = sorted({s for s, _ in rows})
    print(f"club_season_tier.csv: {len(rows)} rows, seasons {seasons[0]}–{seasons[-1]}")


if __name__ == "__main__":
    main()
