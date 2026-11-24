"""Births baseline by local authority and birth year, 1975–2005 (England, LAD 2021).

ONS live births by local authority (Nomis NM_205_1) are only available from 2013, so the
baseline uses ONS mid-year population estimates (Nomis NM_31_1, local authorities as of
April 2021, back-cast to 1981) for **males**:

  birth year y >= 1981 : B(y) = mean( males aged under 1 at mid-year y,
                                       males aged under 1 at mid-year y+1 )
      (the under-1 population at mid-year y was born July y-1 to June y; averaging two
       mid-years centres the count on calendar year y)
  birth year 1976–1980 : B(y) = males aged 1–4 at mid-1981 / 4
  birth year 1975      : B(y) = males aged 5–9 at mid-1981 / 5

These are surviving resident infants, i.e. births net of infant deaths and migration; the
proxy is recorded in `baseline_method`. Total population (all ages, both sexes) for
1981–2005 is saved for the total-population sensitivity analysis.

Outputs: data/processed/births_lad_year.csv   (lad21cd, lad21nm, birth_year, births_male, baseline_method)
         data/processed/population_lad_year.csv (lad21cd, year, population)
         data/raw/nomis_NM_31_1_<date>.csv
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # pipeline/: common, season_rule

import io

import pandas as pd

from common import PROCESSED, RAW, _get, today

URL = "https://www.nomisweb.co.uk/api/v01/dataset/NM_31_1.data.csv"
GEO = "TYPE432"  # local authorities: district / unitary (as of April 2021)
UNDER1, AGE1_4, AGE5_9, ALL_AGES = 1, 2, 3, 0
MALE, TOTAL = 5, 7


def fetch(sex: int, age: int, years: range) -> pd.DataFrame:
    r = _get(URL, {"geography": GEO, "date": ",".join(map(str, years)), "sex": sex, "age": age,
                   "measures": 20100, "select": "date_name,geography_code,geography_name,sex_name,age_name,obs_value"})
    df = pd.read_csv(io.StringIO(r.text))
    return df[df.GEOGRAPHY_CODE.str.startswith("E")]


def main() -> None:
    u1 = fetch(MALE, UNDER1, range(1981, 2007))
    a14 = fetch(MALE, AGE1_4, range(1981, 1982))
    a59 = fetch(MALE, AGE5_9, range(1981, 1982))
    pop = fetch(TOTAL, ALL_AGES, range(1981, 2006))
    pd.concat([u1, a14, a59, pop]).to_csv(RAW / f"nomis_NM_31_1_{today()}.csv", index=False)

    names = u1.drop_duplicates("GEOGRAPHY_CODE").set_index("GEOGRAPHY_CODE").GEOGRAPHY_NAME
    u = u1.pivot(index="GEOGRAPHY_CODE", columns="DATE_NAME", values="OBS_VALUE")
    rows = []
    for lad in u.index:
        for y in range(1981, 2006):
            rows.append((lad, y, (u.at[lad, y] + u.at[lad, y + 1]) / 2, "mean of male under-1 at mid-years y and y+1"))
        q14 = a14.set_index("GEOGRAPHY_CODE").OBS_VALUE.get(lad)
        q59 = a59.set_index("GEOGRAPHY_CODE").OBS_VALUE.get(lad)
        for y in range(1976, 1981):
            rows.append((lad, y, q14 / 4, "male aged 1-4 at mid-1981 / 4"))
        rows.append((lad, 1975, q59 / 5, "male aged 5-9 at mid-1981 / 5"))
    births = pd.DataFrame(rows, columns=["lad21cd", "birth_year", "births_male", "baseline_method"])
    births.insert(1, "lad21nm", births.lad21cd.map(names))
    births = births.sort_values(["lad21cd", "birth_year"])
    births.to_csv(PROCESSED / "births_lad_year.csv", index=False)

    p = pop.rename(columns={"GEOGRAPHY_CODE": "lad21cd", "DATE_NAME": "year", "OBS_VALUE": "population"})
    p[["lad21cd", "year", "population"]].to_csv(PROCESSED / "population_lad_year.csv", index=False)

    tot = births.groupby("birth_year").births_male.sum().round()
    print(f"Local authorities (England, April 2021): {births.lad21cd.nunique()}")
    print("England male births (proxy), selected years:",
          {y: int(tot[y]) for y in [1975, 1978, 1981, 1985, 1990, 1995, 2000, 2005]})
    zero = births[births.births_male <= 0]
    print("Zero or missing values:", len(zero), "| NaN:", int(births.births_male.isna().sum()))


if __name__ == "__main__":
    main()
