# Data Transformation - dbt Setup Guide

This guide walks you through setting up and running the dbt (data build tool) project for data transformation in the Rapsodo pipeline.

## Prerequisites

- Python 3.8+
- `uv` package manager installed
- PostgreSQL running and configured
- Environment variables configured in `.env` file (in the `data-dbt/rapsodo` directory)
- Docker Compose

## Quick Start: Setup & Navigate

**Step 1: Navigate to the dbt Project Directory**

```bash
cd data-dbt/rapsodo
```

This ensures all relative paths in the dbt project are resolved correctly.

**Step 2: Initialize dbt**

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

**Step 3: Load Common Mapping Reference Tables**

Before running the staging models, load the lookup tables used by the transformation logic:

```bash
make common-mapping-rapsodo-seed
```

This command runs:
- `uv run dbt seed --select plan_mapping status_mapping user_dq_issue_category`

It creates and loads the `common_mapping` tables used for:
- plan standardization (`plan_mapping`)
- status standardization (`status_mapping`)
- DQ issue categorization (`user_dq_issue_category`)

## Available Make Commands

Once you're in the `data-dbt/rapsodo` directory, you can run the following commands:

---

### 2. Load Common Mapping Lookup Tables

```bash
make common-mapping-rapsodo-seed
```

**Purpose:** Create and populate the reference tables used by the dbt models for status/plan normalization and DQ tracking.

**What it does:**
- Creates the `common_mapping` schema if needed
- Loads `plan_mapping`
- Loads `status_mapping`
- Loads `user_dq_issue_category`

---

### 3. Level 1 (L1) Data Quality Tests - Raw Layer

```bash
make raw-rapsodo-dbt-l1-test
```

**Purpose:** Run foundational data quality tests on raw source tables

**What it tests:**
The L1 DQ tests validate the integrity of source data by checking:

- **Null Values:** Ensures critical fields are not null and data completeness
- **Uniqueness:** Verifies that primary key and unique identifier fields have no duplicates
- **List of Values Acceptance:** Validates that categorical fields contain only expected values from a predefined list
- **Length of Value:** Checks that string fields conform to expected length constraints

**What it does:**
- Runs quality tests on the `internal_subscriptions` source
- Runs quality tests on the `billing_subscriptions` source
- Validates data integrity from source systems
- Reports any data quality violations

---

### 4. Build Staging Layer Models

```bash
make staging-rapsodo-dbt-run
```

**Purpose:** Transform raw source data into clean, standardized staging layer tables

**What it does:**
- Runs `staging__internal_subscriptions` model
- Runs `staging__billing_subscriptions` model
- Applies cleaning and standardization transformations

---

### 5. Level 2 (L2) Data Quality Tests - Staging Layer

```bash
make staging-rapsodo-dbt-l2-test
```

**Purpose:** Validate data relationships and consistency across staging tables

**What it tests:**
The L2 DQ tests ensure data consistency and integrity across transformed tables:

- **Test subscribers existance** Verifies that both user are tally between `staging__internal_subscriptions` and `staging__billing_subscriptions` are valid
- **Test subscribers status** Ensures all the status are the same between both tables
- **Test time difference** Find out the timestamp difference between bill payments & subscription activation

**What it does:**
- Runs dbt L2 test model to detect the issues
- Reports any data quality violations

---

### 6. Build Core Layer Models

---

```bash
make core-rapsodo-dbt-run
```

**Purpose:** Reconcile two sources table and produce one output row per user

**What it does:**
- Runs `core__cleaned_subscriptions` model
- Prepares data for analytics and reporting

---

## Full Setup Workflow

To set up and run the complete dbt pipeline:

```bash
# 1. Navigate to the dbt project
cd data-dbt/rapsodo

# 2. Setup dbt (install dependencies)
make setup-dbt

# 3. Load common mapping reference tables
make common-mapping-rapsodo-seed

# 4. Test raw layer data sources (L1 DQ)
make raw-rapsodo-dbt-l1-test

# 5. Build staging layer
make staging-rapsodo-dbt-run

# 6. Test staging layer relationships (L2 DQ)
make staging-rapsodo-dbt-l2-test

# 7. Build core layer
make core-rapsodo-dbt-run
```

## Project Structure

```
data-dbt/rapsodo/
├── Makefile                 # Make commands for running dbt tasks
├── dbt_project.yml         # dbt project configuration
├── profiles.yml            # Database connection profiles
├── packages.yml            # dbt package dependencies
├── models/
│   ├── raw/                # Raw source data validation
│   ├── staging/            # Cleaned and standardized data
│   └── core/               # Business-ready data
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

After successfully running the core layer models, your transformed data is ready for:
- Analytics queries
- Dashboard development
- Reporting and insights

For more information on dbt, visit [dbt documentation](https://docs.getdbt.com/).
