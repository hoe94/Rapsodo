#!/usr/bin/env python3
"""
Fast Excel Ingestion Script (Excel -> Staging CSV -> PostgreSQL COPY)
"""

import os
import re
import sys
import tempfile
from datetime import datetime, timezone, timedelta
import uuid

import pandas as pd
from sqlalchemy import create_engine, text

excel_file_path = os.getenv("EXCEL_FILE_PATH")
excel_sheets = os.getenv("EXCEL_SHEET")
csv_file_path = os.getenv("CSV_FILE_PATH")

# Database configuration
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "postgres")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_SCHEMA = os.getenv("DB_SCHEMA", "staging")

# Create SQLAlchemy engine
db_url = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
engine = create_engine(db_url)

def sanitize_identifier(name: str) -> str:
    name = str(name).strip()
    name = re.sub(r"\s+", "_", name)
    name = re.sub(r"[^0-9a-zA-Z_]+", "", name)
    if not re.match(r"^[a-zA-Z]", name):
        name = f"t_{name}"
    return name.lower()


def uuid7_or_fallback() -> str:
    try:
        return str(uuid.uuid7())
    except AttributeError:
        return str(uuid.uuid1())


def export_sheet_to_csv(df: pd.DataFrame, sheet_name:str):
    temp_csv = os.path.join(csv_file_path, f"{sheet_name}.csv")
    df.to_csv(temp_csv, index=False, na_rep="")
    print(f"Exported sheet '{sheet_name}' ({len(df)} rows) to CSV: {temp_csv}")

    return temp_csv


def create_schema_if_not_exists(schema_name: str):
    """Create schema in Postgres if it doesn't exist."""
    try:
        with engine.connect() as conn:
            conn.execute(text(f"CREATE SCHEMA IF NOT EXISTS \"{schema_name}\""))
            conn.commit()
            print(f"Schema '{schema_name}' is ready.")
    except Exception as e:
        print(f"Error creating schema '{schema_name}': {e}", file=sys.stderr)
        raise


def ingest_csv_via_copy(df: pd.DataFrame, schema_name: str, table_name: str) -> None:
    """
    Ingest DataFrame into PostgreSQL using pandas.to_sql().
    
    Args:
        df: DataFrame to ingest
        schema_name: Target schema name
        table_name: Target table name
    """
    try:
        start_time = datetime.now()
        row_count = len(df)
        
        # Use pandas to_sql with SQLAlchemy engine
        df.to_sql(
            table_name,
            engine,
            schema=schema_name,
            if_exists='replace',  # or 'append' to add to existing table
            index=False,
            method='multi'  # For better performance
        )
        
        elapsed = (datetime.now() - start_time).total_seconds()
        print(f"Ingested {row_count} rows into {schema_name}.{table_name} in {elapsed:.4f} seconds.")
        
    except Exception as e:
        print(f"Error ingesting DataFrame into {schema_name}.{table_name}: {e}", file=sys.stderr)
        raise

def main():
    if not os.path.exists(excel_file_path):
        print(f"Excel file not found: {excel_file_path}", file=sys.stderr)
        sys.exit(2)

    excel_sheets = ["internal_subscriptions", "billing_subscriptions"]
    extract_ts = datetime.now(timezone(timedelta(hours=8))).isoformat()

    xl = pd.read_excel(excel_file_path, sheet_name=excel_sheets, engine="openpyxl", dtype=object)
    for sheet_name in excel_sheets:
        # 1. Save DataFrame to intermediate CSV file

        if sheet_name not in xl:
            print(f"Warning: sheet '{sheet_name}' not found in Excel file. Skipping.")
            continue

        df = xl[sheet_name]
        orig_cols = list(df.columns)
        cols = [sanitize_identifier(str(c)) for c in orig_cols]
        df.columns = cols
        temp_csv = export_sheet_to_csv(df, sheet_name)

        csv_df = pd.read_csv(temp_csv)

        # 2. Add metadata columns for dataframe
        gmt_plus_8 = datetime.now(timezone(timedelta(hours=8)))
        now_ts = gmt_plus_8.isoformat()
        csv_df['dw_id'] = [uuid7_or_fallback() for _ in range(len(df))]
        csv_df['dw_modified_by'] = "job"
        csv_df['dw_modified_timestamp_myt'] = now_ts
        csv_df['dw_extract_timestamp_myt'] = extract_ts
        csv_df['dw_source_write_timestamp_myt'] = now_ts
        csv_df['dw_is_deleted'] = False

        # 3. Create schema in Postgres if it doesn't exist
        create_schema_if_not_exists(DB_SCHEMA)

        # 4. Ingest into Postgres via native COPY
        sanitized_table_name = sanitize_identifier(sheet_name)
        ingest_csv_via_copy(csv_df, DB_SCHEMA, sanitized_table_name)

        # Clean up temp CSV file
        if os.path.exists(temp_csv):
            os.remove(temp_csv)
            print(f"Cleaned up: {temp_csv}")


if __name__ == "__main__":
    main()