# GSF Database

PostgreSQL federation management database for the Gambia Scrabble Federation.

## Local setup

```bash
# Install dependencies
pip3 install -r requirements.txt

# Copy env file and set password
cp .env.example .env

# Apply schema to local PostgreSQL
psql -U gsf_user -h localhost -d gsf_db -f schema.sql

# Import a TSH tournament
python3 scripts/import_tsh.py --tournament "GSF Nationals 2025" \
  --dir /home/ebrimasaye/Development/TSH/GSF-Nationals-2026/
```

## Cloud migration

Change `DATABASE_URL` in `.env` to your cloud PostgreSQL connection string.
Everything else (API, import scripts) works without any code changes.

Supported cloud targets:
- **Supabase**: `postgresql://postgres:pass@db.xxx.supabase.co:5432/postgres`
- **AWS RDS**: `postgresql://gsf_user:pass@endpoint.rds.amazonaws.com:5432/gsf_db`
- **Neon**: `postgresql://gsf_user:pass@ep-xxx.neon.tech/gsf_db`
- **Railway**: connection string from Railway dashboard

Then run:
```bash
psql $DATABASE_URL -f schema.sql   # create schema on cloud
```
