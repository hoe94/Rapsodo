# Data Transformation - dbt Setup Guide

This guide walks you through setting up and running the dbt (data build tool) project for data transformation in the Rapsodo pipeline.

## Prerequisites

- Python 3.8+
- `uv` package manager installed
- PostgreSQL running and configured
- Environment variables configured in `.env` file (in the `data-dbt/rapsodo` directory)
- Docker Compose

## Quick Start

### Step 1: Navigate to the dbt Project Directory

**Always run this first before executing any dbt or make commands:**

```bash
cd data-dbt/rapsodo
```

This ensures all relative paths in the dbt project are resolved correctly.

### Step 2: Setup dbt

Initialize the dbt project by running:

```bash
make setup-dbt
```

This command performs:
- `uv run dbt deps`: Installs dbt dependencies defined in `packages.yml`
- `uv run dbt debug`: Validates your dbt configuration and database connection

**Expected Output:**
- All dependencies installed successfully
- Connection to PostgreSQL database confirmed

## Available Make Commands

Once you're in the `data-dbt/rapsodo` directory, you can run the following commands:

### 1. Setup dbt

```bash
cd data-dbt/rapsodo && make setup-dbt
```

**Purpose:** Install dependencies and validate the dbt configuration

**What it does:**
- Downloads and installs dbt packages (e.g., `dbt_date`, `dbt_expectations`)
- Tests the connection to your PostgreSQL database
- Validates profiles and project configuration

---

### 2. Test Bronze Layer Sources

```bash
cd data-dbt/rapsodo && make bronze-rapsodo-dbt-test
```

**Purpose:** Run data quality tests on source tables

**What it does:**
- Tests the `internal_subscriptions` source
- Tests the `billing_subscriptions` source
- Validates data integrity from source systems

---

### 3. Build Silver Layer Models

```bash
cd data-dbt/rapsodo && make silver-rapsodo-dbt-run
```

**Purpose:** Transform raw source data into clean, standardized silver layer tables

**What it does:**
- Runs `silver__internal_subscriptions` model
- Runs `silver__billing_subscriptions` model
- Applies cleaning and standardization transformations

---

### 4. Build Gold Layer Models

```bash
cd data-dbt/rapsodo && make gold-rapsodo-dbt-run
```

**Purpose:** Create business-ready dimensional and fact tables

**What it does:**
- Runs `gold__cleaned_subscriptions` model
- Prepares data for analytics and reporting

---

## Full Setup Workflow

To set up and run the complete dbt pipeline:

```bash
# 1. Navigate to the dbt project
cd data-dbt/rapsodo

# 2. Setup dbt (install dependencies)
make setup-dbt

# 3. Test data sources
make bronze-rapsodo-dbt-test

# 4. Build silver layer
make silver-rapsodo-dbt-run

# 5. Build gold layer
make gold-rapsodo-dbt-run
```

## Project Structure

```
data-dbt/rapsodo/
├── Makefile                 # Make commands for running dbt tasks
├── dbt_project.yml         # dbt project configuration
├── profiles.yml            # Database connection profiles
├── packages.yml            # dbt package dependencies
├── models/
│   ├── bronze/             # Source data validation
│   ├── silver/             # Cleaned and standardized data
│   └── gold/               # Business-ready data
├── macros/                 # Custom dbt macros
├── tests/                  # Custom tests
├── snapshots/              # Slowly changing dimensions
├── seeds/                  # Static data files
└── target/                 # Compiled dbt artifacts
```

## Environment Configuration

Before running dbt commands, ensure your `.env` file in the `data-dbt/rapsodo` directory includes:

```bash
# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=rapsodo_db
DB_USER=your_user
DB_PASSWORD=your_password
DB_SCHEMA=dbt_schema
```

## Troubleshooting

### Issue: "dbt command not found"
**Solution:** Ensure you've run `make setup-dbt` to install dbt dependencies via `uv`.

### Issue: "Database connection failed"
**Solution:** Verify your PostgreSQL server is running and credentials in `.env` are correct. Run `make setup-dbt` to test the connection.

### Issue: "Module not found" when running models
**Solution:** Run `make setup-dbt` again to ensure all dbt packages are properly installed.

## Next Steps

After successfully running the gold layer models, your transformed data is ready for:
- Analytics queries
- Dashboard development
- Reporting and insights

For more information on dbt, visit [dbt documentation](https://docs.getdbt.com/).
