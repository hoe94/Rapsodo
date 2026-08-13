#!/usr/bin/env python3
"""Ingest an Excel (.xlsx) file into Postgres.

Behavior:
- Each sheet becomes a table (sheet name sanitized).
- Each original column is created as TEXT and allows NULLs.
- Adds metadata columns:
  - dw_id: UUID (generated with uuid.uuid7() when available, else fallback)
  - dw_modified_by: TEXT (default 'job' or provided via --modified-by)
  - dw_modified_timestamp: TIMESTAMPTZ
  - dw_extract_timestamp_myt: TIMESTAMPTZ (time of reading the Excel)
  - dw_source_write_timestamp_myt: TIMESTAMPTZ (time of insert)
  - dw_is_deleted: BOOLEAN (default false)

Usage:
  python scripts/ingest_excel.py path/to/file.xlsx

Environment variables (use .env or system env):
  DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, DB_SCHEMA (optional, default: public)

"""
import argparse
import os
import re
import sys
from datetime import datetime, timezone
import uuid

from dotenv import load_dotenv
import pandas as pd
from sqlalchemy import create_engine, text


def sanitize_identifier(name: str) -> str:
    name = name.strip()
    name = re.sub(r"\s+", "_", name)
    name = re.sub(r"[^0-9a-zA-Z_]+", "", name)
    if not re.match(r"^[a-zA-Z]", name):
        name = f"t_{name}"
    return name.lower()


def uuid7_or_fallback() -> str:
    try:
        u = uuid.uuid7()
    except AttributeError:
        # Python <3.11 fallback; not true uuid7 but still unique
        u = uuid.uuid1()
    return str(u)


def create_table_if_not_exists(conn, schema: str, table: str, columns: list[str]):
    cols_sql = []
    for c in columns:
        cols_sql.append(f'"{c}" TEXT')

    meta_sql = [
        'dw_id UUID PRIMARY KEY',
        "dw_modified_by TEXT DEFAULT 'job'",
        'dw_modified_timestamp TIMESTAMPTZ DEFAULT now()',
        'dw_extract_timestamp_myt TIMESTAMPTZ',
        'dw_source_write_timestamp_myt TIMESTAMPTZ',
        'dw_is_deleted BOOLEAN DEFAULT false',
    ]

    full_cols = cols_sql + meta_sql
    cols_fragment = ',\n    '.join(full_cols)

    create_sql = f"""
    CREATE TABLE IF NOT EXISTS "{schema}"."{table}" (
    {cols_fragment}
    );
    """
    conn.execute(text(create_sql))


def main():
    parser = argparse.ArgumentParser(description="Ingest Excel sheets into Postgres (one sheet = one table)")
    parser.add_argument("xlsx_path", help="Path to .xlsx file")
    parser.add_argument("--modified-by", default="job", help="Value for dw_modified_by")
    parser.add_argument("--schema", default=None, help="DB schema to use (overrides env DB_SCHEMA)")
    args = parser.parse_args()

    load_dotenv()

    DB_HOST = os.getenv("DB_HOST", "localhost")
    DB_PORT = os.getenv("DB_PORT", "5432")
    DB_NAME = os.getenv("DB_NAME")
    DB_USER = os.getenv("DB_USER")
    DB_PASSWORD = os.getenv("DB_PASSWORD")
    DB_SCHEMA = args.schema or os.getenv("DB_SCHEMA", "public")

    if not DB_NAME or not DB_USER or not DB_PASSWORD:
        print("Missing required DB connection environment variables (DB_NAME, DB_USER, DB_PASSWORD).", file=sys.stderr)
        sys.exit(2)

    engine_url = f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    engine = create_engine(engine_url)

    xlsx = args.xlsx_path
    if not os.path.exists(xlsx):
        print(f"Excel file not found: {xlsx}", file=sys.stderr)
        sys.exit(2)

    extract_ts = datetime.now(timezone.utc)

    # Read all sheets
    xl = pd.read_excel(xlsx, sheet_name=None, engine="openpyxl", dtype=object)

    with engine.begin() as conn:
        # Ensure schema exists
        conn.execute(text(f"CREATE SCHEMA IF NOT EXISTS \"{DB_SCHEMA}\""))

        for sheet_name, df in xl.items():
            table = sanitize_identifier(sheet_name)
            # sanitize column names
            orig_cols = list(df.columns)
            cols = [sanitize_identifier(str(c)) for c in orig_cols]

            create_table_if_not_exists(conn, DB_SCHEMA, table, cols)

            # prepare rows for insertion
            insert_cols = cols + [
                'dw_id', 'dw_modified_by', 'dw_modified_timestamp',
                'dw_extract_timestamp_myt', 'dw_source_write_timestamp_myt', 'dw_is_deleted'
            ]

            # Build parameterized insert
            columns_sql = ', '.join([f'"{c}"' for c in insert_cols])
            values_sql = ', '.join([f":{c}" for c in insert_cols])
            insert_sql = text(f"INSERT INTO \"{DB_SCHEMA}\".\"{table}\" ({columns_sql}) VALUES ({values_sql})")

            now_ts = datetime.now(timezone.utc)

            for _, row in df.iterrows():
                data = {}
                for orig, col in zip(orig_cols, cols):
                    val = row.get(orig)
                    if pd.isna(val):
                        data[col] = None
                    else:
                        data[col] = str(val)

                data['dw_id'] = uuid7_or_fallback()
                data['dw_modified_by'] = args.modified_by
                data['dw_modified_timestamp'] = now_ts
                data['dw_extract_timestamp_myt'] = extract_ts
                data['dw_source_write_timestamp_myt'] = now_ts
                data['dw_is_deleted'] = False

                conn.execute(insert_sql, **data)

            print(f"Inserted {len(df)} rows into {DB_SCHEMA}.{table}")


if __name__ == '__main__':
    main()
