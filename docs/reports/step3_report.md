# Step 3 Report: English Area Data

**Project:** football-talent-hotspots, i.e. where England's Premier League and Championship footballers come from
**Author:** Dennis Wambua
**Step:** 3 of 8
**Completed:** 18 November 2026
**Related:** [Work Plan](../WORKPLAN.md) · [Data Quality Report](data_quality_step3.md) · [Step 2 Report](step2_report.md) · [Proposal v2.1](../Talent_Hotspots_Technical_Research_Proposal.pdf)

---

## 1. Purpose

Step 3 builds the **area side** of the study. For every area of England we need:

1. **How many boys were born there in each year 1975–2005.** This is the baseline for the expected number of players (proposal section 6.4).
2. **The explanatory variables for RQ3:** deprivation, urbanisation, and how close the area was to a professional football club when its children were growing up.

The player side (Step 2) and the area side (Step 3) are combined in Step 4 to compute observed vs. expected counts.

---

## 2. Final result

**Spatial unit:** the **309 local authority districts (LADs) of England**, on 2021 boundaries, built from **33,755 neighbourhoods (LSOAs)**.

| Variable | What it measures | Source | Range across LADs | Median |
|---|---|---|---|---|
| `births_male` (per LAD and year) | Boys born, 1975–2005 (baseline for expected counts) | ONS mid-year estimates (Nomis) | Cohort total 330 – 235,665 | 22,113 |
| `imd_score` | Deprivation (higher = more deprived) | English Indices of Deprivation 2025 | 5.9 – 43.5 | 19.0 |
| `urban_share` | Share of residents in urban neighbourhoods | ONS Rural-Urban Classification 2021 | 0 – 1 | 0.87 |
| `dist_club_km` | Distance to the nearest professional club when each birth cohort was 12 | Wikidata club grounds + manual fixes | 1.1 – 162.2 km | 13.8 km |

**Totals:** 9.54 million male births in England across 1975–2005.

**Extremes:**

| | Highest | Lowest |
|---|---|---|
| Deprivation | Blackpool (43.5), Middlesbrough (40.0), Burnley (38.7) | Hart (5.9), Wokingham (6.1), Rushcliffe (7.8) |
| Distance to a club | Isles of Scilly (162 km), Cornwall (60 km), Copeland (57 km), Dover (57 km) | Hammersmith & Fulham (1.1 km), Kensington & Chelsea (1.7 km), Islington (1.8 km) |
| Urban share | 95 LADs are fully urban | 1 LAD is fully rural |

**How the explanatory variables relate to each other (correlation across LADs):**

| | Deprivation | Urban share | Distance to club |
|---|---|---|---|
| Deprivation | 1 | 0.36 | −0.22 |
| Urban share | 0.36 | 1 | **−0.59** |
| Distance to club | −0.22 | **−0.59** | 1 |

Urban areas tend to be closer to clubs (r = −0.59). That's a moderate overlap, so the Step 7 models need a multicollinearity check (variance inflation factors).

### Output files

| File | Contents |
|---|---|
| `data/processed/lad21_england.gpkg` | 309 LAD polygons, British National Grid (EPSG:27700) |
| `data/processed/lad21_covariates.csv` | One row per LAD: IMD, urban share, club distance, population, area |
| `data/processed/births_lad_year.csv` | Male births by LAD and birth year 1975–2005, with the method used |
| `data/processed/population_lad_year.csv` | Total population by LAD, 1981–2005 (for the sensitivity analysis) |
| `data/processed/lsoa21_england.csv` | 33,755 LSOAs: LAD, IMD score, population, urban/rural, centroid |
| `data/processed/club_season_ground.csv` | Ground location of every league club in every season, 1985/86–2025/26 |
| `data/processed/lad21_season_dist_club.csv` | Distance to the nearest club by LAD and season |
| `data/manual/club_ground_overrides.csv` | 6 documented temporary ground-shares |
| `data/manual/category1_academies.csv` | Template for the Category 1 academy list (to be compiled) |
| `data/raw/ons/`, `data/raw/imd/`, `data/raw/nomis_*` | Dated raw downloads |

---

## 3. What was done

### 3.1 Finding the right data
Every data address was found by **querying the publishers' own catalogues**, not guessed:
- the ONS Open Geography Portal service list (3,853 layers searched)
- the Nomis dataset catalogue
- the GOV.UK statistics page for IMD 2025

### 3.2 Boundaries (`pipeline/areas/11_ons_boundaries.py`)
Downloaded from the ONS Open Geography Portal:
- **LAD December 2021** boundaries, filtered to the 309 in England
- **LSOA 2021** boundaries, which already include the **2021 rural-urban class** of each neighbourhood
- the official **LSOA 2021 → LAD 2021 lookup**

All 33,755 English LSOAs matched a LAD.

### 3.3 Births baseline (`pipeline/areas/10_births_baseline.py`)
The plan was ONS **live births by local authority**. Their Nomis dataset (NM_205_1) only starts in **2013**, so the baseline uses the closest official substitute: **boys aged under 1** in ONS mid-year population estimates (NM_31_1), available from 1981.

| Birth years | How births are estimated |
|---|---|
| 1981–2005 | Average of boys aged under 1 at mid-year *y* and mid-year *y+1*. A mid-year count covers babies born July to June, so averaging two years centres it on calendar year *y*. |
| 1976–1980 | Boys aged 1–4 in mid-1981, divided by 4 |
| 1975 | Boys aged 5–9 in mid-1981, divided by 5 |

**Check:** the England totals follow the known birth trend:

| 1975 | 1978 | 1981 | 1985 | 1990 | 1995 | 2000 | 2005 |
|---|---|---|---|---|---|---|---|
| 309,345 | 286,840 | 303,016 | 315,034 | 332,976 | 311,842 | 289,580 | 314,474 |

That's the late-1970s low, the 1990 peak and the late-1990s dip. No LAD has missing or zero values.

Total population (all ages) for 1981–2005 was also saved for the planned **total-population sensitivity analysis**.

### 3.4 Deprivation (IMD 2025)
The **English Indices of Deprivation 2025** were published in late 2025 on 2021 LSOAs, the same neighbourhoods as our boundaries. File 7 (all scores plus population denominators) was downloaded from GOV.UK. Each LAD's score is the **population-weighted average** of its LSOA scores.

### 3.5 Urbanisation
The **2021 Rural-Urban Classification** comes with the LSOA boundary layer. Each LAD's `urban_share` is the share of its residents living in LSOAs classed as urban.

### 3.6 Club grounds (`pipeline/clubs/09_club_grounds.py`)
- Every English league club (tiers 1–4, 118 clubs) was looked up in Wikidata for its **home ground and coordinates**, including start and end dates where recorded, so clubs that moved are placed correctly.
- **6 manual overrides** fix long temporary ground-shares that Wikidata doesn't record by season:

| Club | Seasons | Played at |
|---|---|---|
| Brighton & Hove Albion | 1997/98–1998/99 | Priestfield Stadium, Gillingham |
| Bristol Rovers | 1986/87–1995/96 | Twerton Park, Bath |
| Charlton Athletic | 1985/86–1990/91 | Selhurst Park |
| Charlton Athletic | 1991/92 | Boleyn Ground (Upton Park) |
| Coventry City | 2013/14 | Sixfields Stadium, Northampton |
| Coventry City | 2019/20–2020/21 | St Andrew's, Birmingham |

Venue coordinates for the overrides are taken from Wikidata via the venues' Wikipedia articles, not typed in by hand.

### 3.7 Distance to the nearest professional club (`analysis/prepare/03_area_covariates.R`)
The proposal asks for distance to the nearest professional club **when each birth cohort was aged 12**, since that's when academy recruitment usually starts.
1. For every season 1987/88–2017/18 (the seasons when the 1975–2005 cohorts turned 12), the distance from **each LSOA centre** to the **nearest of that season's 91–92 league grounds** was measured in British National Grid (metres).
2. Each LAD's distance for that season is the **population-weighted average** of its LSOAs.
3. These are combined across seasons, **weighted by the number of boys born in each year**: `dist_club_i = Σ_y births_i,y × distance_i(season y+12) / Σ_y births_i,y`

### 3.8 Quality report
`pipeline/reports/12_step3_report.py` writes `docs/reports/data_quality_step3.md`.

---

## 4. Challenges and how they were solved

| # | Challenge | What happened | Solution |
|---|---|---|---|
| 1 | **No historical local authority births** | Nomis LA live births start in 2013; the players were born 1975–2005. | Used boys aged under 1 from ONS mid-year estimates (from 1981), with the 1981 age bands for 1975–80. Checked against the known national trend. |
| 2 | **Boundary changes** | 2023 council mergers (Cumbria, North Yorkshire, Somerset) mean the 2023-boundary series has zeros before 2023. | Used **April 2021 boundaries (309 LADs)**, the only version back-dated to 1981, and matched the map boundaries to them. |
| 3 | **Finding exact download addresses** | The ONS portal has thousands of layers with similar names. | Searched the publishers' catalogues programmatically and checked every layer's fields and record counts before downloading. |
| 4 | **Different ID fields between layers** | The LAD layer uses `OBJECTID`, the LSOA layer `FID`, so the first LAD download came back empty. | The download script now reads each layer's ID field from its metadata. |
| 5 | **Wikidata stores mostly current grounds** | Only 5 clubs had dated ground changes in Wikidata. | Moves within the same town barely affect LAD-level distance. The long temporary moves were added as documented overrides. |
| 6 | **Club IDs typed from memory were wrong** | Two of four IDs in the first version of the overrides were wrong (Brighton, Coventry). | Caught by checking against the club table. The script now **stops** if an override's ID and club name don't match. |
| 7 | **No official Category 1 academy list** | The Premier League doesn't publish a historical list; only individual club announcements exist. | Deferred to before Step 7 (the only step that uses it). It will be compiled club by club, each with a source link. |
| 8 | **File permissions** | Files written inside the Docker container belonged to the container's root user. | Ownership is reset to your user after each run. |

---

## 5. Limitations

1. **The births baseline is a proxy.** Boys aged under 1 at mid-year are births *minus* infant deaths and families who moved away, *plus* babies who moved in. Nationally the totals are close to registered births, but small local differences are possible. For 1975–80 the estimate comes from 1981 age groups, which is less precise.
2. **2021 boundaries for all years.** The ONS series is back-dated to 2021 boundaries by the ONS itself; any error in that back-dating carries through.
3. **Deprivation is measured now, not at birth.** IMD 2025 describes areas today. Some areas have changed a lot since the 1970s–2000s (e.g. regenerated inner-city districts). The proposal already lists this; a sensitivity analysis with an older deprivation measure remains possible.
4. **Neighbourhood population weights are from 2022.** They're used to average deprivation, urbanisation and distance within a LAD, but population distribution within a LAD may have been different decades ago.
5. **Club grounds are approximate for some seasons.** Most clubs are placed at their current ground for all seasons. Moves within a town (e.g. Arsenal from Highbury to the Emirates, 2006) change distances by only a few kilometres.
6. **Maidstone United (1989/90–1991/92)** has no ground in Wikidata and is left out of the nearest-club calculation for those three seasons. The effect is negligible: the nearest club for Kent is barely affected.
7. **Urbanisation and club distance overlap** (r = −0.59), which needs checking in the Step 7 models.
8. **Category 1 academies not yet compiled**, so the academy-distance variable isn't available yet.

---

## 6. Deviations from the proposal (v2.1)

| Proposal | What was done | Reason |
|---|---|---|
| ONS live births by local authority as the baseline | Boys aged under 1 from ONS mid-year estimates | LA births on Nomis start in 2013 |
| "Current" local authority boundaries (~300) | April/December 2021 boundaries (309) | Only boundaries with population data back to 1981 |
| IMD (2019 or latest) | IMD **2025** | Newest release, on the same 2021 neighbourhoods |
| MSOA boundaries downloaded | Skipped | Made optional in v2.1 |
| GHS-POP grids downloaded in Step 3 | Moved to Step 5 | Only used for the point-pattern analysis |
| Category 1 academy list in Step 3 | Template only; compiled before Step 7 | No authoritative list; needs a source per club |

These should be added to the proposal's methodology (sections 6.3 and 6.2) at the next revision, together with the Step 2 changes.

---

## 7. Implications for the next steps

- **Step 4:** combine players (Step 2) with births (Step 3) to compute observed (O), expected (E) and SR = O/E for each of the 309 LADs and for the 10 km and 20 km hexagon grids. Births must be shared out to hexagons. The plan is to apportion each LAD's births to its LSOAs by population, then to hexagons.
- **Step 5:** download GHS-POP (1975–2005) to build the population surface for Ripley's K.
- **Step 7:** check the overlap between urban share and club distance; compile the Category 1 academy list for the post-EPPP sub-model; consider an older deprivation measure as a sensitivity check.

---

## 8. How to reproduce

Inside the app container (`docker compose exec app bash`):

```bash
python pipeline/clubs/09_club_grounds.py        # club grounds by season (needs Step 2's club table)
python pipeline/areas/10_births_baseline.py     # births baseline from Nomis
python pipeline/areas/11_ons_boundaries.py      # ONS boundaries + lookup (~5 min)
# IMD 2025 File 7 must be in data/raw/imd/ (downloaded from GOV.UK)
Rscript analysis/prepare/03_area_covariates.R   # LAD covariates (~2 min)
python pipeline/reports/12_step3_report.py
```

Tests: `pytest tests/` (20 tests, all passing).

---

## Sources

- Office for National Statistics, Open Geography Portal: LAD December 2021 boundaries, LSOA 2021 boundaries with RUC 2021, LSOA→LAD lookup. Open Government Licence v3.0.
- Office for National Statistics via Nomis: Population estimates, local authority based by five-year age band (NM_31_1). Open Government Licence v3.0.
- Ministry of Housing, Communities & Local Government: [English indices of deprivation 2025](https://www.gov.uk/government/statistics/english-indices-of-deprivation-2025), File 7. Open Government Licence v3.0.
- Wikidata: club home venues (P115) and coordinates (P625). CC0.
