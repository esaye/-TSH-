# GSF Scrabble Portal — Design Document
Date: 2026-02-21

## Overview
A full portal at `scrabble.gambiascrabblefederation.net` serving a dazzling Gambia-themed landing page plus the live TSH tournament web GUI proxied at `/tournament`.

## Architecture

```
scrabble.gambiascrabblefederation.net
        │
   Cloudflared tunnel
        │
   Nginx :80
   ├── /             → /var/www/gsf/index.html
   ├── /assets/      → /var/www/gsf/assets/
   └── /tournament   → proxy_pass http://localhost:7779
```

## Stack
- **Nginx** — static file serving + reverse proxy
- **TSH built-in HTTP server** — port 7779, started from `GSF-Nationals-2026/`
- **Cloudflared** — exposes `scrabble.gambiascrabblefederation.net` → localhost:80
- **Plain HTML/CSS/JS** — no build tooling, self-contained

## Gambia Design Language
- Flag colours: Red `#CE1126`, Blue `#3A75C4`, Green `#3A7728`, White `#FFFFFF`
- Animated horizontal flag stripes in hero and footer
- Gambia coat of arms SVG (crossed axe and hoe, wreath)
- Typography: Google Fonts — Playfair Display (headings), Inter (body)

## Landing Page Sections
1. **Hero** — full-viewport, animated flag stripes, coat of arms, GSF title, "Enter Tournament Portal" CTA
2. **About GSF** — mission + stats row (founding year, members, tournaments)
3. **Live Tournament** — card with tournament name, links to Standings / Pairings / Score Entry at `/tournament`
4. **Player Rankings** — iframe embedding TSH ratings report
5. **News & Announcements** — three static announcement cards
6. **Gallery** — masonry photo grid, placeholders initially
7. **Footer** — contact, flag stripe bar

## Files to Create/Modify
- `/var/www/gsf/index.html` — landing page
- `/var/www/gsf/assets/style.css` — all custom CSS
- `/var/www/gsf/assets/coat-of-arms.svg` — Gambia coat of arms
- `/etc/nginx/sites-available/gsf` — Nginx site config
- `GSF-Nationals-2026/config.tsh` — add `config port = 7779`
- `~/.cloudflared/config.yml` — add new ingress rule
- `/etc/systemd/system/tsh-gsf.service` — TSH systemd service (optional)

## Deployment Steps
1. Install Nginx if not present
2. Create `/var/www/gsf/` with landing page + assets
3. Write and enable Nginx site config
4. Add `config port = 7779` to TSH tournament config
5. Update cloudflared config with new hostname ingress
6. Restart cloudflared
7. Start TSH server
