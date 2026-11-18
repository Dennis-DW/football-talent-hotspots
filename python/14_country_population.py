"""Average national population 1975–2005, for players per million by country of birth (RQ4).

  Countries:             World Bank WDI SP.POP.TOTL (based on UN World Population Prospects)
  England/Scotland/Wales: ONS mid-year estimates via Nomis (NM_31_1), 1981–2005
  Northern Ireland:       not available on Nomis -> left missing (counts only)

Output: data/processed/country_population.csv (code, name, pop_mean, years, source)
Raw:    data/raw/worldbank_SP.POP.TOTL_<date>.json
"""
from __future__ import annotations

import io

import pandas as pd

from common import PROCESSED, RAW, _get, save_json, today


def main() -> None:
    rows, page, pages = [], 1, 1
    while page <= pages:
        r = _get("https://api.worldbank.org/v2/country/all/indicator/SP.POP.TOTL",
                 {"date": "1975:2005", "format": "json", "per_page": 20000, "page": page}).json()
        pages = r[0]["pages"]
        rows += r[1]
        page += 1
    save_json({"retrieved": today(), "data": rows}, RAW / f"worldbank_SP.POP.TOTL_{today()}.json")
    wb = pd.DataFrame([{"code": x["countryiso3code"], "name": x["country"]["value"], "year": int(x["date"]),
                        "pop": x["value"]} for x in rows if x["countryiso3code"]])
    wb = (wb.dropna(subset=["pop"]).groupby(["code", "name"])
            .agg(pop_mean=("pop", "mean"), n_years=("pop", "size")).reset_index())
    wb["years"] = "1975–2005"
    wb["source"] = "World Bank WDI SP.POP.TOTL"

    r = _get("https://www.nomisweb.co.uk/api/v01/dataset/NM_31_1.data.csv",
             {"geography": "E92000001,S92000003,W92000004", "date": ",".join(map(str, range(1981, 2006))),
              "sex": 7, "age": 0, "measures": 20100, "select": "geography_name,date_name,obs_value"})
    uk = pd.read_csv(io.StringIO(r.text)).groupby("GEOGRAPHY_NAME").OBS_VALUE.agg(["mean", "size"]).reset_index()
    uk = pd.DataFrame({"code": uk.GEOGRAPHY_NAME, "name": uk.GEOGRAPHY_NAME, "pop_mean": uk["mean"],
                       "n_years": uk["size"], "years": "1981–2005", "source": "ONS mid-year estimates (Nomis NM_31_1)"})
    out = pd.concat([wb, uk], ignore_index=True)
    out.to_csv(PROCESSED / "country_population.csv", index=False)
    print(f"World Bank countries/aggregates: {len(wb)} | UK nations: {list(uk.code)}")


if __name__ == "__main__":
    main()
