-include .env
export

setup-db:
	bash scripts/start-db.sh
	
ingestion:
	uv run main.py