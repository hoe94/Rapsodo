include .env
export

setup-dbt:
	uv run dbt deps
	uv run dbt debug

bronze-rapsodo-dbt-test:
	uv run dbt test --select source:internal_subscriptions
	uv run dbt test --select source:billing_subscriptions

silver-rapsodo-dbt-run:
	uv run dbt run --select=silver__internal_subscriptions.sql
	uv run dbt run --select=silver__billing_subscriptions.sql

gold-rapsodo-dbt-run:
	uv run dbt run --select=gold__cleaned_subscriptions.sql