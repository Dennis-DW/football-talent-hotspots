"""Integrity tests for Step 4 outputs (observed / expected counts)."""
from pathlib import Path

import pandas as pd
import pytest

PROCESSED = Path(__file__).resolve().parents[1] / "data" / "processed"
LEVELS = ["lad21", "ttwa", "hex10", "hex20"]

pytestmark = pytest.mark.skipif(not (PROCESSED / "counts_lad21.csv").exists(),
                                reason="Step 4 outputs not built")


@pytest.mark.parametrize("level", LEVELS)
def test_observed_equals_expected_in_total(level):
    c = pd.read_csv(PROCESSED / f"counts_{level}.csv")
    tot = c.groupby("variant")[["O", "E"]].sum()
    assert (abs(tot.O - tot.E) < 1e-6).all()


@pytest.mark.parametrize("level", LEVELS)
def test_births_fully_allocated(level):
    births = pd.read_csv(PROCESSED / "births_lad_year.csv").births_male.sum()
    c = pd.read_csv(PROCESSED / f"counts_{level}.csv")
    allocated = c[c.variant == "main"].births.sum()
    assert abs(allocated - births) / births < 1e-9


@pytest.mark.parametrize("level", LEVELS)
def test_no_negative_or_missing_values(level):
    c = pd.read_csv(PROCESSED / f"counts_{level}.csv")
    assert (c.O >= 0).all() and (c.E >= 0).all()
    assert c[c.E > 0].SR.notna().all()


def test_every_placed_player_has_all_units():
    p = pd.read_csv(PROCESSED / "player_units.csv")
    assert p[["lad21cd", "ttwa", "hex10", "hex20"]].notna().all().all()
    assert p.player_qid.is_unique


def test_london_level_birthplaces_only_used_at_ttwa():
    p = pd.read_csv(PROCESSED / "player_units.csv")
    lad = pd.read_csv(PROCESSED / "counts_lad21.csv")
    ttwa = pd.read_csv(PROCESSED / "counts_ttwa.csv")
    main_lad = lad[lad.variant == "main"].O.sum()
    main_ttwa = ttwa[ttwa.variant == "main"].O.sum()
    assert main_lad == p.fine.sum()
    assert main_ttwa == len(p)
