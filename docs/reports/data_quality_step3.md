# Data Quality Report — Step 3

*Generated 2026-11-18 by `python/12_step3_report.py`.*

## Summary

| Item | Value |
|---|---|
| Spatial unit | Local authority districts, April/December 2021 boundaries (England) |
| Local authorities | 309 |
| LSOAs (2021) | 33,755 (all matched to a LAD and to IMD 2025) |
| Births baseline | Male infants, ONS mid-year estimates (Nomis NM_31_1), birth years 1975–2005 |
| Deprivation | English Indices of Deprivation 2025, IMD score (LSOA 2021) |
| Urbanisation | Rural-Urban Classification 2021 (LSOA) |
| Club grounds | 118 clubs, seasons 1985/86–2025/26 |
| Category 1 academies | 0 entries compiled (to be completed before the Step 7 sub-model) |

## Births baseline

ONS local-authority live births on Nomis start only in 2013, so the baseline uses ONS
mid-year population estimates for males on April 2021 LAD boundaries (back-cast to 1981):

| Method | From | To |
|---|---|---|
| male aged 1-4 at mid-1981 / 4 | 1976 | 1980 |
| male aged 5-9 at mid-1981 / 5 | 1975 | 1975 |
| mean of male under-1 at mid-years y and y+1 | 1981 | 2005 |

England totals, selected years:

| Birth year | Male births (proxy) |
|---|---|
| 1975 | 309,345 |
| 1978 | 286,840 |
| 1981 | 303,016 |
| 1985 | 315,034 |
| 1990 | 332,976 |
| 1995 | 311,842 |
| 2000 | 289,580 |
| 2005 | 314,474 |

These are surviving resident infants (births net of infant deaths and migration). They are
close to registered male births and follow the known trend (late-1970s low, 1990 peak).

## Local authority covariates

| Variable | min | 25% | 50% | 75% | max |
|---|---|---|---|---|---|
| imd_score | 5.91 | 13.76 | 18.98 | 25.47 | 43.47 |
| urban_share | 0.0 | 0.63 | 0.87 | 1.0 | 1.0 |
| dist_club_km | 1.09 | 6.09 | 13.75 | 22.23 | 162.24 |
| pop2022 | 2281.0 | 104283.0 | 144561.0 | 227298.0 | 1154221.0 |

- `imd_score`: population-weighted mean IMD 2025 score (higher = more deprived).
- `urban_share`: share of the population in urban LSOAs.
- `dist_club_km`: births-weighted distance from the LAD's population to the nearest
  professional club ground (tiers 1–4) in the season each birth cohort was aged 12.

Furthest from a club: Isles of Scilly (162.2 km), Cornwall (59.6 km), Copeland (57.0 km), Dover (56.9 km), Torridge (55.8 km).
Closest: Hammersmith and Fulham (1.1 km), Kensington and Chelsea (1.7 km), Islington (1.8 km), Ipswich (2.4 km), Watford (2.4 km).

## Club grounds

| Ground location basis | Club-seasons |
|---|---|
| undated | 3564 |
| dated | 182 |
| manual override | 22 |
| missing | 3 |

Wikidata records only the current ground for most clubs. Moves within the same town have
little effect at LAD level; the long temporary moves (Brighton, Bristol Rovers, Charlton,
Coventry) are corrected in `data/manual/club_ground_overrides.csv`. Maidstone United
(1989/90–1991/92, tier 4) has no ground in Wikidata and is omitted for those seasons.

## Limitations

1. The births baseline is a proxy (male infants at mid-year), not registered births.
2. LSOA population weights are mid-2022, not contemporary with the birth cohorts.
3. IMD 2025 measures deprivation now, not when the players were born.
4. Club grounds are mostly current grounds applied to all seasons (see above).
5. Category 1 academy list still to be compiled with a source per club.
