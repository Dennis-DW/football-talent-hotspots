# Step 2 Report: Player Data and League Eligibility

**Project:** football-talent-hotspots, i.e. where England's Premier League and Championship footballers come from
**Author:** Dennis Wambua
**Step:** 2 of 8 (Milestone M1: clean player dataset)
**Completed:** 18 November 2026
**Related:** [Work Plan](../WORKPLAN.md) · [Data Quality Report](data_quality_step2.md) · [Proposal v2.1](../Talent_Hotspots_Technical_Research_Proposal.pdf)

---

## 1. Purpose

Step 2 builds the list of players the study is about: **men born 1975–2005 who played league football in the Premier League or the second tier (First Division to 2004, Championship since) between 1992/93 and 2025/26**, together with their birthplaces. It also separates English-born players (main analysis, RQ1–RQ3) from players born elsewhere (descriptive analysis, RQ4).

---

## 2. Final result

| Measure | Value |
|---|---|
| Clubs that were in the top two divisions at least once, 1992/93–2025/26 | **78** |
| Players fetched from Wikidata (born 1970 or later, any membership at those clubs) | 12,620 |
| **Study players** | **6,581** |
| – certain evidence of a tier 1–2 league appearance | 4,977 (75.6%) |
| – probable evidence | 1,604 (24.4%) |
| Premier League subset (certain + probable) | 4,081 (2,102 certain) |
| Birthplace coordinates available | 6,566 (99.8%) |
| **English-born** (main analysis) | **3,081** (46.8%) |
| – birthplace at town level (usable for local maps) | **3,017** |
| – birthplace only at county level / only "England" | 18 / 46 |
| – Premier League subset | 1,611 (648 certain) |
| Born in Scotland, Wales or Northern Ireland | 439 |
| Born outside the UK | 3,061 players from 129 other countries |

**English-born players by birth decade**

| 1975–79 | 1980s | 1990s | 2000–05 |
|---|---|---|---|
| 542 | 1,183 | 1,127 | 229 |

The 2000–05 group is smaller because many of these players are still early in their careers.

**Top birth countries:** England 3,081 · France 355 · Scotland 233 · Ireland 223 · Spain 222 · Netherlands 161 · Brazil 119 · Wales 119 · Germany 99 · Portugal 94.

### Output files

| File | Contents |
|---|---|
| `data/processed/club_season_tier.csv` | Every English league club's division in every season, 1985/86–2025/26 (tiers 1–4) |
| `data/processed/players_eligible.parquet` | One row per study player: birth date, birthplace, coordinates, birth country, English-born flag, evidence level, Premier League flag |
| `data/processed/membership_seasons.parquet` | Player × club × tier 1–2 season (from Wikidata dates) |
| `data/processed/exclusion_log.csv` | Every excluded player with the reason (6,039 rows) |
| `data/manual/club_qids.csv`, `club_qid_overrides.csv` | Club name → Wikidata ID, including manual fixes |
| `data/manual/validation_sample.csv`, `validation_sample_claude.csv` | The 200-player validation sample and its results |
| `data/raw/*_2026-11-02.parquet`, `*_2026-11-18.*` | Dated raw snapshots (Wikidata, Wikipedia, Nominatim) |

---

## 3. What was done

### 3.1 Club–season–division table
**Why:** a player is in the study only if he played for a club **in a season when that club was in the top two divisions**, so we need every club's division in every season.

1. **engsoccerdata** (R package, pinned to commit `872c5c3`) provided all English league seasons from 1985/86 to 2024/25 except **2022/23** (`R/01_club_tiers_engsoc.R`).
2. **Wikipedia season articles** provided the missing seasons (**2022/23 and 2025/26**) and a cross-check of 2016/17–2024/25 (`python/01_league_tables_wikipedia.py`). The script reads the league table on each season page and links every club to its Wikidata ID.
3. **Club → Wikidata ID matching** (`python/02_club_qids.py`): 117 club names were matched, 98 automatically from the Wikipedia tables, 11 by article-title search and **8 by manual correction**.
4. **Cross-check:** for the 32 season–division tables available in both sources, the club lists matched **exactly (0 mismatches)**.

Seasons start in 1985/86, not 1992/93, because Step 3 needs every professional club at the time each birth cohort was aged 12.

### 3.2 Season assignment rule (fixed before looking at the data)
Wikidata usually gives club join and leave dates **to the year only** (87% of memberships). Seasons run August–May, so "joined 2004" could mean the 2003/04 or the 2004/05 season. To avoid case-by-case choices, the rule was written and tested **before** any player data was examined (`python/season_rule.py`, 13 unit tests):

| Date | Assigned to |
|---|---|
| Year-only **start** Y | The season beginning in August Y (2004 → 2004/05) |
| Year-only **end** Y | The season ending in May Y (2004 → 2003/04) |
| Start and end in the same year, start year-only | The season ending in that year |
| Full dates | Every season whose August–May window overlaps the membership |

A player who qualifies only under the most generous reading of year-only dates is flagged **`season_ambiguous`** (265 study players).

### 3.3 Fetching players from Wikidata
`python/03_fetch_wikidata.py` queried every footballer with a membership at one of the 78 clubs and born 1970 or later. That gave **31,847 memberships for 12,620 players**, with:
- club join and leave dates **and their precision** (year, month or day)
- matches played, where recorded
- birth date, sex, birthplace, birthplace coordinates and country, and position

Results were saved as dated snapshots, so the study can be reproduced even after Wikidata changes.

### 3.4 First eligibility pass (Wikidata only)
`python/04_eligibility.py` applied the season rule:
- **Cohort:** born 1 January 1975 – 31 December 2005
- **Men only:** sex recorded as male
- **Memberships recorded with 0 matches played** were ignored
- **Memberships with no dates at all** counted only if the club was in the top two divisions for the player's whole likely career (ages 17–35), since then any timing would qualify

### 3.5 Validation (200 players)
`python/06_validation_sample.py` drew a seeded random sample: **150 included and 50 excluded** players. `python/08_validate_wikipedia.py` checked each one against the player's **English Wikipedia infobox**, which lists every club spell with its years and **league appearances**:

| Measure | Result |
|---|---|
| **False inclusions:** included, but no league appearance at tier 1–2 | **22 of 118 = 18.6%** |
| False exclusions: excluded, but did play at tier 1–2 | 3 of 44 = 6.8% |
| Premier League flag wrong | 21 of 113 = 18.6% |
| Undecidable (club changed division during the spell, or no article) | 38 of 200 |

Almost every false inclusion was a player **under contract but who never played**, typically an academy player. Examples:
- **Luke Brattan:** Manchester City 2015–2019, 0 league apps
- **Alefe Santos:** Derby County 2014–2017, 0 apps
- **Jason Gilchrist:** Burnley 2013–2016, 0 apps

### 3.6 Tightened rule: appearance evidence required
The work plan's decision point said to tighten the rule if validation errors were high. `python/04b_appearance_evidence.py` re-examined **all ~10,760 candidates**, including those excluded in the first pass, using their Wikipedia infoboxes:

| Evidence level | Meaning | Players |
|---|---|---|
| **Certain** | ≥1 league appearance in a spell at a club that was in the top two divisions in **every** season of that spell | 4,977 |
| **Probable** | League appearances in a spell at a club that was in the top two divisions in only **some** of its seasons (the appearances can't be split by season); or, with no infobox, Wikidata matches played > 0 | 1,604 |
| None | Excluded | 4,180 |

- **Removed:** 984 players the first pass had included.
- **Added back:** 415 players it had excluded.
- In the validation sample, all 22 false inclusions are now excluded and all 3 false exclusions are now included. This is only a consistency check, since it uses the same source as the validation.

**Main analysis = certain + probable. Sensitivity analysis = certain only.**

### 3.7 Birthplaces and country of birth
1. **Precision** (`python/05_geocode_fallback.py`): each birthplace was classified as town, county/region or whole country (e.g. "England"). Only **one** birthplace lacked coordinates, and Nominatim (OpenStreetMap) couldn't resolve it either.
2. **Country of birth** (`R/02_birth_country.R`): each birthplace point was placed in Natural Earth map units, which split the UK into England, Scotland, Wales and Northern Ireland. 6,418 points fell inside a unit, and 148 coastal points were snapped to the nearest unit within 10 km.

### 3.8 Reports
- `python/07_quality_report.py` generates `docs/reports/data_quality_step2.md`.
- Every excluded player is listed with a reason in `exclusion_log.csv`:

| Reason | Players |
|---|---|
| No evidence of a tier 1–2 league appearance | 4,180 |
| Born outside 1975–2005 | 1,695 |
| Not male (women's football) | 160 |
| Sex not recorded | 4 |

---

## 4. Challenges and how they were solved

| # | Challenge | What happened | Solution |
|---|---|---|---|
| 1 | **Missing league seasons** | The proposal expected engsoccerdata to stop in 2016 and planned ~10 seasons of manual work. | The package actually runs to 2024/25 with only 2022/23 missing. The 2 missing seasons came from Wikipedia automatically; no manual compilation was needed. |
| 2 | **Two formats of Wikipedia league table** | Newer pages list clubs as `team_order=…`, older ones as `team1=…`, and some keep the table in a separate template. A hidden editor comment also broke the parser. | The parser handles both formats, follows templates and strips comments. All 10 seasons extracted. |
| 3 | **Wrong club matches** | "Wimbledon" matched AFC Wimbledon instead of the original Wimbledon F.C. "Chester", "Maidstone United", "Accrington" and "Macclesfield" matched newer clubs with the same name. "Aldershot" means two different clubs (Aldershot F.C. to 1992, Aldershot Town 2008–13). | The cross-check against Wikipedia exposed them. 9 manual overrides, including season-specific ones for Aldershot, are documented in `club_qid_overrides.csv`. |
| 4 | **Year-only dates** | 87% of memberships have a year-only start or end. | The season rule was fixed in advance, with unit tests and an ambiguity flag (265 players). |
| 5 | **Women's players included** | Some women's-team memberships are recorded against the men's club in Wikidata (e.g. Manchester City). 160 women's players had got in. Spotted while preparing the validation sample. | Men-only filter on Wikidata's sex field. |
| 6 | **Contracts ≠ appearances** | A Wikidata membership marks a contract. Per-season "members" were about 1.5× real squad usage, and validation found 18.6% false inclusions. | The rule was tightened to require league appearance evidence from Wikipedia infoboxes. |
| 7 | **Undated memberships** | 7.9% of memberships have no dates at all. | They count only when the club was in the top two divisions for the player's whole likely career. Under the final rule, infobox evidence replaces them. |
| 8 | **Coastal birthplaces** | At 1:10m resolution, some coastal towns fall just offshore. | Snapped to the nearest country within 10 km (148 players). |
| 9 | **Slow, rate-limited sources** | Wikidata needed 78 club queries plus player batches; Wikipedia needed ~10,000 articles. | Polite batching (50 articles per request), retries and pauses between requests, and dated snapshots so nothing needs re-downloading. |
| 10 | **Manual validation not available** | The planned hand check against squad lists wasn't going to be done. | Automated validation against Wikipedia infobox appearance counts, with its limits stated (section 5). |

---

## 5. Limitations

1. **Validation isn't fully independent.** Wikipedia and Wikidata are both community-edited and often share editors and sources. The validation compares two largely separate records, but not an official source such as league appearance data.
2. **The final rule relies on Wikipedia infoboxes.** Infobox "caps" are league appearances by convention, but infoboxes can be incomplete, out of date or wrong, especially for lower-profile players.
3. **"Probable" players (24%) can't be confirmed season by season.** When a club was promoted or relegated during a player's spell, the infobox gives one appearance total for the whole spell, so we can't tell whether any appearances came in a top-two-division season. This affects the **Premier League flag** most: among English-born players only 648 of 1,611 Premier League players are "certain". The sensitivity analysis (certain only) addresses this.
4. **Coverage depends on Wikipedia and Wikidata.** Players with no Wikidata record, or no birth date, can't enter the study. Coverage is very good for English league players, but the youngest cohort (born 2003–05) is probably less complete.
5. **Birthplace ≠ where a player grew up.** Wikidata records the place of birth, which may be the hospital town rather than the home town. This is handled in later steps by working at local authority level and coarser.
6. **Birthplace precision.** 46 English-born players have only "England" as their birthplace and 18 only a county. They can't be placed on a local map and are excluded from the spatial analysis, but they remain in the counts.
7. **Conflicting records.** 109 players have more than one birth date in Wikidata and 33 more than one birthplace. The most precise date and the first birthplace with coordinates were used.
8. **Snapshot in time.** Data were retrieved on 2 and 18 November 2026. Wikidata and Wikipedia change constantly, so the dated snapshots are needed to reproduce these exact results.

---

## 6. Deviations from the proposal (v2.1)

| Proposal | What was done | Reason |
|---|---|---|
| Compile 2016/17–2025/26 club divisions by hand | Only 2022/23 and 2025/26 were needed, taken automatically from Wikipedia | engsoccerdata is more up to date than expected |
| Eligibility from Wikidata club memberships (+ matches played where available) | Eligibility needs league appearance evidence (Wikipedia infobox); Wikidata matches played as fallback | Validation found 18.6% false inclusions |
| Manual 200-player check against squad lists | Automated check against Wikipedia infoboxes | Manual check not carried out; limitation stated |
| Ambiguous cases flagged by the season rule | Kept (`season_ambiguous`), plus a new evidence level (certain / probable) | The evidence level captures uncertainty more directly |

These changes should be added to the proposal's methodology (section 6.6) at the next revision.

---

## 7. Implications for the next steps

- **Step 3/4 (areas and expected counts):** use the 3,017 English-born players with town-level birthplaces. Report county-level and country-level birthplaces separately.
- **Step 7 (robustness):** add **"certain evidence only"** to the robustness checks. The "Premier League only" check should be read cautiously because of limitation 3.
- **Optional improvement:** Wikipedia club-season articles list appearances per season and could turn many "probable" players into certain or excluded ones. Worth doing if the certain-only results differ from the main results.

---

## 8. How to reproduce

Inside the app container (`docker compose exec app bash`):

```bash
Rscript R/01_club_tiers_engsoc.R
cd python
python 01_league_tables_wikipedia.py
python 02_club_qids.py
python 03_fetch_wikidata.py          # ~30 min, creates new dated snapshots
python 04_eligibility.py
python 04b_appearance_evidence.py    # ~15 min
python 05_geocode_fallback.py
cd .. && Rscript R/02_birth_country.R && cd python
python 07_quality_report.py
# optional, to redo the validation:
python 06_validation_sample.py && python 08_validate_wikipedia.py
```

Tests: `pytest tests/` (20 tests, all passing).
