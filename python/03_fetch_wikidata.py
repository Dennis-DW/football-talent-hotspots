"""Fetch players and club memberships from Wikidata.

1. Memberships: for each club that was in tier 1–2 in any season 1992/93–2025/26, every
   non-deprecated P54 (member of sports team) statement of an association football player
   (P106 = Q937857) born 1970 or later, with start (P580) / end (P582) dates and their
   precision, and matches played (P1350). One query per club.
2. Players: for every player found, birth date (+ precision), sex, place of birth with its
   coordinates and country, and positions. Queried in batches.

Outputs (dated snapshots):
  data/raw/wikidata_memberships_<date>.parquet
  data/raw/wikidata_players_<date>.parquet
"""
from __future__ import annotations

import pandas as pd

from common import FIRST_SEASON, PROCESSED, RAW, qid, sparql, today

BIRTH_FROM = "1970-01-01T00:00:00Z"  # wider than the 1975 cohort start; filtered later

MEMBERSHIP_QUERY = """
SELECT ?player ?st ?start ?startPrec ?end ?endPrec ?apps WHERE {{
  ?player p:P54 ?st .
  ?st ps:P54 wd:{club} .
  FILTER NOT EXISTS {{ ?st wikibase:rank wikibase:DeprecatedRank }}
  ?player wdt:P106 wd:Q937857 ;
          wdt:P569 ?birth .
  FILTER (?birth >= "{birth_from}"^^xsd:dateTime)
  OPTIONAL {{ ?st pqv:P580 ?sv . ?sv wikibase:timeValue ?start ; wikibase:timePrecision ?startPrec . }}
  OPTIONAL {{ ?st pqv:P582 ?ev . ?ev wikibase:timeValue ?end ; wikibase:timePrecision ?endPrec . }}
  OPTIONAL {{ ?st pq:P1350 ?apps . }}
}}
"""

PLAYER_QUERY = """
SELECT ?player ?label ?birth ?birthPrec ?sex ?place ?placeLabel ?coord ?placeCountry
       (GROUP_CONCAT(DISTINCT ?posLabel; separator="|") AS ?positions) WHERE {{
  VALUES ?player {{ {values} }}
  OPTIONAL {{ ?player rdfs:label ?label . FILTER(LANG(?label) = "en") }}
  OPTIONAL {{ ?player p:P569 ?bs . ?bs a wikibase:BestRank ; psv:P569 ?bv .
             ?bv wikibase:timeValue ?birth ; wikibase:timePrecision ?birthPrec . }}
  OPTIONAL {{ ?player wdt:P21 ?sex . }}
  OPTIONAL {{ ?player wdt:P19 ?place .
             OPTIONAL {{ ?place rdfs:label ?placeLabel . FILTER(LANG(?placeLabel) = "en") }}
             OPTIONAL {{ ?place wdt:P625 ?coord . }}
             OPTIONAL {{ ?place wdt:P17 ?placeCountry . }} }}
  OPTIONAL {{ ?player wdt:P413 ?pos . ?pos rdfs:label ?posLabel . FILTER(LANG(?posLabel) = "en") }}
}}
GROUP BY ?player ?label ?birth ?birthPrec ?sex ?place ?placeLabel ?coord ?placeCountry
"""


def fetch_memberships(clubs: pd.DataFrame) -> pd.DataFrame:
    frames = []
    for i, (club_qid, club_name) in enumerate(clubs.itertuples(index=False), 1):
        rows = sparql(MEMBERSHIP_QUERY.format(club=club_qid, birth_from=BIRTH_FROM))
        df = pd.DataFrame(rows)
        if not df.empty:
            df["club_qid"] = club_qid
            frames.append(df)
        print(f"  [{i}/{len(clubs)}] {club_name}: {len(df)} memberships", flush=True)
    m = pd.concat(frames, ignore_index=True)
    m["player_qid"] = m["player"].map(qid)
    m["statement_id"] = m["st"].map(qid)
    m = m.drop(columns=["player", "st"])
    # one statement can have several P1350 values; keep the largest
    if "apps" in m:
        m["apps"] = pd.to_numeric(m["apps"], errors="coerce")
        m = (m.sort_values("apps", ascending=False, na_position="last")
               .drop_duplicates("statement_id"))
    return m.reset_index(drop=True)


def fetch_players(player_qids: list[str], batch: int = 250) -> pd.DataFrame:
    frames = []
    for i in range(0, len(player_qids), batch):
        values = " ".join(f"wd:{q}" for q in player_qids[i : i + batch])
        frames.append(pd.DataFrame(sparql(PLAYER_QUERY.format(values=values))))
        print(f"  players {min(i + batch, len(player_qids))}/{len(player_qids)}", flush=True)
    p = pd.concat(frames, ignore_index=True)
    for col in ("player", "sex", "place", "placeCountry"):
        if col in p:
            p[col] = p[col].map(lambda v: qid(v) if isinstance(v, str) else v)
    return p.rename(columns={"player": "player_qid", "place": "place_qid",
                             "placeLabel": "place_label", "placeCountry": "place_country_qid"})


def main() -> None:
    tiers = pd.read_csv(PROCESSED / "club_season_tier.csv")
    clubs = (tiers[(tiers.season >= FIRST_SEASON) & (tiers.tier <= 2)]
             .drop_duplicates("club_qid")[["club_qid", "club_name"]]
             .sort_values("club_name"))
    print(f"Fetching memberships for {len(clubs)} clubs")
    memberships = fetch_memberships(clubs)
    players = sorted(memberships.player_qid.unique())
    print(f"{len(memberships)} memberships, {len(players)} players. Fetching player details")
    details = fetch_players(players)

    stamp = today()
    m_path = RAW / f"wikidata_memberships_{stamp}.parquet"
    p_path = RAW / f"wikidata_players_{stamp}.parquet"
    memberships.to_parquet(m_path, index=False)
    details.to_parquet(p_path, index=False)
    print(f"Wrote {m_path.name} ({len(memberships)} rows) and {p_path.name} ({len(details)} rows)")


if __name__ == "__main__":
    main()
