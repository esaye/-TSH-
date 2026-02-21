# GSF Database Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a PostgreSQL federation database, Flask JSON API, TSH import script, and three new portal pages (members, rankings, history) — all cloud-migration-ready via DATABASE_URL env var and Alembic migrations.

**Architecture:** PostgreSQL on localhost holds 15 tables covering every TSH entity. A Flask API on :5000 serves JSON. Apache proxies `/api/*` to Flask. Three static portal HTML pages fetch from the API. Alembic handles schema versioning so the DB can move to any cloud PostgreSQL with zero code changes.

**Tech Stack:** PostgreSQL 16, Python 3 / Flask, psycopg2-binary, Alembic, python-dotenv, BeautifulSoup4, Apache2 mod_proxy

---

### Task 1: Install PostgreSQL and create database

**Files:**
- Create: `Development/TSH/database/.env.example`

**Step 1: Install PostgreSQL**
```bash
sudo apt-get update && sudo apt-get install -y postgresql postgresql-contrib
sudo systemctl enable postgresql
sudo systemctl start postgresql
```
Expected: `postgresql.service` active (running)

**Step 2: Create database user and database**
```bash
sudo -u postgres psql << 'EOF'
CREATE USER gsf_user WITH PASSWORD 'gsf_secure_2025';
CREATE DATABASE gsf_db OWNER gsf_user;
GRANT ALL PRIVILEGES ON DATABASE gsf_db TO gsf_user;
EOF
```
Expected: `CREATE ROLE`, `CREATE DATABASE`, `GRANT`

**Step 3: Verify connection**
```bash
psql -U gsf_user -h localhost -d gsf_db -c "SELECT version();"
```
Expected: PostgreSQL version string

**Step 4: Create .env.example**

Create `Development/TSH/database/.env.example`:
```
# Copy to .env and fill in values
# For local PostgreSQL:
DATABASE_URL=postgresql://gsf_user:gsf_secure_2025@localhost:5432/gsf_db

# For cloud migration, replace with:
# DATABASE_URL=postgresql://user:pass@host:5432/gsf_db
# e.g. Supabase: postgresql://postgres:pass@db.xxxx.supabase.co:5432/postgres
# e.g. AWS RDS:  postgresql://gsf_user:pass@rds-endpoint.amazonaws.com:5432/gsf_db

FLASK_ENV=development
FLASK_PORT=5000
```

**Step 5: Create actual .env**
```bash
cp Development/TSH/database/.env.example Development/TSH/database/.env
```
Edit `.env` and set the password to `gsf_secure_2025`.

**Step 6: Commit**
```bash
git add Development/TSH/database/.env.example
git commit -m "feat: add PostgreSQL setup and .env.example"
```

---

### Task 2: Install Python dependencies and set up Alembic

**Files:**
- Create: `Development/TSH/database/requirements.txt`
- Create: `Development/TSH/database/alembic.ini`
- Create: `Development/TSH/database/alembic/env.py`

**Step 1: Install Python packages**
```bash
pip3 install flask psycopg2-binary alembic python-dotenv beautifulsoup4 flask-cors
```
Expected: Successfully installed all packages

**Step 2: Create requirements.txt**

Create `Development/TSH/database/requirements.txt`:
```
flask==3.0.0
psycopg2-binary==2.9.9
alembic==1.13.1
python-dotenv==1.0.0
beautifulsoup4==4.12.3
flask-cors==4.0.0
```

**Step 3: Initialise Alembic**
```bash
cd /home/ebrimasaye/Development/TSH/database
alembic init alembic
```
Expected: Creates `alembic/` directory and `alembic.ini`

**Step 4: Update alembic.ini to use DATABASE_URL from .env**

Edit `Development/TSH/database/alembic.ini` — find and replace:
```ini
sqlalchemy.url = driver://user:pass@localhost/dbname
```
with:
```ini
sqlalchemy.url =
```
(We'll load it dynamically from env in env.py)

**Step 5: Update alembic/env.py**

Replace the contents of `Development/TSH/database/alembic/env.py`:
```python
import os
from logging.config import fileConfig
from sqlalchemy import engine_from_config, pool
from alembic import context
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), '..', '.env'))

config = context.config
config.set_main_option('sqlalchemy.url', os.environ['DATABASE_URL'])

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = None

def run_migrations_offline():
    url = config.get_main_option("sqlalchemy.url")
    context.configure(url=url, target_metadata=target_metadata,
                      literal_binds=True, dialect_opts={"paramstyle": "named"})
    with context.begin_transaction():
        context.run_migrations()

def run_migrations_online():
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
```

**Step 6: Commit**
```bash
git add Development/TSH/database/requirements.txt Development/TSH/database/alembic.ini Development/TSH/database/alembic/
git commit -m "feat: add Alembic migration setup"
```

---

### Task 3: Create the full database schema

**Files:**
- Create: `Development/TSH/database/schema.sql`
- Create: `Development/TSH/database/alembic/versions/0001_initial_schema.py`

**Step 1: Write schema.sql**

Create `Development/TSH/database/schema.sql`:
```sql
-- GSF Federation Database Schema
-- Cloud-portable: works with any PostgreSQL instance

CREATE TABLE IF NOT EXISTS rating_systems (
    id   SERIAL PRIMARY KEY,
    code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(50) NOT NULL
);

CREATE TABLE IF NOT EXISTS members (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    region      VARCHAR(50),
    email       VARCHAR(100),
    phone       VARCHAR(30),
    status      VARCHAR(20) NOT NULL DEFAULT 'active',
    photo_url   VARCHAR(255),
    joined_date DATE,
    notes       TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT members_status_chk CHECK (status IN ('active','inactive','junior'))
);

CREATE TABLE IF NOT EXISTS member_ratings (
    id             SERIAL PRIMARY KEY,
    member_id      INT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    system_id      INT NOT NULL REFERENCES rating_systems(id),
    rating         INT NOT NULL,
    effective_date DATE NOT NULL,
    source         VARCHAR(50) DEFAULT 'import',
    UNIQUE (member_id, system_id, effective_date)
);

CREATE TABLE IF NOT EXISTS tournaments (
    id         SERIAL PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    date_start DATE,
    date_end   DATE,
    location   VARCHAR(100),
    max_rounds INT,
    format     VARCHAR(50),
    realm      VARCHAR(20),
    status     VARCHAR(20) NOT NULL DEFAULT 'upcoming',
    notes      TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT tournaments_status_chk CHECK (status IN ('upcoming','active','completed'))
);

CREATE TABLE IF NOT EXISTS divisions (
    id               SERIAL PRIMARY KEY,
    tournament_id    INT NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    name             VARCHAR(10) NOT NULL,
    max_rounds       INT,
    pairing_strategy VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS tournament_entries (
    id            SERIAL PRIMARY KEY,
    tournament_id INT NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    member_id     INT NOT NULL REFERENCES members(id),
    division_id   INT REFERENCES divisions(id),
    player_number INT,
    seed_rating   INT,
    paid          BOOLEAN NOT NULL DEFAULT false,
    confirmed     BOOLEAN NOT NULL DEFAULT false,
    registered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tournament_id, member_id)
);

CREATE TABLE IF NOT EXISTS pairings (
    id              SERIAL PRIMARY KEY,
    division_id     INT NOT NULL REFERENCES divisions(id) ON DELETE CASCADE,
    round           INT NOT NULL,
    board           INT,
    player1_id      INT NOT NULL REFERENCES members(id),
    player2_id      INT REFERENCES members(id),
    first_player_id INT REFERENCES members(id),
    UNIQUE (division_id, round, board)
);

CREATE TABLE IF NOT EXISTS games (
    id         SERIAL PRIMARY KEY,
    pairing_id INT NOT NULL REFERENCES pairings(id) ON DELETE CASCADE,
    score1     INT,
    score2     INT,
    confirmed  BOOLEAN NOT NULL DEFAULT false,
    UNIQUE (pairing_id)
);

CREATE TABLE IF NOT EXISTS standings (
    id          SERIAL PRIMARY KEY,
    division_id INT NOT NULL REFERENCES divisions(id) ON DELETE CASCADE,
    member_id   INT NOT NULL REFERENCES members(id),
    round       INT NOT NULL,
    wins        NUMERIC(4,1) NOT NULL DEFAULT 0,
    losses      NUMERIC(4,1) NOT NULL DEFAULT 0,
    spread      INT NOT NULL DEFAULT 0,
    rating      INT,
    rank        INT,
    UNIQUE (division_id, member_id, round)
);

CREATE TABLE IF NOT EXISTS teams (
    id            SERIAL PRIMARY KEY,
    tournament_id INT NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    name          VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS team_members (
    team_id       INT NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    member_id     INT NOT NULL REFERENCES members(id),
    tournament_id INT NOT NULL REFERENCES tournaments(id),
    PRIMARY KEY (team_id, member_id)
);

CREATE TABLE IF NOT EXISTS prizes (
    id            SERIAL PRIMARY KEY,
    tournament_id INT NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    member_id     INT NOT NULL REFERENCES members(id),
    prize_name    VARCHAR(100) NOT NULL,
    amount        NUMERIC(10,2),
    currency      VARCHAR(10) NOT NULL DEFAULT 'GMD'
);

CREATE TABLE IF NOT EXISTS tsh_import_log (
    id            SERIAL PRIMARY KEY,
    tournament_id INT REFERENCES tournaments(id),
    imported_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    source_file   VARCHAR(255),
    rows_affected INT,
    notes         TEXT
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_member_ratings_member ON member_ratings(member_id);
CREATE INDEX IF NOT EXISTS idx_entries_tournament    ON tournament_entries(tournament_id);
CREATE INDEX IF NOT EXISTS idx_pairings_division     ON pairings(division_id, round);
CREATE INDEX IF NOT EXISTS idx_standings_division    ON standings(division_id, round);
CREATE INDEX IF NOT EXISTS idx_standings_member      ON standings(member_id);

-- Seed rating systems
INSERT INTO rating_systems (code, name) VALUES
    ('wespa', 'WESPA'),
    ('nsa',   'NSA'),
    ('thai',  'Thai Crossword'),
    ('pak',   'Pakistan'),
    ('nor',   'Norway'),
    ('ken',   'Kenya')
ON CONFLICT (code) DO NOTHING;
```

**Step 2: Apply schema**
```bash
psql -U gsf_user -h localhost -d gsf_db -f /home/ebrimasaye/Development/TSH/database/schema.sql
```
Expected: `CREATE TABLE` × 12, `CREATE INDEX` × 5, `INSERT 0 6`

**Step 3: Verify all tables exist**
```bash
psql -U gsf_user -h localhost -d gsf_db -c "\dt"
```
Expected: 13 rows listing all tables.

**Step 4: Commit**
```bash
git add Development/TSH/database/schema.sql
git commit -m "feat: add full GSF database schema with indexes and seed data"
```

---

### Task 4: Build the Flask API

**Files:**
- Create: `Development/TSH/api/app.py`
- Create: `Development/TSH/api/db.py`

**Step 1: Create db.py — database connection helper**

Create `Development/TSH/api/db.py`:
```python
import os
import psycopg2
import psycopg2.extras
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), '..', 'database', '.env'))

def get_conn():
    return psycopg2.connect(os.environ['DATABASE_URL'])

def query(sql, params=None):
    with get_conn() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(sql, params or ())
            return cur.fetchall()

def query_one(sql, params=None):
    rows = query(sql, params)
    return rows[0] if rows else None
```

**Step 2: Create app.py — Flask API**

Create `Development/TSH/api/app.py`:
```python
from flask import Flask, jsonify, abort
from flask_cors import CORS
from db import query, query_one

app = Flask(__name__)
CORS(app)

# ── Members ──────────────────────────────────────────────────────────────────

@app.get('/api/members')
def members():
    rows = query("""
        SELECT m.id, m.name, m.region, m.status, m.photo_url, m.joined_date,
               mr.rating, rs.code AS rating_system
        FROM members m
        LEFT JOIN LATERAL (
            SELECT mr2.rating, mr2.system_id
            FROM member_ratings mr2
            WHERE mr2.member_id = m.id
            ORDER BY mr2.effective_date DESC
            LIMIT 1
        ) mr ON true
        LEFT JOIN rating_systems rs ON rs.id = mr.system_id
        WHERE m.status != 'inactive'
        ORDER BY mr.rating DESC NULLS LAST
    """)
    return jsonify(list(rows))

@app.get('/api/members/<int:member_id>')
def member_detail(member_id):
    member = query_one("SELECT * FROM members WHERE id = %s", (member_id,))
    if not member:
        abort(404)
    ratings = query("""
        SELECT mr.rating, mr.effective_date, mr.source, rs.code, rs.name
        FROM member_ratings mr
        JOIN rating_systems rs ON rs.id = mr.system_id
        WHERE mr.member_id = %s
        ORDER BY mr.effective_date DESC
    """, (member_id,))
    tournaments = query("""
        SELECT t.id, t.name, t.date_start, t.location,
               s.wins, s.losses, s.spread, s.rank
        FROM tournament_entries te
        JOIN tournaments t ON t.id = te.tournament_id
        LEFT JOIN standings s ON s.member_id = te.member_id
            AND s.division_id = te.division_id
            AND s.round = (
                SELECT MAX(s2.round) FROM standings s2
                WHERE s2.division_id = te.division_id
            )
        WHERE te.member_id = %s
        ORDER BY t.date_start DESC NULLS LAST
    """, (member_id,))
    return jsonify({**dict(member),
                    'ratings': list(ratings),
                    'tournaments': list(tournaments)})

# ── Rankings ──────────────────────────────────────────────────────────────────

@app.get('/api/rankings')
def rankings():
    from flask import request
    system = request.args.get('system', 'wespa')
    rows = query("""
        SELECT m.id, m.name, m.region, m.photo_url,
               mr.rating, mr.effective_date,
               rs.code AS system,
               (SELECT COUNT(*) FROM tournament_entries te WHERE te.member_id = m.id) AS tournaments_played
        FROM members m
        JOIN member_ratings mr ON mr.member_id = m.id
        JOIN rating_systems rs ON rs.id = mr.system_id AND rs.code = %s
        WHERE m.status != 'inactive'
          AND mr.effective_date = (
              SELECT MAX(mr2.effective_date)
              FROM member_ratings mr2
              WHERE mr2.member_id = m.id AND mr2.system_id = mr.system_id
          )
        ORDER BY mr.rating DESC
    """, (system,))
    return jsonify(list(rows))

# ── Tournaments ───────────────────────────────────────────────────────────────

@app.get('/api/tournaments')
def tournaments():
    rows = query("""
        SELECT t.*,
               COUNT(DISTINCT te.member_id) AS player_count
        FROM tournaments t
        LEFT JOIN tournament_entries te ON te.tournament_id = t.id
        GROUP BY t.id
        ORDER BY t.date_start DESC NULLS LAST
    """)
    return jsonify(list(rows))

@app.get('/api/tournaments/<int:tournament_id>')
def tournament_detail(tournament_id):
    t = query_one("SELECT * FROM tournaments WHERE id = %s", (tournament_id,))
    if not t:
        abort(404)
    divisions = query(
        "SELECT * FROM divisions WHERE tournament_id = %s", (tournament_id,))
    standings = query("""
        SELECT m.name, s.wins, s.losses, s.spread, s.rating, s.rank,
               d.name AS division, s.round
        FROM standings s
        JOIN members m ON m.id = s.member_id
        JOIN divisions d ON d.id = s.division_id
        WHERE d.tournament_id = %s
          AND s.round = (SELECT MAX(s2.round) FROM standings s2
                         WHERE s2.division_id = s.division_id)
        ORDER BY d.name, s.rank
    """, (tournament_id,))
    return jsonify({**dict(t),
                    'divisions': list(divisions),
                    'standings': list(standings)})

@app.get('/api/tournaments/<int:tournament_id>/results')
def tournament_results(tournament_id):
    rows = query("""
        SELECT p.round, p.board, p.player1_id, p.player2_id,
               m1.name AS player1_name, m2.name AS player2_name,
               g.score1, g.score2, d.name AS division
        FROM pairings p
        JOIN divisions d ON d.id = p.division_id
        JOIN members m1 ON m1.id = p.player1_id
        LEFT JOIN members m2 ON m2.id = p.player2_id
        LEFT JOIN games g ON g.pairing_id = p.id
        WHERE d.tournament_id = %s
        ORDER BY d.name, p.round, p.board
    """, (tournament_id,))
    return jsonify(list(rows))

# ── History ───────────────────────────────────────────────────────────────────

@app.get('/api/history/<int:member_id>')
def member_history(member_id):
    if not query_one("SELECT id FROM members WHERE id = %s", (member_id,)):
        abort(404)
    games = query("""
        SELECT p.round, p.board, g.score1, g.score2,
               opp.name AS opponent, t.name AS tournament,
               t.date_start, d.name AS division,
               CASE WHEN p.player1_id = %s THEN g.score1 > g.score2
                    ELSE g.score2 > g.score1 END AS won
        FROM pairings p
        JOIN divisions d ON d.id = p.division_id
        JOIN tournaments t ON t.id = d.tournament_id
        LEFT JOIN games g ON g.pairing_id = p.id
        LEFT JOIN members opp ON opp.id = CASE
            WHEN p.player1_id = %s THEN p.player2_id
            ELSE p.player1_id END
        WHERE (p.player1_id = %s OR p.player2_id = %s)
          AND g.score1 IS NOT NULL
        ORDER BY t.date_start DESC, p.round
    """, (member_id, member_id, member_id, member_id))
    return jsonify(list(games))

if __name__ == '__main__':
    import os
    app.run(host='127.0.0.1', port=int(os.environ.get('FLASK_PORT', 5000)),
            debug=os.environ.get('FLASK_ENV') == 'development')
```

**Step 3: Test the API starts**
```bash
cd /home/ebrimasaye/Development/TSH/api
python3 app.py &
sleep 2
curl -s http://localhost:5000/api/members | python3 -m json.tool | head -5
curl -s http://localhost:5000/api/tournaments | python3 -m json.tool | head -5
kill %1
```
Expected: `[]` for both (empty DB) — no errors.

**Step 4: Commit**
```bash
git add Development/TSH/api/
git commit -m "feat: add Flask API with all endpoints"
```

---

### Task 5: Create systemd service for Flask API

**Files:**
- Create: `/etc/systemd/system/gsf-api.service`

**Step 1: Write the service file**

Ask user to run:
```bash
sudo tee /etc/systemd/system/gsf-api.service > /dev/null << 'EOF'
[Unit]
Description=GSF Flask API
After=network.target postgresql.service

[Service]
User=ebrimasaye
WorkingDirectory=/home/ebrimasaye/Development/TSH/api
EnvironmentFile=/home/ebrimasaye/Development/TSH/database/.env
ExecStart=/usr/bin/python3 /home/ebrimasaye/Development/TSH/api/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable gsf-api
sudo systemctl start gsf-api
```

**Step 2: Verify running**
```bash
sudo systemctl status gsf-api
curl -s http://localhost:5000/api/members
```
Expected: `active (running)`, `[]`

---

### Task 6: Update Apache to proxy /api

**Files:**
- Modify: `/etc/apache2/sites-available/gsf.conf`

**Step 1: Update gsf.conf**

Write to `/tmp/gsf.conf`:
```apache
<VirtualHost *:80>
    ServerName tournaments.gambiascrabblefederation.net
    DocumentRoot /var/www/gsf

    <Directory /var/www/gsf>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    ProxyPreserveHost On

    # Flask API
    ProxyPass /api http://localhost:5000/api
    ProxyPassReverse /api http://localhost:5000/api

    # TSH live server
    ProxyPass /tournament http://localhost:7779
    ProxyPassReverse /tournament http://localhost:7779

    ErrorLog ${APACHE_LOG_DIR}/gsf-error.log
    CustomLog ${APACHE_LOG_DIR}/gsf-access.log combined
</VirtualHost>
```

Ask user to run:
```bash
sudo cp /tmp/gsf.conf /etc/apache2/sites-available/gsf.conf
sudo apache2ctl configtest && sudo systemctl reload apache2
```

**Step 2: Verify proxy works**
```bash
curl -s http://localhost/api/members
```
Expected: `[]`

---

### Task 7: Write TSH import script

**Files:**
- Create: `Development/TSH/database/scripts/import_tsh.py`

**Step 1: Create the script**

Create `Development/TSH/database/scripts/import_tsh.py`:
```python
#!/usr/bin/env python3
"""
import_tsh.py — Import TSH tournament data into GSF database.

Usage:
    python3 import_tsh.py --tournament "GSF Nationals 2025" \
                          --dir /home/ebrimasaye/Development/TSH/GSF-Nationals-2026/
"""
import argparse
import os
import re
import sys
from datetime import date
from pathlib import Path

import psycopg2
import psycopg2.extras
from dotenv import load_dotenv

load_dotenv(Path(__file__).parent.parent / '.env')


def get_conn():
    return psycopg2.connect(os.environ['DATABASE_URL'])


def parse_t_file(path):
    """Parse a TSH .t player file. Returns list of dicts."""
    players = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            # Format: Last, First rating [wins losses ...] [; scores...]
            m = re.match(r'^(.+?)\s+(\d+)', line)
            if m:
                players.append({
                    'name': m.group(1).strip(),
                    'rating': int(m.group(2)),
                })
    return players


def parse_config(path):
    """Extract key values from config.tsh."""
    cfg = {}
    with open(path) as f:
        for line in f:
            m = re.match(r'^config\s+(\w+)\s*=\s*["\']?([^"\'#\n]+)["\']?', line)
            if m:
                cfg[m.group(1).strip()] = m.group(2).strip()
    return cfg


def upsert_member(cur, name):
    """Insert member if not exists, return id."""
    cur.execute(
        "INSERT INTO members (name) VALUES (%s) ON CONFLICT DO NOTHING RETURNING id",
        (name,))
    row = cur.fetchone()
    if row:
        return row['id']
    cur.execute("SELECT id FROM members WHERE name = %s", (name,))
    return cur.fetchone()['id']


def import_tournament(tournament_name, event_dir):
    event_dir = Path(event_dir)
    config_path = event_dir / 'config.tsh'
    if not config_path.exists():
        print(f"ERROR: config.tsh not found in {event_dir}")
        sys.exit(1)

    cfg = parse_config(config_path)
    event_name = cfg.get('event_name', tournament_name).strip('"')
    event_date = cfg.get('event_date', '').strip('"')
    max_rounds = int(cfg.get('max_rounds', 0))

    conn = get_conn()
    rows_affected = 0

    with conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:

            # Upsert tournament
            cur.execute("""
                INSERT INTO tournaments (name, max_rounds, status)
                VALUES (%s, %s, 'completed')
                ON CONFLICT DO NOTHING RETURNING id
            """, (event_name, max_rounds or None))
            row = cur.fetchone()
            if row:
                tournament_id = row['id']
                print(f"Created tournament: {event_name} (id={tournament_id})")
            else:
                cur.execute("SELECT id FROM tournaments WHERE name = %s", (event_name,))
                tournament_id = cur.fetchone()['id']
                print(f"Found existing tournament: {event_name} (id={tournament_id})")

            # Find .t player files (skip config)
            t_files = list(event_dir.glob('*.t'))
            for t_file in t_files:
                div_name = t_file.stem.upper()

                # Upsert division
                cur.execute("""
                    INSERT INTO divisions (tournament_id, name, max_rounds)
                    VALUES (%s, %s, %s)
                    ON CONFLICT DO NOTHING RETURNING id
                """, (tournament_id, div_name, max_rounds or None))
                row = cur.fetchone()
                if row:
                    division_id = row['id']
                else:
                    cur.execute(
                        "SELECT id FROM divisions WHERE tournament_id=%s AND name=%s",
                        (tournament_id, div_name))
                    division_id = cur.fetchone()['id']

                players = parse_t_file(t_file)
                print(f"  Division {div_name}: {len(players)} players")

                for i, p in enumerate(players, 1):
                    member_id = upsert_member(cur, p['name'])

                    # Upsert entry
                    cur.execute("""
                        INSERT INTO tournament_entries
                            (tournament_id, member_id, division_id, player_number, seed_rating, confirmed)
                        VALUES (%s, %s, %s, %s, %s, true)
                        ON CONFLICT (tournament_id, member_id) DO NOTHING
                    """, (tournament_id, member_id, division_id, i, p['rating']))

                    # Upsert latest rating
                    cur.execute("""
                        SELECT id FROM rating_systems WHERE code = 'wespa'
                    """)
                    rs = cur.fetchone()
                    if rs and p['rating'] > 0:
                        cur.execute("""
                            INSERT INTO member_ratings
                                (member_id, system_id, rating, effective_date, source)
                            VALUES (%s, %s, %s, %s, 'import')
                            ON CONFLICT (member_id, system_id, effective_date) DO UPDATE
                                SET rating = EXCLUDED.rating
                        """, (member_id, rs['id'], p['rating'], date.today()))
                    rows_affected += 1

            # Log the import
            cur.execute("""
                INSERT INTO tsh_import_log (tournament_id, source_file, rows_affected, notes)
                VALUES (%s, %s, %s, %s)
            """, (tournament_id, str(event_dir), rows_affected, f"Imported {len(t_files)} division(s)"))

    print(f"\nImport complete: {rows_affected} members processed.")
    conn.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Import TSH data into GSF database')
    parser.add_argument('--tournament', required=True, help='Tournament name')
    parser.add_argument('--dir', required=True, help='Path to tournament directory')
    args = parser.parse_args()
    import_tournament(args.tournament, args.dir)
```

**Step 2: Make executable**
```bash
chmod +x /home/ebrimasaye/Development/TSH/database/scripts/import_tsh.py
```

**Step 3: Run against GSF Nationals 2026**
```bash
cd /home/ebrimasaye/Development/TSH/database
python3 scripts/import_tsh.py \
  --tournament "GSF Nationals 2025" \
  --dir /home/ebrimasaye/Development/TSH/GSF-Nationals-2026/
```
Expected: `Import complete: N members processed.`

**Step 4: Verify data in DB**
```bash
psql -U gsf_user -h localhost -d gsf_db -c "SELECT name, status FROM members ORDER BY name;"
psql -U gsf_user -h localhost -d gsf_db -c "SELECT name, max_rounds FROM tournaments;"
```
Expected: Members and tournament rows populated.

**Step 5: Test API now returns data**
```bash
curl -s http://localhost:5000/api/members | python3 -m json.tool | head -20
curl -s http://localhost:5000/api/tournaments | python3 -m json.tool
```
Expected: JSON with members and tournament data.

**Step 6: Commit**
```bash
git add Development/TSH/database/scripts/
git commit -m "feat: add TSH import script"
```

---

### Task 8: Create /members portal page

**Files:**
- Create: `/var/www/gsf/members.html`

**Step 1: Write members.html**

Create `/var/www/gsf/members.html`:
```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Members — Gambia Scrabble Federation</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@700&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="/assets/style.css">
  <style>
    .page-hero { padding: 8rem 2rem 3rem; text-align: center; background: linear-gradient(160deg,#0d1117,#0e1e3a); }
    .search-bar { max-width: 480px; margin: 2rem auto 0; position: relative; }
    .search-bar input {
      width: 100%; padding: 0.85rem 1.25rem; border-radius: 8px;
      background: rgba(255,255,255,0.07); border: 1px solid rgba(255,255,255,0.15);
      color: white; font-size: 1rem; outline: none;
    }
    .search-bar input::placeholder { color: rgba(255,255,255,0.35); }
    .members-section { padding: 3rem 2rem; background: var(--dark); }
    .members-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px,1fr)); gap: 1.25rem; }
    .member-card {
      background: rgba(255,255,255,0.04); border: 1px solid rgba(255,255,255,0.1);
      border-radius: 12px; padding: 1.5rem; text-align: center;
      cursor: pointer; transition: border-color .2s, transform .2s;
    }
    .member-card:hover { border-color: var(--gold); transform: translateY(-3px); }
    .member-avatar {
      width: 64px; height: 64px; border-radius: 50%;
      background: linear-gradient(135deg, var(--blue), var(--green));
      margin: 0 auto 1rem; display: flex; align-items: center; justify-content: center;
      font-family: var(--font-head); font-size: 1.4rem; font-weight: 700; color: white;
    }
    .member-name { font-family: var(--font-head); font-size: 1rem; margin-bottom: 0.35rem; }
    .member-rating { font-size: 1.4rem; font-weight: 700; color: var(--gold); }
    .member-region { font-size: 0.78rem; color: rgba(255,255,255,0.4); margin-top: 0.25rem; }
    .member-status { display: inline-block; font-size: 0.7rem; padding: 0.15rem 0.5rem;
      border-radius: 10px; margin-top: 0.5rem; }
    .status-active { background: rgba(58,119,40,.2); color: #6ee7a0; }
    .status-junior { background: rgba(58,117,196,.2); color: #93c5fd; }
    #loading, #empty { text-align: center; color: rgba(255,255,255,.4); padding: 3rem; }
  </style>
</head>
<body>
<div class="flag-stripe"><div class="s1"></div><div class="s2"></div><div class="s3"></div><div class="s4"></div><div class="s5"></div></div>
<nav class="nav">
  <div class="nav-inner">
    <a href="/" class="nav-brand"><img src="/assets/coat-of-arms.svg" width="36" height="36" alt="GSF"> GSF</a>
    <div class="nav-links">
      <a href="/">Home</a>
      <a href="/members.html" style="color:var(--gold)">Members</a>
      <a href="/rankings.html">Rankings</a>
      <a href="/history.html">History</a>
      <a href="/tournament" class="nav-cta">Live Portal →</a>
    </div>
  </div>
</nav>

<div class="page-hero">
  <p class="section-label">Federation</p>
  <h1 class="section-title">Member Directory</h1>
  <div class="search-bar">
    <input type="search" id="search" placeholder="Search by name or region…" oninput="filterMembers()">
  </div>
</div>

<section class="members-section">
  <div class="container">
    <div id="loading">Loading members…</div>
    <div id="empty" style="display:none">No members found.</div>
    <div class="members-grid" id="grid"></div>
  </div>
</section>

<footer>
  <div class="footer-bottom" style="max-width:1200px;margin:0 auto;padding:1.5rem 2rem;border-top:1px solid rgba(255,255,255,.1);font-size:.8rem;color:rgba(255,255,255,.25)">
    <span>© 2025 Gambia Scrabble Federation</span>
  </div>
  <div class="flag-stripe"><div class="s1"></div><div class="s2"></div><div class="s3"></div><div class="s4"></div><div class="s5"></div></div>
</footer>

<script>
let all = [];
async function load() {
  try {
    const res = await fetch('/api/members');
    all = await res.json();
    document.getElementById('loading').style.display = 'none';
    render(all);
  } catch(e) {
    document.getElementById('loading').textContent = 'Could not load members.';
  }
}
function initials(name) {
  return name.split(',').map(p=>p.trim()[0]).join('').toUpperCase().slice(0,2);
}
function render(members) {
  const grid = document.getElementById('grid');
  document.getElementById('empty').style.display = members.length ? 'none' : 'block';
  grid.innerHTML = members.map(m => `
    <div class="member-card" onclick="location.href='/member.html?id=${m.id}'">
      <div class="member-avatar">${initials(m.name)}</div>
      <div class="member-name">${m.name}</div>
      <div class="member-rating">${m.rating ?? '—'}</div>
      <div class="member-region">${m.region ?? 'The Gambia'}</div>
      <span class="member-status status-${m.status}">${m.status}</span>
    </div>`).join('');
}
function filterMembers() {
  const q = document.getElementById('search').value.toLowerCase();
  render(all.filter(m =>
    m.name.toLowerCase().includes(q) ||
    (m.region||'').toLowerCase().includes(q)
  ));
}
load();
</script>
</body>
</html>
```

**Step 2: Verify it loads**
```bash
curl -s -H "Host: tournaments.gambiascrabblefederation.net" http://localhost/members.html | grep -o '<title>.*</title>'
```
Expected: `<title>Members — Gambia Scrabble Federation</title>`

---

### Task 9: Create /rankings portal page

**Files:**
- Create: `/var/www/gsf/rankings.html`

**Step 1: Write rankings.html**

Create `/var/www/gsf/rankings.html`:
```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Rankings — Gambia Scrabble Federation</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@700&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="/assets/style.css">
  <style>
    .page-hero { padding: 8rem 2rem 3rem; text-align: center; background: linear-gradient(160deg,#0d1117,#0e1e3a); }
    .system-tabs { display: flex; gap: 0.5rem; justify-content: center; margin-top: 2rem; flex-wrap: wrap; }
    .tab {
      padding: 0.45rem 1.1rem; border-radius: 20px; font-size: 0.85rem; font-weight: 600;
      border: 1px solid rgba(255,255,255,.15); color: rgba(255,255,255,.55);
      cursor: pointer; transition: all .2s;
    }
    .tab.active, .tab:hover { background: var(--gold); color: #000; border-color: var(--gold); }
    .rankings-section { padding: 3rem 2rem; }
    table { width: 100%; border-collapse: collapse; }
    thead tr { border-bottom: 1px solid rgba(255,255,255,.15); }
    th { padding: 0.75rem 1rem; font-size: 0.75rem; letter-spacing: .1em; text-transform: uppercase;
         color: rgba(255,255,255,.45); text-align: left; }
    th.right, td.right { text-align: right; }
    td { padding: 0.9rem 1rem; border-bottom: 1px solid rgba(255,255,255,.06); font-size: 0.9rem; }
    tr:hover td { background: rgba(255,255,255,.03); }
    .rank-num { font-family: var(--font-head); font-size: 1.1rem; color: rgba(255,255,255,.3); }
    .rank-num.top { color: var(--gold); }
    .rating-val { font-size: 1.1rem; font-weight: 700; color: var(--gold); }
    #loading { text-align: center; color: rgba(255,255,255,.4); padding: 3rem; }
  </style>
</head>
<body>
<div class="flag-stripe"><div class="s1"></div><div class="s2"></div><div class="s3"></div><div class="s4"></div><div class="s5"></div></div>
<nav class="nav">
  <div class="nav-inner">
    <a href="/" class="nav-brand"><img src="/assets/coat-of-arms.svg" width="36" height="36" alt="GSF"> GSF</a>
    <div class="nav-links">
      <a href="/">Home</a>
      <a href="/members.html">Members</a>
      <a href="/rankings.html" style="color:var(--gold)">Rankings</a>
      <a href="/history.html">History</a>
      <a href="/tournament" class="nav-cta">Live Portal →</a>
    </div>
  </div>
</nav>

<div class="page-hero">
  <p class="section-label">National</p>
  <h1 class="section-title">Player Rankings</h1>
  <div class="system-tabs" id="tabs"></div>
</div>

<section class="rankings-section">
  <div class="container">
    <div id="loading">Loading rankings…</div>
    <table id="table" style="display:none">
      <thead><tr>
        <th>Rank</th><th>Player</th><th>Region</th>
        <th class="right">Rating</th><th class="right">Tournaments</th>
      </tr></thead>
      <tbody id="tbody"></tbody>
    </table>
  </div>
</section>

<footer>
  <div class="footer-bottom" style="max-width:1200px;margin:0 auto;padding:1.5rem 2rem;border-top:1px solid rgba(255,255,255,.1);font-size:.8rem;color:rgba(255,255,255,.25)">
    <span>© 2025 Gambia Scrabble Federation</span>
  </div>
  <div class="flag-stripe"><div class="s1"></div><div class="s2"></div><div class="s3"></div><div class="s4"></div><div class="s5"></div></div>
</footer>

<script>
const systems = ['wespa','nsa','thai','pak'];
let active = 'wespa';

function buildTabs() {
  document.getElementById('tabs').innerHTML = systems.map(s =>
    `<div class="tab ${s===active?'active':''}" onclick="loadRankings('${s}')">${s.toUpperCase()}</div>`
  ).join('');
}

async function loadRankings(system) {
  active = system;
  buildTabs();
  document.getElementById('loading').style.display = 'block';
  document.getElementById('table').style.display = 'none';
  try {
    const res = await fetch(`/api/rankings?system=${system}`);
    const data = await res.json();
    document.getElementById('loading').style.display = 'none';
    if (!data.length) {
      document.getElementById('loading').style.display = 'block';
      document.getElementById('loading').textContent = `No ${system.toUpperCase()} rankings available.`;
      return;
    }
    document.getElementById('tbody').innerHTML = data.map((r,i) => `
      <tr>
        <td><span class="rank-num ${i<3?'top':''}">#${i+1}</span></td>
        <td><a href="/member.html?id=${r.id}" style="color:inherit">${r.name}</a></td>
        <td style="color:rgba(255,255,255,.5)">${r.region??'The Gambia'}</td>
        <td class="right"><span class="rating-val">${r.rating}</span></td>
        <td class="right" style="color:rgba(255,255,255,.5)">${r.tournaments_played}</td>
      </tr>`).join('');
    document.getElementById('table').style.display = 'table';
  } catch(e) {
    document.getElementById('loading').textContent = 'Could not load rankings.';
  }
}
buildTabs();
loadRankings('wespa');
</script>
</body>
</html>
```

---

### Task 10: Create /history portal page

**Files:**
- Create: `/var/www/gsf/history.html`

**Step 1: Write history.html**

Create `/var/www/gsf/history.html`:
```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Tournament History — Gambia Scrabble Federation</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@700&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="/assets/style.css">
  <style>
    .page-hero { padding: 8rem 2rem 3rem; text-align: center; background: linear-gradient(160deg,#0d1117,#0e1e3a); }
    .history-section { padding: 3rem 2rem; }
    .timeline { position: relative; padding-left: 2rem; }
    .timeline::before { content:''; position:absolute; left:0; top:0; bottom:0; width:2px; background:rgba(255,255,255,.1); }
    .t-item { position: relative; margin-bottom: 2rem; }
    .t-item::before { content:''; position:absolute; left:-2.4rem; top:.4rem; width:12px; height:12px;
      border-radius:50%; background:var(--gold); border:2px solid var(--dark); }
    .t-card {
      background: rgba(255,255,255,.04); border:1px solid rgba(255,255,255,.1);
      border-radius:12px; padding:1.5rem; cursor:pointer;
      transition: border-color .2s, transform .2s;
    }
    .t-card:hover { border-color:var(--gold); transform:translateX(4px); }
    .t-card.active { border-color:var(--blue); }
    .t-date { font-size:.75rem; color:var(--gold); letter-spacing:.1em; text-transform:uppercase; margin-bottom:.4rem; }
    .t-name { font-family:var(--font-head); font-size:1.2rem; margin-bottom:.3rem; }
    .t-meta { font-size:.85rem; color:rgba(255,255,255,.45); }
    .t-detail { display:none; margin-top:1rem; overflow-x:auto; }
    .t-detail.open { display:block; }
    table { width:100%; border-collapse:collapse; font-size:.875rem; }
    th { padding:.5rem .75rem; text-align:left; font-size:.7rem; letter-spacing:.1em;
         text-transform:uppercase; color:rgba(255,255,255,.4); border-bottom:1px solid rgba(255,255,255,.1); }
    td { padding:.6rem .75rem; border-bottom:1px solid rgba(255,255,255,.05); }
    #loading { text-align:center; color:rgba(255,255,255,.4); padding:3rem; }
  </style>
</head>
<body>
<div class="flag-stripe"><div class="s1"></div><div class="s2"></div><div class="s3"></div><div class="s4"></div><div class="s5"></div></div>
<nav class="nav">
  <div class="nav-inner">
    <a href="/" class="nav-brand"><img src="/assets/coat-of-arms.svg" width="36" height="36" alt="GSF"> GSF</a>
    <div class="nav-links">
      <a href="/">Home</a>
      <a href="/members.html">Members</a>
      <a href="/rankings.html">Rankings</a>
      <a href="/history.html" style="color:var(--gold)">History</a>
      <a href="/tournament" class="nav-cta">Live Portal →</a>
    </div>
  </div>
</nav>

<div class="page-hero">
  <p class="section-label">Archive</p>
  <h1 class="section-title">Tournament History</h1>
</div>

<section class="history-section">
  <div class="container">
    <div id="loading">Loading tournaments…</div>
    <div class="timeline" id="timeline"></div>
  </div>
</section>

<footer>
  <div class="footer-bottom" style="max-width:1200px;margin:0 auto;padding:1.5rem 2rem;border-top:1px solid rgba(255,255,255,.1);font-size:.8rem;color:rgba(255,255,255,.25)">
    <span>© 2025 Gambia Scrabble Federation</span>
  </div>
  <div class="flag-stripe"><div class="s1"></div><div class="s2"></div><div class="s3"></div><div class="s4"></div><div class="s5"></div></div>
</footer>

<script>
async function load() {
  try {
    const res = await fetch('/api/tournaments');
    const data = await res.json();
    document.getElementById('loading').style.display = 'none';
    document.getElementById('timeline').innerHTML = data.map(t => `
      <div class="t-item">
        <div class="t-card" onclick="toggle(${t.id}, this)">
          <div class="t-date">${t.date_start ? new Date(t.date_start).getFullYear() : 'TBD'}</div>
          <div class="t-name">${t.name}</div>
          <div class="t-meta">${t.location??'The Gambia'} · ${t.player_count} players · ${t.max_rounds??'?'} rounds</div>
          <div class="t-detail" id="detail-${t.id}">
            <p style="color:rgba(255,255,255,.4);font-size:.85rem;margin:.5rem 0">Click to load results…</p>
          </div>
        </div>
      </div>`).join('');
  } catch(e) {
    document.getElementById('loading').textContent = 'Could not load tournament history.';
  }
}

async function toggle(id, card) {
  const detail = document.getElementById(`detail-${id}`);
  if (detail.classList.toggle('open')) {
    card.classList.add('active');
    const res = await fetch(`/api/tournaments/${id}`);
    const data = await res.json();
    if (!data.standings?.length) {
      detail.innerHTML = '<p style="color:rgba(255,255,255,.4);font-size:.85rem">No results recorded.</p>';
      return;
    }
    detail.innerHTML = `<table>
      <thead><tr><th>Rank</th><th>Player</th><th>W-L</th><th>Spread</th></tr></thead>
      <tbody>${data.standings.map(s=>`
        <tr>
          <td style="color:var(--gold)">#${s.rank??'—'}</td>
          <td>${s.name}</td>
          <td style="color:rgba(255,255,255,.6)">${s.wins}-${s.losses}</td>
          <td style="color:rgba(255,255,255,.6)">${s.spread>0?'+':''}${s.spread}</td>
        </tr>`).join('')}
      </tbody></table>`;
  } else {
    card.classList.remove('active');
  }
}
load();
</script>
</body>
</html>
```

---

### Task 11: Update landing page navigation and commit everything

**Files:**
- Modify: `/var/www/gsf/index.html`

**Step 1: Add Members/Rankings/History links to nav**

In `/var/www/gsf/index.html`, find the nav-links div and add:
```html
<a href="/members.html">Members</a>
<a href="/rankings.html">Rankings</a>
<a href="/history.html">History</a>
```
between the existing `<a href="#gallery">Gallery</a>` and `<a href="/tournament" class="nav-cta">` links.

**Step 2: Add cloud migration note to Docker Compose**

Create `Development/TSH/database/docker-compose.yml`:
```yaml
# Local development mirror of cloud PostgreSQL.
# To use: docker compose up -d
# To migrate to cloud: change DATABASE_URL in .env — no other changes needed.
version: '3.9'
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: gsf_user
      POSTGRES_PASSWORD: gsf_secure_2025
      POSTGRES_DB: gsf_db
    ports:
      - "5433:5432"   # 5433 to avoid conflict with local PostgreSQL
    volumes:
      - gsf_pgdata:/var/lib/postgresql/data
      - ./schema.sql:/docker-entrypoint-initdb.d/schema.sql
volumes:
  gsf_pgdata:
```

**Step 3: Add README for database**

Create `Development/TSH/database/README.md`:
```markdown
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
```

**Step 4: Final commit**
```bash
git add Development/TSH/database/ Development/TSH/api/
git commit -m "feat: add GSF database, Flask API, import script, portal pages, and cloud migration support"
git push
```
