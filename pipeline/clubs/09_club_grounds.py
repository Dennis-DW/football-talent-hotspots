"""Home ground location of every English league club in every season, 1985/86–2025/26.

Uses Wikidata home venue (P115) statements with their start (P580) and end (P582)
qualifiers, so clubs that moved ground (e.g. Arsenal: Highbury -> Emirates Stadium in
2006) are placed correctly in each season. Where a club has one venue statement, or none
with dates covering the season, the preferred/most recent venue is used and flagged.

Output: data/processed/club_season_ground.csv
        (season, tier, club_qid, club_name, venue_qid, venue_label, lon, lat, venue_basis)
        data/raw/wikidata_club_venues_<date>.csv
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # pipeline/: common, season_rule

import re

import pandas as pd

from common import MANUAL, PROCESSED, RAW, qid, sparql, today, load_script

title_to_qid = load_script("clubs/02_club_qids.py").title_to_qid

QUERY = """
SELECT ?club ?venue ?venueLabel ?coord ?start ?end ?rank WHERE {{
  VALUES ?club {{ {values} }}
  ?club p:P115 ?st . ?st ps:P115 ?venue ; wikibase:rank ?rank .
  FILTER(?rank != wikibase:DeprecatedRank)
  OPTIONAL {{ ?venue wdt:P625 ?coord . }}
  OPTIONAL {{ ?st pq:P580 ?start . }}
  OPTIONAL {{ ?st pq:P582 ?end . }}
  OPTIONAL {{ ?venue rdfs:label ?venueLabel . FILTER(LANG(?venueLabel) = "en") }}
}}
"""


def year(v):
    m = re.match(r"^(\d{4})", v) if isinstance(v, str) else None
    return int(m.group(1)) if m else None


def main() -> None:
    tiers = pd.read_csv(PROCESSED / "club_season_tier.csv")
    clubs = sorted(tiers.club_qid.unique())
    rows = []
    for i in range(0, len(clubs), 100):
        rows += sparql(QUERY.format(values=" ".join(f"wd:{c}" for c in clubs[i:i + 100])))
    v = pd.DataFrame(rows)
    v["club_qid"] = v.club.map(qid)
    v["venue_qid"] = v.venue.map(qid)
    v["preferred"] = v["rank"].str.endswith("PreferredRank")
    v["start_year"] = v.start.map(year)
    v["end_year"] = v.end.map(year)
    xy = v.coord.str.extract(r"Point\(([-0-9.eE]+) ([-0-9.eE]+)\)").astype(float)
    v["lon"], v["lat"] = xy[0], xy[1]
    v = v.drop_duplicates(["club_qid", "venue_qid", "start_year", "end_year"])
    v.drop(columns=["club", "venue", "rank"]).to_csv(RAW / f"wikidata_club_venues_{today()}.csv", index=False)
    v = v[v.lon.notna()]

    out = []
    for r in tiers.itertuples():
        cv = v[v.club_qid == r.club_qid]
        # a season (start year s) is covered if the venue was used between Aug s and May s+1
        dated = cv[cv.start_year.notna() | cv.end_year.notna()]
        cover = dated[(dated.start_year.fillna(0) <= r.season + 1) & (dated.end_year.fillna(9999) > r.season)]
        if len(cover):
            pick, basis = cover.sort_values("start_year", na_position="first").iloc[-1], "dated"
        elif len(cv):
            pick = cv.sort_values(["preferred", "start_year"], ascending=False, na_position="last").iloc[0]
            basis = "undated"
        else:
            out.append({"season": r.season, "tier": r.tier, "club_qid": r.club_qid,
                        "club_name": r.club_name, "venue_basis": "missing"})
            continue
        out.append({"season": r.season, "tier": r.tier, "club_qid": r.club_qid, "club_name": r.club_name,
                    "venue_qid": pick.venue_qid, "venue_label": pick.venueLabel,
                    "lon": pick.lon, "lat": pick.lat, "venue_basis": basis})
    out = pd.DataFrame(out)

    # Documented temporary ground-shares that Wikidata does not record by season
    ov = pd.read_csv(MANUAL / "club_ground_overrides.csv")
    names = tiers.drop_duplicates("club_qid").set_index("club_qid").club_name
    bad = ov[ov.club_qid.map(names) != ov.club_name]
    if len(bad):
        raise ValueError(f"Override club IDs do not match names:\n{bad[['club_qid', 'club_name']]}")
    titles = title_to_qid(sorted(ov.venue_wikipedia_title.unique()))
    missing = set(ov.venue_wikipedia_title) - set(titles)
    if missing:
        raise ValueError(f"Venue articles not found: {missing}")
    vq = sorted(set(titles.values()))
    coords = {}
    for r in sparql(f"""SELECT ?v ?c ?l WHERE {{ VALUES ?v {{ {' '.join('wd:' + q for q in vq)} }}
                        ?v wdt:P625 ?c . OPTIONAL {{ ?v rdfs:label ?l FILTER(LANG(?l)="en") }} }}"""):
        m = re.match(r"Point\(([-0-9.eE]+) ([-0-9.eE]+)\)", r["c"])
        coords[qid(r["v"])] = (float(m.group(1)), float(m.group(2)), r.get("l"))
    n_over = 0
    for r in ov.itertuples():
        q = titles[r.venue_wikipedia_title]
        lon, lat, label = coords[q]
        sel = (out.club_qid == r.club_qid) & out.season.between(r.first_season, r.last_season)
        out.loc[sel, ["venue_qid", "venue_label", "lon", "lat", "venue_basis"]] = [q, label, lon, lat, "manual override"]
        n_over += int(sel.sum())
    print(f"Manual ground overrides applied to {n_over} club-seasons")

    out.to_csv(PROCESSED / "club_season_ground.csv", index=False)

    print(f"Clubs: {len(clubs)} | venue statements with coordinates: {len(v)}")
    print("Club-seasons by venue basis:", out.venue_basis.value_counts().to_dict())
    miss = out[out.venue_basis == "missing"].drop_duplicates("club_qid")
    for r in miss.itertuples():
        print("  MISSING venue:", r.club_name, r.club_qid)
    moves = out.dropna(subset=["venue_qid"]).groupby("club_qid").venue_qid.nunique()
    print("Clubs with more than one ground over the period:", int((moves > 1).sum()))


if __name__ == "__main__":
    main()
