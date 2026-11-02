"""Environment checks for Step 1.

Usage (inside the app container):  pytest tests/
"""
import importlib
import os

import pytest


@pytest.mark.parametrize("module", ["pandas", "pyarrow", "requests", "SPARQLWrapper", "geopy", "psycopg"])
def test_python_packages_import(module):
    importlib.import_module(module)


def test_postgis_answers():
    import psycopg

    conninfo = (
        f"host={os.environ.get('POSTGRES_HOST', 'db')} "
        f"port={os.environ.get('POSTGRES_PORT', '5432')} "
        f"dbname={os.environ['POSTGRES_DB']} "
        f"user={os.environ['POSTGRES_USER']} "
        f"password={os.environ['POSTGRES_PASSWORD']}"
    )
    with psycopg.connect(conninfo, connect_timeout=10) as conn:
        version = conn.execute("SELECT PostGIS_Version()").fetchone()[0]
        schemas = {r[0] for r in conn.execute("SELECT schema_name FROM information_schema.schemata")}
    assert version.startswith("3.")
    assert "talent" in schemas
