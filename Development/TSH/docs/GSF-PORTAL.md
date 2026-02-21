# GSF Tournament Portal — Full Documentation

## Overview

The Gambia Scrabble Federation (GSF) tournament portal is live at:

**https://tournaments.gambiascrabblefederation.net**

It consists of:
- A Gambia-themed landing page served by Apache2
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
                          ├── /            → /var/www/gsf/index.html
                          ├── /assets/     → /var/www/gsf/assets/
                          └── /tournament  → TSH HTTP server :7779
```

---

## File Locations

| File/Directory | Purpose |
|---|---|
| `/var/www/gsf/index.html` | Landing page HTML |
| `/var/www/gsf/assets/style.css` | All CSS styles |
| `/var/www/gsf/assets/coat-of-arms.svg` | Gambia coat of arms SVG |
| `/var/www/gsf/assets/gallery/` | Drop tournament photos here |
| `/etc/apache2/sites-available/gsf.conf` | Apache virtual host config |
| `~/.cloudflared/config.yml` | Cloudflare Tunnel ingress rules |
| `Development/TSH/GSF-Nationals-2026/` | Active tournament directory |
| `Development/TSH/GSF-Nationals-2026/config.tsh` | Tournament config (includes `port = 7779`) |
| `Development/TSH/start-tsh-server.sh` | Script to start the TSH web server |

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

## New Tournament Season

When setting up a new tournament (e.g. GSF Nationals 2026):

1. Create a new tournament directory:
   ```bash
   mkdir /home/ebrimasaye/Development/TSH/GSF-Nationals-2026
   ```

2. Copy and edit the config:
   ```bash
   cp /home/ebrimasaye/Development/TSH/GSF-Nationals-2026/config.tsh \
      /home/ebrimasaye/Development/TSH/GSF-Nationals-2027/config.tsh
   ```
   Update `event_name`, `event_date`, and player file.

3. Update `start-tsh-server.sh` to point to the new directory:
   ```bash
   # Edit this line:
   exec perl tsh.pl GSF-Nationals-2027
   ```

4. Update the tournament name/date on the landing page (`/var/www/gsf/index.html`).

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
