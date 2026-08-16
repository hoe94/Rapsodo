# Rapsodo_Interview

Fast Excel Ingestion Script that extracts data from Excel sheets, transforms it, and ingests it into PostgreSQL.

## Prerequisites

- Python 3.8+
- PostgreSQL running
- Environment variables configured (see below)

## Environment Variables

Create a `.env` file in the project root with the following variables:

```bash
# Excel Configuration
EXCEL_FILE_PATH=path/to/your/excel/file.xlsx
EXCEL_SHEET=["sheet_name1", "sheet_name2"]  # JSON array format
CSV_FILE_PATH=./CSV

# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=postgres
DB_USER=postgres
DB_PASSWORD=your_password
DB_SCHEMA=staging
```

**Required Variables:**
- `EXCEL_FILE_PATH`: Path to the Excel file to ingest
- `EXCEL_SHEET`: Sheet names to extract (JSON array format)
- `CSV_FILE_PATH`: Directory to store intermediate CSV files

**Database Variables:**
- `DB_HOST`: PostgreSQL host (default: localhost)
- `DB_PORT`: PostgreSQL port (default: 5432)
- `DB_NAME`: Database name (default: postgres)
- `DB_USER`: Database user (default: postgres)
- `DB_PASSWORD`: Database password (default: empty)
- `DB_SCHEMA`: Target schema name (default: staging)

## Setup

### 1. Setup Database

Run the database setup script:

```bash
make setup-db
```

Or manually run:

```bash
bash scripts/start-db.sh
```

### 2. Install Dependencies

```bash
pip install -r scripts/requirements.txt
```

Or using uv:

```bash
uv sync
```

## Running the Ingestion

Execute the ingestion pipeline:

```bash
make ingestion
```

Or run directly:

```bash
python main.py
```

## What the Script Does

1. **Reads Excel File**: Loads specified sheets from the Excel file
2. **Sanitizes Column Names**: Converts column names to valid PostgreSQL identifiers
3. **Exports to CSV**: Saves intermediate CSV files to `CSV_FILE_PATH`
4. **Adds Metadata Columns**: Injects data warehouse metadata:
   - `dw_id`: Unique identifier (UUID v7 or v1)
   - `dw_modified_by`: Set to "job"
   - `dw_modified_timestamp_myt`: Modification timestamp (GMT+8)
   - `dw_extract_timestamp_myt`: Extract timestamp (GMT+8)
   - `dw_source_write_timestamp_myt`: Source write timestamp (GMT+8)
   - `dw_is_deleted`: Boolean flag (default: false)
5. **Creates Schema**: Creates the target schema in PostgreSQL if it doesn't exist
6. **Ingests Data**: Uses pandas `to_sql()` to insert data into PostgreSQL
7. **Cleans Up**: Removes temporary CSV files

## Output

Ingested data is stored in PostgreSQL at:

```
{DB_SCHEMA}.{sanitized_sheet_name}
```

Example:
- Sheet: "billing_subscriptions" → Table: `billing_subscriptions`
- Sheet: "internal subscriptions" → Table: `internal_subscriptions`


uv run dbt deps
uv run dbt debug
uv run dbt test --select source:internal_subscriptions
uv run dbt test --select source:billing_subscriptions
uv run dbt run --select=silver__internal_subscriptions.sql
uv run dbt run --select=silver__billing_subscriptions.sql
uv run dbt run --select=cleaned_subscriptions.sql
