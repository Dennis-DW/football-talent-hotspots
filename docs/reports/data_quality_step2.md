# Data Quality Report — Step 2

*Generated 2026-11-18 by `python/07_quality_report.py`. Source snapshot: `wikidata_memberships_2026-11-02.parquet`.*

## Summary

| Measure | Value |
|---|---|
| Clubs in tier 1–2 at least once, 1992/93–2025/26 | 78 |
| Player memberships fetched (players born 1970+) | 31,847 |
| Distinct players fetched | 12,620 |
| **Study players** (men born 1975–2005 with evidence of ≥1 tier 1–2 league appearance) | **6,581** |
| – certain appearance evidence | 4,977 (75.6%) |
| – probable appearance evidence | 1,604 (24.4%) |
| – season-ambiguous on Wikidata dates (kept, flagged) | 265 |
| Premier League subset (certain + probable) | 4,081 (62.0%) |
| – Premier League, certain only | 2,102 |
| **English-born** | **3,081** (46.8%) |
| English-born with a town/admin-level birthplace (usable for spatial analysis) | 3,035 |
| Study players with birthplace coordinates | 6,566 (99.8%) |

## Validation and eligibility rule

**Validation of the first rule (Wikidata memberships only).** A seeded sample of 200
players (150 included, 50 excluded) was checked against English Wikipedia infoboxes, which
list league appearances per club spell (`python/08_validate_wikipedia.py`,
`data/manual/validation_sample_claude.csv`).

| Measure | Result |
|---|---|
| False-inclusion rate (included, but no tier 1–2 league appearance) | 22/118 = 18.6% |
| False-exclusion rate (excluded, but did play at tier 1–2) | 3/44 = 6.8% |
| Premier League flag wrong | 21/113 = 18.6% |
| Undecidable (club changed division during the spell, or no article) | 38 of 200 |

Almost all false inclusions were players under contract, often academy players, who never
made a league appearance for the club. Because the false-inclusion rate was well above
10%, the eligibility rule was tightened (WORKPLAN decision point,
`python/04b_appearance_evidence.py`):

- **certain**: ≥1 league appearance (infobox caps) in a spell at a club that was tier 1–2 in
  every season of the spell;
- **probable**: league appearances in a spell at a club that was tier 1–2 in only some of
  its seasons (the caps cannot be split by season), or, without a Wikipedia infobox,
  Wikidata matches played > 0 at a club with a dated tier 1–2 season;
- otherwise excluded.

The main analysis uses certain + probable; a sensitivity analysis uses certain only.
Evidence source for study players: {'wikipedia_infobox': 6571, 'wikidata_P1350': 10}.

*Limitation:* Wikipedia and Wikidata are both community-edited, so this check uses a second,
largely separate source rather than a fully independent one. The tightened rule rests on
infobox appearance counts, which by convention are league appearances.

## Membership dates in Wikidata

| Measure | Memberships | Share |
|---|---|---|
| With a start date | 29,276 | 91.9% |
| With an end date | 26,849 | 84.3% |
| With neither (undated) | 2,515 | 7.9% |
| With a year-only start or end | 27,652 | 86.8% |

## Birthplace resolution

| geo_level | geo_source | Players |
|---|---|---|
| admin | wikidata | 77 |
| country | wikidata | 86 |
| no birthplace |  | 14 |
| no coordinates |  | 1 |
| town | wikidata | 6403 |

Country-level birthplaces (e.g. "England") cannot be placed on a local map and are excluded
from the spatial analyses; they remain in the descriptive analysis (RQ4).

## Birth country (top 15)

| Birth country / UK nation | Players |
|---|---|
| England | 3081 |
| France | 355 |
| Scotland | 233 |
| Ireland | 223 |
| Spain | 222 |
| Netherlands | 161 |
| Wales | 119 |
| Brazil | 119 |
| Germany | 99 |
| Portugal | 94 |
| Argentina | 90 |
| Northern Ireland | 87 |
| Denmark | 83 |
| Australia | 79 |
| Italy | 74 |

## Exclusions

| Reason | Players |
|---|---|
| no evidence of a tier 1–2 league appearance | 4180 |
| born outside 1975–2005 | 1695 |
| not male (women's football) | 160 |
| sex not recorded | 4 |

Full list: `data/processed/exclusion_log.csv`.

## Study players per season

Distinct players with a **dated** membership overlapping each season, by tier.

These counts are higher than the number of players who actually appeared in a season
(about 500–550 in the Premier League). A Wikidata membership marks a contract, not an
appearance: loanees remain members of their parent club, and squad players who never
played are included. Player-level eligibility is less affected (a player needs only one
qualifying season); the validation sample measures the remaining false-inclusion rate.

| season | Premier League | Second tier |
|---|---|---|
| 1992/93 | 9 | 5 |
| 1993/94 | 27 | 32 |
| 1994/95 | 65 | 73 |
| 1995/96 | 93 | 127 |
| 1996/97 | 135 | 170 |
| 1997/98 | 191 | 242 |
| 1998/99 | 258 | 302 |
| 1999/00 | 301 | 337 |
| 2000/01 | 326 | 387 |
| 2001/02 | 345 | 444 |
| 2002/03 | 384 | 470 |
| 2003/04 | 423 | 504 |
| 2004/05 | 466 | 528 |
| 2005/06 | 498 | 617 |
| 2006/07 | 537 | 617 |
| 2007/08 | 581 | 697 |
| 2008/09 | 620 | 744 |
| 2009/10 | 639 | 753 |
| 2010/11 | 664 | 799 |
| 2011/12 | 679 | 796 |
| 2012/13 | 680 | 804 |
| 2013/14 | 721 | 868 |
| 2014/15 | 743 | 848 |
| 2015/16 | 783 | 768 |
| 2016/17 | 800 | 756 |
| 2017/18 | 809 | 727 |
| 2018/19 | 830 | 715 |
| 2019/20 | 834 | 732 |
| 2020/21 | 819 | 736 |
| 2021/22 | 839 | 685 |
| 2022/23 | 839 | 689 |
| 2023/24 | 838 | 644 |
| 2024/25 | 798 | 614 |
| 2025/26 | 783 | 585 |

## Matches-played evidence

Study players whose qualifying memberships record matches played (P1350) > 0:
5,130 (78.0%). The rest have no matches-played value in
Wikidata, so their appearance cannot be confirmed from Wikidata alone.

## Next checks

- Manual validation of 200 players: `data/manual/validation_sample.csv`.
- Players with several birth dates in Wikidata: 109; several birthplaces: 33.
