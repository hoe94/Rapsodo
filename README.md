# Rapsodo - Senior Data Engineer Skills Assessment

This project focuses on the business problem:

> Rapsodo tracks subscriptions in two places: our internal app database, and our payment provider. These two systems don’t always agree — sync delays, provider outages, and a legacy double-write bug have left some records inconsistent. Enclosed within the provided Excel workbook are two exports representing the same underlying subscriptions from these two systems: internal_subscriptions and billing_subscriptions. They use different column names, different status vocabularies, and occasionally disagree with each other. Your task involves reconciling the two sources and identifying where and how they disagree. You may use SQL, Python, or both to complete this task, and your submission should include the accompanying code

## Project summary

This project follows an ELT framework for data ingestion. First, I extract the subscription data from the provided Excel workbook and save the relevant sheets as CSV files. Those CSV files are then ingested into PostgreSQL at the raw layer, preserving the original source structure so the data can be validated and audited without losing traceability. For step-by-step instructions on executing the ingestion pipeline, refer to [data_ingestion.md](data_ingestion.md).

After loading the raw data, I created dbt Level 1 tests to detect data quality issues, such as null values, duplicate records (uniqueness), and values outside the allowed accepted list. Any data quality issues found during this stage are documented in
- [Data quality findings](#data-quality-findings)
, along with notes on what was corrected and where the logic lives in the dbt models.

Finally, I reconcile the two source systems in the core layer to create a trusted source-of-truth view of each subscription. The reconciliation process compares the internal and billing datasets, flags mismatches and duplicates, and produces a unified  dataset that is suitable for downstream analysis and reporting.

For step-by-step instructions on executing the dbt project, refer to [data_transformation.md](data_transformation.md).

## Project navigation
- Data quality summary and coding notes: [Docs/Load_and_Clean_datasets_finding_coding.csv](Docs/Load_and_Clean_datasets_finding_coding.csv)
- Data ingestion steps: [data_ingestion.md](data_ingestion.md)
- Data transformation and dbt workflow: [data-transformation.md](data-transformation.md)


## Data quality findings

#### Problem Statement:
>Load and clean both datasets. If you encounter any data quality issues, briefly summarize them here and comment your code where you handle them

#### Finding:
- [Docs/Load_and_Clean_datasets_finding_coding.csv](Docs/Load_and_Clean_datasets_finding_coding.csv)

The issues covered include:
- column name mismatches between billing and internal subscription datasets
- unclear timestamp field naming
- null handling and value standardization
- plan and status normalization
- duplicate detection and data quality classification

## Recommended workflow

1. Review the DQ findings file in [Docs/Load_and_Clean_datasets_finding_coding.csv](Docs/Load_and_Clean_datasets_finding_coding.csv)
2. Follow the ingestion steps in [data_ingestion.md](data_ingestion.md)
3. Run the transformation pipeline in [data-transformation.md](data-transformation.md)
4. 


