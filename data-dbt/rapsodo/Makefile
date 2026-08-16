include .env
export

setup-dbt:
	uv run dbt deps
	uv run dbt debug

raw-rapsodo-dbt-l1-test:
	uv run dbt test --select source:internal_subscriptions source:billing_subscriptions

staging-rapsodo-dbt-run:
	uv run dbt run --select=staging__internal_subscriptions.sql staging__billing_subscriptions.sql

staging-rapsodo-dbt-l2-test:
	uv run dbt test --models tests/staging
	
core-rapsodo-dbt-run:
	uv run dbt run --select=core__cleaned_subscriptions.sql --full-refresh