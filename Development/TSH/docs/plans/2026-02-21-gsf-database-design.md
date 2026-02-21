# GSF Database Design Document
Date: 2026-02-21

## Overview
A PostgreSQL federation management database (`gsf_db`) on localhost, covering every aspect of TSH tournament data. A Python/Flask API serves the data as JSON. Three new portal pages (`/members`, `/rankings`, `/history`) read from the API.

## Architecture

```
TSH flat files
     │
     └─► import_tsh.py ──► PostgreSQL :5432 (gsf_db)
                                   │
                           Flask API :5000
                                   │
                           Apache2 :80
                           ├── /api/*      → Flask API (proxy)
                           ├── /members    → member directory page
                           ├── /rankings   → national rankings page
                           ├── /history    → tournament archive page
                           └── /tournament → TSH live server :7779
```

## Tech Stack
- **PostgreSQL 14+** — database engine
- **Python 3 / Flask** — API layer
- **psycopg2** — Python PostgreSQL driver
- **BeautifulSoup4** — parse TSH-generated HTML for import
- **Plain HTML/CSS/JS** — portal pages (same stack as landing page)

## Database Schema (15 tables)

### Core tables

**members** — all registered GSF players
```sql
id SERIAL PRIMARY KEY,
name VARCHAR(100) NOT NULL,
region VARCHAR(50),
email VARCHAR(100),
phone VARCHAR(30),
status VARCHAR(20) DEFAULT 'active',  -- active, inactive, junior
photo_url VARCHAR(255),
joined_date DATE,
notes TEXT,
created_at TIMESTAMPTZ DEFAULT now()
```

**rating_systems** — supported rating systems
```sql
id SERIAL PRIMARY KEY,
code VARCHAR(20) UNIQUE NOT NULL,  -- wespa, nsa, thai, pak, nor, ken
name VARCHAR(50) NOT NULL
```

**member_ratings** — rating per player per system over time
```sql
id SERIAL PRIMARY KEY,
member_id INT REFERENCES members(id),
system_id INT REFERENCES rating_systems(id),
rating INT NOT NULL,
effective_date DATE NOT NULL,
source VARCHAR(50)  -- 'tournament', 'import', 'manual'
```

**tournaments**
```sql
id SERIAL PRIMARY KEY,
name VARCHAR(100) NOT NULL,
date_start DATE,
date_end DATE,
location VARCHAR(100),
max_rounds INT,
format VARCHAR(50),   -- swiss, roundrobin, bracket, koth
realm VARCHAR(20),    -- nsa, wespa, thai, absp
status VARCHAR(20) DEFAULT 'upcoming',  -- upcoming, active, completed
notes TEXT,
created_at TIMESTAMPTZ DEFAULT now()
```

**divisions**
```sql
id SERIAL PRIMARY KEY,
tournament_id INT REFERENCES tournaments(id),
name VARCHAR(10) NOT NULL,    -- A, B, C
max_rounds INT,
pairing_strategy VARCHAR(50)  -- swiss, koth, roundrobin
```

**tournament_entries** — registration and seeding
```sql
id SERIAL PRIMARY KEY,
tournament_id INT REFERENCES tournaments(id),
member_id INT REFERENCES members(id),
division_id INT REFERENCES divisions(id),
player_number INT,
seed_rating INT,
paid BOOLEAN DEFAULT false,
confirmed BOOLEAN DEFAULT false,
registered_at TIMESTAMPTZ DEFAULT now()
```

### Tournament data tables

**pairings** — round-by-round matchups
```sql
id SERIAL PRIMARY KEY,
division_id INT REFERENCES divisions(id),
round INT NOT NULL,
board INT,
player1_id INT REFERENCES members(id),
player2_id INT REFERENCES members(id),  -- NULL = bye
first_player_id INT REFERENCES members(id)
```

**games** — scores for each pairing
```sql
id SERIAL PRIMARY KEY,
pairing_id INT REFERENCES pairings(id),
score1 INT,
score2 INT,
confirmed BOOLEAN DEFAULT false
```

**standings** — snapshot after each round
```sql
id SERIAL PRIMARY KEY,
division_id INT REFERENCES divisions(id),
member_id INT REFERENCES members(id),
round INT NOT NULL,
wins NUMERIC(4,1),
losses NUMERIC(4,1),
spread INT,
rating INT,
rank INT
```

### Team & prizes

**teams**
```sql
id SERIAL PRIMARY KEY,
tournament_id INT REFERENCES tournaments(id),
name VARCHAR(100) NOT NULL
```

**team_members**
```sql
team_id INT REFERENCES teams(id),
member_id INT REFERENCES members(id),
tournament_id INT REFERENCES tournaments(id),
PRIMARY KEY (team_id, member_id)
```

**prizes**
```sql
id SERIAL PRIMARY KEY,
tournament_id INT REFERENCES tournaments(id),
member_id INT REFERENCES members(id),
prize_name VARCHAR(100),
amount NUMERIC(10,2),
currency VARCHAR(10) DEFAULT 'GMD'
```

**tsh_import_log** — audit trail
```sql
id SERIAL PRIMARY KEY,
tournament_id INT REFERENCES tournaments(id),
imported_at TIMESTAMPTZ DEFAULT now(),
source_file VARCHAR(255),
rows_affected INT,
notes TEXT
```

## API Endpoints (Flask :5000)

```
GET /api/members                    all active members + current rating
GET /api/members/:id                full profile + rating history + career
GET /api/rankings                   national rankings sorted by rating
GET /api/rankings?system=wespa      filter by rating system
GET /api/tournaments                all tournaments (past + upcoming)
GET /api/tournaments/:id            tournament detail + final standings
GET /api/tournaments/:id/results    round-by-round results
GET /api/history/:member_id         full career history for one player
```

## Portal Pages

- `/members` — searchable card grid, name/rating/region/photo, click → full profile
- `/rankings` — table filterable by rating system, rank/name/rating/W-L/last tournament
- `/history` — timeline of all tournaments, click → full results with pairings

## Import Script

`scripts/import_tsh.py` reads after each tournament:
- `<division>.t` → members, seed ratings, results
- `config.tsh` → tournament metadata
- `html/` → standings snapshots, pairings (parsed from TSH HTML)

Usage:
```bash
python3 scripts/import_tsh.py \
  --tournament "GSF Nationals 2025" \
  --dir Development/TSH/GSF-Nationals-2026/
```

## Files to Create

```
Development/TSH/
  database/
    schema.sql              -- full PostgreSQL schema + seed data
    scripts/
      import_tsh.py         -- TSH → DB import script
      seed_ratings.py       -- seed rating_systems table
  api/
    app.py                  -- Flask API
    requirements.txt        -- psycopg2, flask, python-dotenv
    .env.example            -- DB connection string template
  /var/www/gsf/
    members.html            -- /members portal page
    rankings.html           -- /rankings portal page
    history.html            -- /history portal page
  /etc/apache2/sites-available/gsf.conf   -- add /api proxy
```
