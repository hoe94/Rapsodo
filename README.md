# Rapsodo - Senior Data Engineer Skills Assessment

This project focuses on the business problem:

> Load and clean both datasets. If you encounter any data quality issues, briefly summarize them here and comment your code where you handle them.

The workflow loads raw subscription data, standardizes column names and values, handles duplicates and nulls, and builds the dbt transformation pipeline for downstream reconciliation and analysis.

## Project navigation
- Data quality summary and coding notes: [Docs/Load_and_Clean_datasets_finding_coding.csv](Docs/Load_and_Clean_datasets_finding_coding.csv)
- Data ingestion steps: [data_ingestion.md](data_ingestion.md)
- Data transformation and dbt workflow: [data-transformation.md](data-transformation.md)


## Data quality findings

The project includes a summary of the issues identified while cleaning both datasets, along with the corresponding dbt model files that handle each fix. This summary is stored here:

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


