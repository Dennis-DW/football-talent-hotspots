"""Season assignment rule (proposal v2.1, section 6.6).

A season is identified by its start year: 2004 means 2004/05. Its playing window is
1 August of the start year to 31 May of the following year. A club membership covers
every season whose playing window overlaps the membership interval.

Wikidata dates carry a precision: 9 = year only, 10 = month, 11 = day.

The rule, fixed before looking at the data:
  * year-only start Y  -> 1 August Y            (2004 -> first season 2004/05)
  * year-only end Y    -> 31 May Y              (2004 -> last season 2003/04)
  * year-only start Y with an end in the same year Y -> 1 January Y
        (the membership is assigned to the season ending in Y)
  * full dates are used as they are; a start in June/July therefore falls in the
    following season, and an end in June/July closes the season that just ended.

The "wide" interpretation is the most generous reading of year-only dates
(start Y -> 1 January Y, end Y -> 31 December Y). A player who is eligible under the
wide reading but not under the rule is flagged as ambiguous.
"""
from __future__ import annotations

import datetime as dt
from dataclasses import dataclass

YEAR, MONTH, DAY = 9, 10, 11


@dataclass(frozen=True)
class WDate:
    """A Wikidata time value: a date plus its precision."""
    date: dt.date
    precision: int

    @property
    def year_only(self) -> bool:
        return self.precision <= YEAR

    @property
    def month_only(self) -> bool:
        return self.precision == MONTH


def season_window(season: int) -> tuple[dt.date, dt.date]:
    return dt.date(season, 8, 1), dt.date(season + 1, 5, 31)


def _resolve_start(start: WDate, end: WDate | None, wide: bool) -> dt.date:
    y = start.date.year
    if start.year_only:
        if wide or (end is not None and end.date.year == y):
            return dt.date(y, 1, 1)
        return dt.date(y, 8, 1)
    if start.month_only:
        return dt.date(y, start.date.month, 1)
    return start.date


def _resolve_end(end: WDate, wide: bool) -> dt.date:
    y = end.date.year
    if end.year_only:
        return dt.date(y, 12, 31) if wide else dt.date(y, 5, 31)
    if end.month_only:
        m = end.date.month
        nxt = dt.date(y + (m == 12), m % 12 + 1, 1)
        return nxt - dt.timedelta(days=1)
    return end.date


def membership_seasons(
    start: WDate | None,
    end: WDate | None,
    *,
    wide: bool = False,
    open_end_season: int | None = None,
) -> list[int]:
    """Seasons (start years) covered by a membership.

    `open_end_season`: last season to assume when there is a start date but no end date
    (the membership is treated as continuing). Returns [] when there is no start date
    and no end date (undated memberships are handled separately).
    If only the end date is known, only the final season is returned.
    """
    if start is None and end is None:
        return []
    if start is None:
        e = _resolve_end(end, wide)
        # Aug–Dec falls in the season starting that year; Jan–Jul closes the previous one
        return [e.year if e.month >= 8 else e.year - 1]
    else:
        s = _resolve_start(start, end, wide)
        if end is not None:
            e = _resolve_end(end, wide)
        elif open_end_season is not None:
            e = season_window(open_end_season)[1]
        else:
            e = s
    if e < s:
        e = s  # inconsistent dates: keep the start point only
    first = s.year if s.month >= 8 else s.year - 1
    last = e.year if e.month >= 8 else e.year - 1
    seasons = []
    for season in range(first, last + 1):
        w0, w1 = season_window(season)
        if s <= w1 and e >= w0:
            seasons.append(season)
    return seasons
