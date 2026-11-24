"""Download ONS boundaries and lookups (ONS Open Geography Portal, ArcGIS REST API).

  LAD 2021 (December 2021, generalised, UK)        -> England local authority districts (309)
  LSOA 2021 (super generalised) with RUC 2021      -> neighbourhoods + rural-urban class
  LSOA 2021 -> LAD 2021 lookup                     -> to aggregate LSOA data to LAD 2021

LAD 2021 is used because the ONS population series needed for the births baseline is
back-cast to 1981 only on April 2021 local authority boundaries.

Outputs (GeoJSON, EPSG:4326): data/raw/ons/<layer>_<date>.geojson ; lookup as CSV.
Source: Office for National Statistics, licensed under the Open Government Licence v3.0.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # pipeline/: common, season_rule

import json

import pandas as pd

from common import RAW, _get, today

BASE = "https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/{}/FeatureServer/0/query"
LAYERS = {
    "lad21_uk_bgc": ("Local_Authority_Districts_December_2021_UK_BGC_2022", "1=1"),
    "lsoa21_ew_bsc_ruc": ("LSOA_2021_EW_BSC_V4_RUC", "LSOA21CD LIKE 'E%'"),
    # Travel to Work Areas 2011: functional areas that contain a town and its catchment,
    # used to absorb the "hospital effect" (birthplaces recorded at the maternity hospital)
    "ttwa11_uk_gcb": ("Travel_to_Work_Areas_Dec_2011_GCB_in_United_Kingdom_2022", "1=1"),
}
LOOKUPS = {
    "lsoa21_lad21_lookup": ("LSOA21_PCON24_LAD21_EW_LU", "LSOA21CD LIKE 'E%'"),
    "lad21_rgn21_lookup": ("LAD21_RGN21_EN_LU_e39114ca0d934551b012bba304cdd11f", "1=1"),
}


def fetch_features(service: str, where: str, geometry: bool, page: int = 1000) -> list[dict]:
    meta = _get(BASE.format(service).rsplit("/query", 1)[0], {"f": "json"}).json()
    oid = meta.get("objectIdField", "OBJECTID")
    feats, offset = [], 0
    while True:
        params = {"where": where, "outFields": "*", "f": "geojson" if geometry else "json",
                  "resultOffset": offset, "resultRecordCount": page, "orderByFields": oid}
        if geometry:
            params["outSR"] = 4326
        else:
            params["returnGeometry"] = "false"
        r = _get(BASE.format(service), params).json()
        batch = r.get("features", [])
        feats += batch
        if len(batch) < page:
            break
        offset += page
    return feats


def main() -> None:
    out_dir = RAW / "ons"
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, (service, where) in LAYERS.items():
        feats = fetch_features(service, where, geometry=True)
        path = out_dir / f"{name}_{today()}.geojson"
        path.write_text(json.dumps({"type": "FeatureCollection", "features": feats}))
        print(f"{name}: {len(feats)} features -> {path.name}")
    for name, (service, where) in LOOKUPS.items():
        lk = fetch_features(service, where, geometry=False)
        df = pd.DataFrame([f["attributes"] for f in lk])
        path = out_dir / f"{name}_{today()}.csv"
        df.to_csv(path, index=False)
        print(f"{name}: {len(df)} rows, columns {list(df.columns)} -> {path.name}")


if __name__ == "__main__":
    main()
