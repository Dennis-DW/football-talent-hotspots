"""Birthplace resolution level and geocoding fallback.

1. Resolution level of each Wikidata birthplace (geo_level):
     country – the birthplace item is itself a country / constituent country (e.g. England)
     admin   – a county, region or similar administrative area
     town    – anything else with coordinates (city, town, village, district, hospital…)
   Country-level birthplaces are excluded from the spatial analyses (kept for RQ4).
2. Fallback: for study players whose birthplace has no coordinates in Wikidata, query
   Nominatim (OpenStreetMap) with "<place label>, <country label>" at most once per second.

Input/Output: data/processed/players_eligible.parquet (adds geo_level, geo_source)
Raw responses: data/raw/nominatim_<date>.json
"""
from __future__ import annotations

import time

import pandas as pd
import requests

from common import MANUAL, PROCESSED, RAW, USER_AGENT, qid, save_json, sparql, today

COUNTRY_TYPES = {"Q6256", "Q3624078", "Q3336843", "Q15634554", "Q7275"}  # country, sovereign
# state, constituent country (UK), state with limited recognition, state
ADMIN_TYPES = {
    "Q180673",   # ceremonial county of England
    "Q769603",   # non-metropolitan county
    "Q1136601",  # metropolitan county
    "Q48091",    # region of England
    "Q1187580",  # historic county
    "Q10864048", # first-level administrative division
    "Q13220204", # second-level administrative division
    "Q35657",    # state of the United States
    "Q36784",    # region of France
    "Q15284",    # municipality (kept as admin only when large; see below)
}
ADMIN_TYPES.discard("Q15284")


def place_types(place_qids: list[str]) -> dict[str, set[str]]:
    out: dict[str, set[str]] = {}
    for i in range(0, len(place_qids), 300):
        values = " ".join(f"wd:{q}" for q in place_qids[i : i + 300])
        for r in sparql(f"SELECT ?p ?t WHERE {{ VALUES ?p {{ {values} }} ?p wdt:P31 ?t }}"):
            out.setdefault(qid(r["p"]), set()).add(qid(r["t"]))
    return out


def labels(qids: list[str]) -> dict[str, str]:
    out = {}
    for i in range(0, len(qids), 300):
        values = " ".join(f"wd:{q}" for q in qids[i : i + 300])
        for r in sparql(f"""SELECT ?x ?l WHERE {{ VALUES ?x {{ {values} }}
                            ?x rdfs:label ?l FILTER(LANG(?l)="en") }}"""):
            out[qid(r["x"])] = r["l"]
    return out


def nominatim(query: str) -> dict | None:
    r = requests.get("https://nominatim.openstreetmap.org/search",
                     params={"q": query, "format": "jsonv2", "limit": 1, "addressdetails": 0},
                     headers={"User-Agent": USER_AGENT}, timeout=60)
    time.sleep(1.1)  # Nominatim usage policy: max 1 request per second
    r.raise_for_status()
    res = r.json()
    return res[0] if res else None


def nominatim_level(hit: dict) -> str:
    t = (hit.get("addresstype") or hit.get("type") or "").lower()
    if t == "country":
        return "country"
    if t in {"state", "county", "region", "state_district", "province"}:
        return "admin"
    return "town"


def main() -> None:
    path = PROCESSED / "players_eligible.parquet"
    p = pd.read_parquet(path)
    p["geo_source"] = p["lon"].notna().map({True: "wikidata", False: None})

    places = sorted(p["place_qid"].dropna().unique())
    types = place_types(places)

    def level(place):
        if not isinstance(place, str):
            return "no birthplace"
        t = types.get(place, set())
        if t & COUNTRY_TYPES:
            return "country"
        if t & ADMIN_TYPES:
            return "admin"
        return "town"

    p["geo_level"] = p["place_qid"].map(level)
    # Birthplaces that span several local authorities (e.g. "London") cannot be placed in
    # one LAD: their coordinates are a single central point (data/manual/multi_lad_places.csv)
    multi = pd.read_csv(MANUAL / "multi_lad_places.csv")
    p.loc[p["place_qid"].isin(multi.place_qid), "geo_level"] = "region"

    need = p[p["lon"].isna() & p["place_qid"].notna()]
    country_names = labels(sorted(need["place_country_qid"].dropna().unique()))
    raw = {}
    for idx, r in need.iterrows():
        q = r["place_label"] if isinstance(r["place_label"], str) else None
        if not q:
            continue
        c = country_names.get(r["place_country_qid"])
        query = f"{q}, {c}" if c else q
        hit = nominatim(query)
        raw[r["player_qid"]] = {"query": query, "result": hit}
        if hit:
            p.at[idx, "lon"] = float(hit["lon"])
            p.at[idx, "lat"] = float(hit["lat"])
            p.at[idx, "geo_source"] = "nominatim"
            p.at[idx, "geo_level"] = nominatim_level(hit)

    p.loc[p["lon"].isna() & p["place_qid"].notna(), "geo_level"] = "no coordinates"
    save_json({"retrieved": today(), "results": raw}, RAW / f"nominatim_{today()}.json")
    p.to_parquet(path, index=False)

    print(f"Birthplaces without coordinates in Wikidata: {len(need)}; "
          f"geocoded by Nominatim: {sum(1 for v in raw.values() if v['result'])}")
    print("geo_source:", p["geo_source"].value_counts(dropna=False).to_dict())
    print("geo_level:", p["geo_level"].value_counts(dropna=False).to_dict())


if __name__ == "__main__":
    main()
