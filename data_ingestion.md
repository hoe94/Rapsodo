# Data Ingestion

Ingestion pipeline that extracts data from Excel sheets transform into CSV file, and ingests it into PostgreSQL.

## Prerequisites

- Python 3.8+
- `uv` package manager installed
- PostgreSQL running
- Environment variables configured (see below)
- Docker Compose

## Environment Variables

Create a `.env` file in the project root with the following variables:

```bash
# Excel Configuration
EXCEL_FILE_PATH=
CSV_FILE_PATH=

# Database Configuration
DB_HOST=
DB_PORT=
DB_NAME=
DB_USER=
DB_PASSWORD=
DB_SCHEMA=
```

**Required Variables:**
- `EXCEL_FILE_PATH`: Path to the Excel file to ingest
- `CSV_FILE_PATH`: Directory to store intermediate CSV files

**Database Variables:**
- `DB_HOST`: PostgreSQL host
- `DB_PORT`: PostgreSQL port
- `DB_NAME`: Database name
- `DB_USER`: Database user
- `DB_PASSWORD`: Database password
- `DB_SCHEMA`: Target schema name

## Setup

### 1. Navigate to the dbt Project Directory**

```bash
cd data-ingestion
```

### 2. Setup Database

Run the database setup script:

```bash
make setup-db
```

Or manually run:

```bash
bash scripts/start-db.sh
```

### 3. Install Dependencies

```bash
pip install -r scripts/requirements.txt
```

Or using uv:

```bash
uv sync
```

## 4. Running the Ingestion

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
- Sheet: "billing_subscriptions" → Table: `raw_rapsodo.billing_subscriptions`
- Sheet: "internal subscriptions" → Table: `raw_rapsodo.internal_subscriptions`

