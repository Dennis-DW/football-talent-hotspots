"""Shared helpers: paths, polite HTTP access to Wikidata/Wikipedia, dated snapshots."""
from __future__ import annotations

import datetime as dt
import json
import time
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
PROCESSED = ROOT / "data" / "processed"
MANUAL = ROOT / "data" / "manual"
REPORTS = ROOT / "docs" / "reports"

USER_AGENT = "football-talent-hotspots/0.1 (academic research project; https://github.com/Dennis-DW/football-talent-hotspots)"
SPARQL_URL = "https://query.wikidata.org/sparql"
WIKIPEDIA_API = "https://en.wikipedia.org/w/api.php"

# First and last seasons of the study, as season start years (1992 = 1992/93)
FIRST_SEASON = 1992
LAST_SEASON = 2025
BIRTH_MIN = dt.date(1975, 1, 1)
BIRTH_MAX = dt.date(2005, 12, 31)

_session = requests.Session()
_session.headers.update({"User-Agent": USER_AGENT})


def today() -> str:
    return dt.date.today().isoformat()


def _get(url: str, params: dict, retries: int = 5, timeout: int = 120) -> requests.Response:
    """GET with exponential back-off; honours Retry-After on 429/503."""
    for attempt in range(retries):
        try:
            r = _session.get(url, params=params, timeout=timeout)
            if r.status_code in (429, 503):
                wait = int(r.headers.get("Retry-After", 2 ** (attempt + 2)))
                time.sleep(wait)
                continue
            r.raise_for_status()
            return r
        except (requests.ConnectionError, requests.Timeout):
            time.sleep(2 ** (attempt + 1))
    raise RuntimeError(f"Request failed after {retries} attempts: {url} {str(params)[:200]}")


def sparql(query: str) -> list[dict]:
    """Run a SPARQL query on the Wikidata Query Service; return bindings as plain dicts."""
    r = _get(SPARQL_URL, {"query": query, "format": "json"})
    time.sleep(1.0)  # be polite between queries
    out = []
    for b in r.json()["results"]["bindings"]:
        out.append({k: v["value"] for k, v in b.items()})
    return out


def wikipedia(params: dict) -> dict:
    p = {"format": "json", "formatversion": 2, **params}
    r = _get(WIKIPEDIA_API, p)
    time.sleep(0.5)
    return r.json()


def qid(uri: str) -> str:
    return uri.rsplit("/", 1)[-1]


def save_json(obj, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=1))


def latest(pattern: str, folder: Path = RAW) -> Path:
    """Most recent dated snapshot matching a glob pattern (e.g. 'wikidata_memberships_*.parquet')."""
    files = sorted(folder.glob(pattern))
    if not files:
        raise FileNotFoundError(f"No file matching {pattern} in {folder}")
    return files[-1]
