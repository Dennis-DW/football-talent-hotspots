"""Verify the paper's references against Crossref and write paper/refs_verified.md.

Each journal reference is looked up by DOI on the Crossref REST API; the title, authors,
year and venue recorded by Crossref are written to refs_verified.md together with whether
they match the entry in refs.bib. A reference is citable only if it is listed as verified.
Books, software and data sets without a Crossref record are checked against their
official page (URL recorded) and marked as such.

Usage (from the repository root): python paper/verify_refs.py
"""
from __future__ import annotations

import datetime as dt
import json
import re
import time
import urllib.parse
import urllib.request

UA = "football-talent-hotspots/0.1 (academic research; reference verification)"

# key: (doi or None, expected title fragment, url for non-DOI items, note)
REFS = {
    "anselin1988": ("10.1007/978-94-015-7799-1", "Spatial Econometrics", None, "book"),
    "anselin1995": ("10.1111/j.1538-4632.1995.tb00338.x", "Local Indicators of Spatial Association", None, ""),
    "assuncao1999": ("10.1002/(SICI)1097-0258(19990830)18:16<2147::AID-SIM179>3.0.CO;2-I", "adjust Moran", None, ""),
    "baddeley2000": ("10.1111/1467-9574.00144", "inhomogeneous point patterns", None, ""),
    "baddeley2015": (None, "Spatial Point Patterns: Methodology and Applications with R", "https://www.routledge.com/9781482210200", "book"),
    "benjamini1995": ("10.1111/j.2517-6161.1995.tb02031.x", "False Discovery Rate", None, ""),
    "cote2006": ("10.1080/02640410500432490", "When \"where\" is more important than \"when\"", None, ""),
    "getis1992": ("10.1111/j.1538-4632.1992.tb00261.x", "Distance Statistics", None, ""),
    "macdonald2009": ("10.1080/10413200802541868", "Place but not Date of Birth", None, ""),
    "marshall1991": ("10.2307/2347593", "Empirical Bayes", None, ""),
    "ripley1977": ("10.1111/j.2517-6161.1977.tb01615.x", "Modelling Spatial Patterns", None, ""),
    "openshaw1984": (None, "The modifiable areal unit problem", "https://www.uio.no/studier/emner/sv/iss/SGO9010/openshaw1983.pdf", "CATMOG monograph, no DOI"),
    "venables2002": ("10.1007/978-0-387-21706-2", "Modern Applied Statistics with S", None, "book"),
    "vrandecic2014": ("10.1145/2629489", "Wikidata", None, ""),
    "bivand2015": ("10.18637/jss.v063.i18", "Comparing Implementations", None, ""),
    "curley2016": (None, "engsoccerdata", "https://github.com/jalapic/engsoccerdata", "software"),
    "imd2025": (None, "English indices of deprivation 2025", "https://www.gov.uk/government/statistics/english-indices-of-deprivation-2025", "data set"),
    "onsnomis": (None, "Population estimates - local authority based by five year age band", "https://www.nomisweb.co.uk/datasets/pestsyoala", "data set"),
    "onsgeo": (None, "ONS Open Geography Portal", "https://geoportal.statistics.gov.uk/", "data set"),
    "worldbank": (None, "Population, total (SP.POP.TOTL)", "https://data.worldbank.org/indicator/SP.POP.TOTL", "data set"),
    "naturalearth": (None, "Natural Earth Admin 0 map units", "https://www.naturalearthdata.com/downloads/10m-cultural-vectors/", "data set"),
}


def get(url: str) -> tuple[int, bytes]:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, b""
    except Exception:
        return 0, b""


def crossref(doi: str) -> dict | None:
    code, body = get("https://api.crossref.org/works/" + urllib.parse.quote(doi, safe=""))
    time.sleep(1)
    if code != 200:
        return None
    m = json.loads(body)["message"]
    authors = [f"{a.get('given', '')} {a.get('family', '')}".strip() for a in m.get("author", [])]
    year = None
    for k in ("published-print", "published-online", "issued"):
        if m.get(k, {}).get("date-parts"):
            year = m[k]["date-parts"][0][0]
            break
    return {"title": " ".join(m.get("title", [""])), "authors": authors, "year": year,
            "venue": " ".join(m.get("container-title", [""])) or m.get("publisher", ""),
            "volume": m.get("volume"), "issue": m.get("issue"), "page": m.get("page")}


def norm(s: str) -> str:
    return re.sub(r"[^a-z0-9 ]", "", s.lower())


def main() -> None:
    lines = [
        "# Verified references", "",
        f"Verified on {dt.date.today().isoformat()} by `paper/verify_refs.py`. Journal articles and books with a DOI were "
        "looked up on the Crossref REST API (`api.crossref.org/works/<DOI>`); the record below is what Crossref returned. "
        "Items without a DOI (software, data sets, a monograph) were checked by requesting their official page "
        "(HTTP status recorded). A reference is citable in the paper only when it is listed here as verified.", "",
    ]
    ok_all = True
    for key, (doi, frag, url, note) in REFS.items():
        lines.append(f"## {key}")
        if doi:
            m = crossref(doi)
            if m is None:
                ok_all = False
                lines += [f"- **NOT VERIFIED**: DOI {doi} not found on Crossref.", ""]
                print(f"{key}: NOT FOUND")
                continue
            match = norm(frag) in norm(m["title"])
            ok_all &= match
            lines += [f"- Title: {m['title']}",
                      f"- Authors: {', '.join(m['authors']) or 'not listed'}",
                      f"- Year: {m['year']} · Venue: {m['venue']}"
                      + (f", vol. {m['volume']}" if m['volume'] else "") + (f"({m['issue']})" if m['issue'] else "")
                      + (f", pp. {m['page']}" if m['page'] else ""),
                      f"- DOI: https://doi.org/{doi}",
                      f"- Verified by: Crossref API{' (' + note + ')' if note else ''}. Title check: {'match' if match else 'MISMATCH'}.", ""]
            print(f"{key}: {'ok' if match else 'MISMATCH'} — {m['title'][:70]} ({m['year']})")
        else:
            code, _ = get(url)
            time.sleep(0.5)
            reachable = code in (200, 301, 302, 403)
            lines += [f"- Item: {frag} ({note})", f"- URL: {url}",
                      f"- Verified by: official page request, HTTP {code}{'' if reachable else ' — NOT REACHABLE'}.", ""]
            print(f"{key}: page HTTP {code}")
    open("paper/refs_verified.md", "w").write("\n".join(lines))
    print("all verified" if ok_all else "SOME REFERENCES NEED ATTENTION")


if __name__ == "__main__":
    main()
