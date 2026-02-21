# GSF Tournament Portal — Full Documentation

## Overview

The Gambia Scrabble Federation (GSF) tournament portal is live at:

**https://tournaments.gambiascrabblefederation.net**

It consists of:
- A Gambia-themed landing page served by Apache2
- Three dynamic portal pages (Members, Rankings, History) fed by a live PostgreSQL database
- A Flask JSON API serving all tournament and player data
- The TSH tournament management GUI proxied at `/tournament`
- A Cloudflare Tunnel connecting the domain to the local machine

---

## Architecture

```
Browser
  │
  └─► Cloudflare (DNS proxy)
          │
          └─► Cloudflare Tunnel (jellyfin / 3205f896-...)
                  │
                  └─► Apache2 :80  (this machine)
                          │
                          ├── /              → /var/www/gsf/index.html
                          ├── /assets/       → /var/www/gsf/assets/
                          ├── /members.html  → /var/www/gsf/members.html
                          ├── /rankings.html → /var/www/gsf/rankings.html
                          ├── /history.html  → /var/www/gsf/history.html
                          ├── /api/*         → Flask API :5000
                          └── /tournament    → TSH HTTP server :7779

Flask API :5000
  │
  └─► PostgreSQL :5432  (gsf_db)
          │
          └─► Populated by import_tsh.py after each tournament
```

---

## File Locations

### Web server

| File/Directory | Purpose |
|---|---|
| `/var/www/gsf/index.html` | Landing page HTML |
| `/var/www/gsf/members.html` | Member directory portal page |
| `/var/www/gsf/rankings.html` | National rankings portal page |
| `/var/www/gsf/history.html` | Tournament archive portal page |
| `/var/www/gsf/assets/style.css` | All CSS styles (Gambia flag colour variables) |
| `/var/www/gsf/assets/coat-of-arms.svg` | Gambia coat of arms SVG |
| `/var/www/gsf/assets/gallery/` | Drop tournament photos here |
| `/etc/apache2/sites-available/gsf.conf` | Apache virtual host config |

### API and database

| File/Directory | Purpose |
|---|---|
| `Development/TSH/api/app.py` | Flask API — all 8 endpoints |
| `Development/TSH/api/db.py` | PostgreSQL connection helper |
| `Development/TSH/database/.env` | Live credentials (not in git) |
| `Development/TSH/database/.env.example` | Template for new installs |
| `Development/TSH/database/schema.sql` | Full 13-table schema + seed data |
| `Development/TSH/database/requirements.txt` | Python dependencies |
| `Development/TSH/database/alembic.ini` | Alembic config (reads DATABASE_URL) |
| `Development/TSH/database/alembic/env.py` | Alembic env — loads .env at runtime |
| `Development/TSH/database/docker-compose.yml` | Local dev Docker PostgreSQL mirror |
| `Development/TSH/database/scripts/import_tsh.py` | Imports TSH .t files into database |
| `/etc/systemd/system/gsf-api.service` | systemd unit — auto-starts Flask API |

### TSH tournament management

| File/Directory | Purpose |
|---|---|
| `Development/TSH/GSF-Nationals-2026/` | Active tournament directory |
| `Development/TSH/GSF-Nationals-2026/config.tsh` | Tournament config (includes `port = 7779`) |
| `Development/TSH/start-tsh-server.sh` | Script to start the TSH web server |
| `~/.cloudflared/config.yml` | Cloudflare Tunnel ingress rules |

---

## Cloudflare Tunnel

**Tunnel name:** jellyfin
**Tunnel ID:** `3205f896-0c3c-4a5d-99f9-a923bac2c2cb`
**Credentials:** `~/.cloudflared/3205f896-0c3c-4a5d-99f9-a923bac2c2cb.json`

**DNS record** (set in Cloudflare dashboard):
```
Type:   CNAME
Name:   tournaments
Target: 3205f896-0c3c-4a5d-99f9-a923bac2c2cb.cfargotunnel.com
Proxy:  Enabled (orange cloud)
```

**Config file** (`~/.cloudflared/config.yml`):
```yaml
tunnel: 3205f896-0c3c-4a5d-99f9-a923bac2c2cb
credentials-file: /home/ebrimasaye/.cloudflared/3205f896-0c3c-4a5d-99f9-a923bac2c2cb.json
protocol: http2

ingress:
  - hostname: music.ebrimasaye.com
    service: http://localhost:8096
    originRequest:
      noTLSVerify: true
  - hostname: tournaments.gambiascrabblefederation.net
    service: http://localhost:80
  - service: http_status:404
```

**Manage cloudflared:**
```bash
sudo systemctl start cloudflared
sudo systemctl stop cloudflared
sudo systemctl restart cloudflared
sudo systemctl status cloudflared
```

---

## Apache Configuration

**Site config:** `/etc/apache2/sites-available/gsf.conf`

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

**Apache commands:**
```bash
sudo systemctl reload apache2      # apply config changes
sudo systemctl restart apache2     # full restart
sudo apache2ctl configtest         # verify config syntax
sudo tail -f /var/log/apache2/gsf-access.log   # live access log
sudo tail -f /var/log/apache2/gsf-error.log    # live error log
```

---

## Database

**Engine:** PostgreSQL 16 on localhost:5432
**Database:** `gsf_db`
**User:** `gsf_user` / password in `Development/TSH/database/.env`

### Schema — 13 tables

| Table | Purpose |
|---|---|
| `members` | All registered GSF players |
| `member_ratings` | Rating per player per system over time |
| `rating_systems` | Supported systems: wespa, nsa, thai, pak, nor, ken |
| `tournaments` | All tournaments (past and upcoming) |
| `divisions` | Per-tournament divisions (A, B, C…) |
| `tournament_entries` | Player registration and seeding |
| `pairings` | Round-by-round matchups |
| `games` | Scores for each pairing |
| `standings` | Snapshot after each round (wins, losses, spread, rank) |
| `teams` | Team registrations |
| `team_members` | Team composition per tournament |
| `prizes` | Prize winners and amounts (GMD) |
| `tsh_import_log` | Audit trail of every import run |

### Direct database access
```bash
PGPASSWORD=gsf_secure_2025 psql -U gsf_user -h localhost -d gsf_db

# Useful queries
\dt                                    -- list all tables
SELECT name, rating FROM members JOIN member_ratings ... -- check ratings
SELECT * FROM tournaments;             -- list tournaments
SELECT * FROM tsh_import_log;          -- check import history
```

### Apply schema to a fresh database
```bash
PGPASSWORD=gsf_secure_2025 psql -U gsf_user -h localhost -d gsf_db \
  -f /home/ebrimasaye/Development/TSH/database/schema.sql
```

---

## Flask API

**Service:** `gsf-api` (systemd)
**Runs on:** `http://127.0.0.1:5000`
**Proxied at:** `https://tournaments.gambiascrabblefederation.net/api/*`

### Endpoints

| Method | Endpoint | Returns |
|---|---|---|
| GET | `/api/members` | All active members + current rating |
| GET | `/api/members/:id` | Full profile + rating history + career tournaments |
| GET | `/api/rankings` | National rankings sorted by rating (default: WESPA) |
| GET | `/api/rankings?system=nsa` | Rankings filtered by rating system |
| GET | `/api/tournaments` | All tournaments with player counts |
| GET | `/api/tournaments/:id` | Tournament detail + final standings |
| GET | `/api/tournaments/:id/results` | Round-by-round pairings and scores |
| GET | `/api/history/:member_id` | Full career game history for one player |

### Manage the API service
```bash
sudo systemctl start gsf-api
sudo systemctl stop gsf-api
sudo systemctl restart gsf-api
sudo systemctl status gsf-api
journalctl -u gsf-api -n 50 -f      # live logs
```

### Run manually (for debugging)
```bash
cd /home/ebrimasaye/Development/TSH/api
python3 app.py
```

---

## TSH Import Script

After each tournament, import its data into the database:

```bash
python3 /home/ebrimasaye/Development/TSH/database/scripts/import_tsh.py \
  --tournament "GSF Nationals 2026" \
  --dir /home/ebrimasaye/Development/TSH/GSF-Nationals-2026/
```

The script reads:
- `config.tsh` — tournament name and round count (uses `config event_name`)
- `*.t` files — player names and seed ratings (one player per line)

It creates/updates rows in `members`, `tournaments`, `divisions`, `tournament_entries`, `member_ratings`, and logs the run in `tsh_import_log`.

**Note:** The tournament display name is taken from `config event_name` in `config.tsh`, not from the `--tournament` flag. Edit `config event_name` in the config file to set the exact name you want displayed.

---

## TSH Web Server

TSH has a built-in HTTP server enabled by `config port = 7779` in the tournament config.

**Start the server:**
```bash
/home/ebrimasaye/Development/TSH/start-tsh-server.sh
```

Or manually:
```bash
cd /home/ebrimasaye/Development/TSH
perl tsh.pl GSF-Nationals-2026
```

Once running, the TSH web GUI is available at:
- Local: http://localhost:7779
- Public: https://tournaments.gambiascrabblefederation.net/tournament

**Note:** TSH must be running for the `/tournament` section of the portal to work. It only needs to run during and around active tournaments.

---

## Running a Tournament

1. **Start TSH server:**
   ```bash
   /home/ebrimasaye/Development/TSH/start-tsh-server.sh
   ```

2. **Open the TSH shell** (separate terminal):
   ```bash
   cd /home/ebrimasaye/Development/TSH
   perl tsh.pl GSF-Nationals-2026
   ```

3. **Use TSH commands** to manage the tournament:
   ```
   pair 1 a          # generate round 1 pairings
   sp 1 a            # show round 1 pairings
   addscore 1 a      # enter scores for round 1
   rat a             # show ratings/standings
   ```

4. **Live results** update automatically at:
   https://tournaments.gambiascrabblefederation.net/tournament

5. **After the tournament is complete, import results into the database:**
   ```bash
   python3 /home/ebrimasaye/Development/TSH/database/scripts/import_tsh.py \
     --tournament "GSF Nationals 2026" \
     --dir /home/ebrimasaye/Development/TSH/GSF-Nationals-2026/
   ```
   Members, rankings, and history pages update automatically.

---

## New Tournament Season

When setting up a new tournament (e.g. GSF Nationals 2027):

1. Create a new tournament directory:
   ```bash
   mkdir /home/ebrimasaye/Development/TSH/GSF-Nationals-2027
   ```

2. Copy and edit the config:
   ```bash
   cp /home/ebrimasaye/Development/TSH/GSF-Nationals-2026/config.tsh \
      /home/ebrimasaye/Development/TSH/GSF-Nationals-2027/config.tsh
   ```
   Update `event_name`, `event_date`, and player file path.

3. Update `start-tsh-server.sh` to point to the new directory:
   ```bash
   # Edit this line:
   exec perl tsh.pl GSF-Nationals-2027
   ```

4. Update the tournament name/date on the landing page (`/var/www/gsf/index.html`).

5. After the tournament, run the import script to populate the database.

---

## Customising the Landing Page

All edits are in `/var/www/gsf/index.html` — no build step needed, changes are live immediately.

### Update tournament name/date
Find the `#tournament` section and edit:
```html
<div class="tournament-name">GSF Nationals 2025</div>
<div class="tournament-date">November 28–29, 2025 · Banjul, The Gambia</div>
```

### Add/edit news cards
Find the `#news` section. Each card follows this pattern:
```html
<div class="news-card">
  <span class="news-tag tag-tournament">Tournament</span>
  <h3>Your headline</h3>
  <p>Your description.</p>
  <div class="news-date">Month Year</div>
</div>
```
Tag classes: `tag-tournament` (red), `tag-results` (green), `tag-announcement` (gold).

### Add gallery photos
Drop image files into `/var/www/gsf/assets/gallery/`, then replace a gallery placeholder in `index.html`:
```html
<!-- Before -->
<div class="gallery-placeholder">Photo</div>

<!-- After -->
<img src="/assets/gallery/your-photo.jpg" alt="Description">
```

### Update statistics
Find the `.stats-row` in the `#about` section:
```html
<div class="stat-num">15+</div>   <!-- Nationals held -->
<div class="stat-num">100+</div>  <!-- Registered players -->
<div class="stat-num">2005</div>  <!-- Founded year -->
```

### Design colours
All colours are CSS variables in `/var/www/gsf/assets/style.css`:
```css
:root {
  --red:   #CE1126;   /* Gambia flag red */
  --blue:  #3A75C4;   /* Gambia flag blue */
  --green: #3A7728;   /* Gambia flag green */
  --gold:  #FFD700;   /* Accent colour */
}
```

---

## Cloud Migration

The entire stack is designed to move to any cloud PostgreSQL with a single change.

**Step 1:** Provision a PostgreSQL database on your target (Supabase, AWS RDS, Neon, Railway, etc.)

**Step 2:** Run the schema against it:
```bash
psql $NEW_DATABASE_URL -f /home/ebrimasaye/Development/TSH/database/schema.sql
```

**Step 3:** Update `Development/TSH/database/.env`:
```
DATABASE_URL=postgresql://user:pass@cloud-host:5432/dbname
```

**Step 4:** Restart the Flask API:
```bash
sudo systemctl restart gsf-api
```

No other code changes are needed. The Flask API, Alembic migrations, and import script all read from `DATABASE_URL`.

**Supported cloud targets:**
- **Supabase**: `postgresql://postgres:pass@db.xxx.supabase.co:5432/postgres`
- **AWS RDS**: `postgresql://gsf_user:pass@endpoint.rds.amazonaws.com:5432/gsf_db`
- **Neon**: `postgresql://gsf_user:pass@ep-xxx.neon.tech/gsf_db`
- **Railway**: connection string from Railway dashboard

---

## Troubleshooting

**Site not loading:**
```bash
sudo systemctl status cloudflared    # is tunnel running?
sudo systemctl status apache2        # is Apache running?
curl -H "Host: tournaments.gambiascrabblefederation.net" http://localhost/
```

**`/tournament` returning 502 Bad Gateway:**
- TSH server is not running. Start it with `./start-tsh-server.sh`.

**`/api/*` returning 502 Bad Gateway:**
- Flask API is not running.
```bash
sudo systemctl status gsf-api
sudo systemctl start gsf-api
journalctl -u gsf-api -n 50         # check for startup errors
```

**Members/Rankings/History pages show "Could not load":**
- The Flask API is down or the `/api` proxy is not working.
```bash
curl -H "Host: tournaments.gambiascrabblefederation.net" http://localhost/api/members
sudo systemctl status gsf-api
```

**Changes to `index.html` not showing:**
- No build step needed — changes are live immediately. Hard-refresh the browser (Ctrl+Shift+R).

**Cloudflared tunnel not connecting:**
```bash
sudo systemctl restart cloudflared
journalctl -u cloudflared -n 50     # view logs
```

**Apache config error after editing `gsf.conf`:**
```bash
sudo apache2ctl configtest           # check syntax
sudo systemctl reload apache2        # apply if OK
```

**Database connection error in Flask:**
- Check `.env` has the correct `DATABASE_URL`.
- Check PostgreSQL is running: `sudo systemctl status postgresql`
- Test connection directly:
  ```bash
  PGPASSWORD=gsf_secure_2025 psql -U gsf_user -h localhost -d gsf_db -c "SELECT 1"
  ```

**Import script finds no players:**
- Check the `.t` file exists in the tournament directory.
- Preview the file: `head -3 GSF-Nationals-2026/a.t`
- The script skips lines starting with `#` and empty lines.
