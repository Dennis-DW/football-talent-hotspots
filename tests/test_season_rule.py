"""Tests for the season assignment rule, using the examples in proposal section 6.6."""
import datetime as dt
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "python"))

from season_rule import DAY, MONTH, YEAR, WDate, membership_seasons  # noqa: E402


def y(year):
    return WDate(dt.date(year, 1, 1), YEAR)


def d(year, month, day):
    return WDate(dt.date(year, month, day), DAY)


def m(year, month):
    return WDate(dt.date(year, month, 1), MONTH)


# --- examples written in the proposal -------------------------------------------------

def test_year_only_start_goes_to_season_beginning_that_year():
    # 2004 -> 2004/05 is the first season
    assert membership_seasons(y(2004), y(2006))[0] == 2004


def test_year_only_end_goes_to_season_ending_that_year():
    # 2004 -> 2003/04 is the last season
    assert membership_seasons(y(2001), y(2004))[-1] == 2003


def test_same_year_start_and_end_with_year_only_start():
    # joined and left in 2004, start year-only -> the season ending in 2004
    assert membership_seasons(y(2004), y(2004)) == [2003]
    assert membership_seasons(y(2004), d(2004, 3, 15)) == [2003]


def test_full_dates_use_the_season_containing_them():
    assert membership_seasons(d(2004, 1, 20), d(2004, 5, 1)) == [2003]
    assert membership_seasons(d(2004, 9, 1), d(2005, 5, 30)) == [2004]


def test_summer_start_belongs_to_following_season():
    assert membership_seasons(d(2010, 7, 1), d(2012, 6, 30)) == [2010, 2011]
    assert membership_seasons(d(2010, 6, 15), d(2011, 5, 20)) == [2010]


def test_summer_end_closes_the_season_that_just_ended():
    assert membership_seasons(d(2008, 8, 1), d(2010, 6, 30))[-1] == 2009


# --- other behaviour --------------------------------------------------------------------

def test_wide_reading_adds_the_neighbouring_seasons():
    assert membership_seasons(y(2004), y(2006), wide=True) == [2003, 2004, 2005, 2006]
    assert membership_seasons(y(2004), y(2006)) == [2004, 2005]


def test_open_end_continues_to_given_season():
    assert membership_seasons(d(2023, 7, 1), None, open_end_season=2025) == [2023, 2024, 2025]


def test_start_without_end_or_open_end_is_one_season():
    assert membership_seasons(d(2023, 1, 10), None) == [2022]


def test_end_only_returns_final_season():
    assert membership_seasons(None, d(2015, 5, 30)) == [2014]
    assert membership_seasons(None, d(2015, 10, 1)) == [2015]
    assert membership_seasons(None, y(2015)) == [2014]
    assert membership_seasons(None, y(2015), wide=True) == [2015]


def test_undated_returns_nothing():
    assert membership_seasons(None, None) == []


def test_month_precision():
    # joined "January 2004", left "May 2004" -> 2003/04 only
    assert membership_seasons(m(2004, 1), m(2004, 5)) == [2003]
    # left "June 2010" -> last season 2009/10
    assert membership_seasons(m(2008, 8), m(2010, 6))[-1] == 2009


def test_inconsistent_dates_keep_start_point():
    assert membership_seasons(d(2010, 9, 1), d(2009, 9, 1)) == [2010]
