# GSF Scrabble Portal Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deploy a dazzling Gambia-themed landing page at `scrabble.gambiascrabblefederation.net` with the TSH tournament GUI proxied at `/tournament`.

**Architecture:** Apache2 (already active) serves static files from `/var/www/gsf/` and reverse-proxies `/tournament/*` to the TSH built-in HTTP server on port 7779. Cloudflared tunnels the domain to Apache on port 80.

**Tech Stack:** Apache2, HTML5/CSS3/vanilla JS, TSH Perl HTTP server, Cloudflared

---

### Task 1: Enable Apache proxy modules and create web root

**Files:**
- Create: `/var/www/gsf/` (directory)
- Create: `/etc/apache2/sites-available/gsf.conf`

**Step 1: Enable proxy modules**

```bash
sudo a2enmod proxy proxy_http
```
Expected: "Enabling module proxy... Enabling module proxy_http..."

**Step 2: Create web root**

```bash
sudo mkdir -p /var/www/gsf/assets/gallery
sudo chown -R $USER:$USER /var/www/gsf
```

**Step 3: Write Apache virtual host config**

Create `/etc/apache2/sites-available/gsf.conf`:

```apache
<VirtualHost *:80>
    ServerName scrabble.gambiascrabblefederation.net

    DocumentRoot /var/www/gsf

    <Directory /var/www/gsf>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    # Proxy /tournament to TSH built-in server
    ProxyPreserveHost On
    ProxyPass /tournament http://localhost:7779
    ProxyPassReverse /tournament http://localhost:7779

    ErrorLog ${APACHE_LOG_DIR}/gsf-error.log
    CustomLog ${APACHE_LOG_DIR}/gsf-access.log combined
</VirtualHost>
```

**Step 4: Enable the site and restart Apache**

```bash
sudo a2ensite gsf.conf
sudo systemctl restart apache2
```

**Step 5: Verify Apache is happy**

```bash
sudo apache2ctl configtest
```
Expected: `Syntax OK`

**Step 6: Commit config**

```bash
git add Development/TSH/docs/plans/
git commit -m "docs: add GSF portal design and implementation plan"
```

---

### Task 2: Create Gambia coat of arms SVG

**Files:**
- Create: `/var/www/gsf/assets/coat-of-arms.svg`

**Step 1: Write the SVG**

Create `/var/www/gsf/assets/coat-of-arms.svg`:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 240" width="200" height="240">
  <!-- Shield background -->
  <path d="M20,10 L180,10 L180,130 Q180,200 100,230 Q20,200 20,130 Z"
        fill="#3A75C4" stroke="#FFD700" stroke-width="3"/>
  <!-- Shield inner border -->
  <path d="M30,18 L170,18 L170,128 Q170,192 100,220 Q30,192 30,128 Z"
        fill="none" stroke="#FFD700" stroke-width="1.5"/>

  <!-- Red top band on shield -->
  <path d="M30,18 L170,18 L170,60 L30,60 Z" fill="#CE1126"/>
  <!-- Green bottom band on shield -->
  <path d="M30,100 L170,100 L170,128 Q170,192 100,220 Q30,192 30,128 Z" fill="#3A7728"/>

  <!-- Crossed axe and hoe (white) -->
  <!-- Hoe handle -->
  <line x1="85" y1="35" x2="115" y2="95" stroke="white" stroke-width="5" stroke-linecap="round"/>
  <!-- Hoe head -->
  <ellipse cx="118" cy="91" rx="12" ry="5" fill="white" transform="rotate(-45,118,91)"/>
  <!-- Axe handle -->
  <line x1="115" y1="35" x2="85" y2="95" stroke="white" stroke-width="5" stroke-linecap="round"/>
  <!-- Axe head -->
  <path d="M72,42 Q62,52 72,62 L85,52 Z" fill="white"/>

  <!-- Stars (two white stars on red band) -->
  <polygon points="60,30 63,40 73,40 65,46 68,56 60,50 52,56 55,46 47,40 57,40"
           fill="white" transform="scale(0.5) translate(60,10)"/>
  <polygon points="140,30 143,40 153,40 145,46 148,56 140,50 132,56 135,46 127,40 137,40"
           fill="white" transform="scale(0.5) translate(60,10)"/>

  <!-- Wreath -->
  <!-- Left branch -->
  <path d="M25,120 Q15,100 20,80 Q25,90 30,100 Q20,95 25,115"
        fill="#3A7728" stroke="#2d5e21" stroke-width="0.5"/>
  <path d="M22,115 Q10,95 18,72 Q24,85 26,98"
        fill="#3A7728" stroke="#2d5e21" stroke-width="0.5"/>
  <path d="M28,105 Q18,82 28,65 Q32,78 32,92"
        fill="#3A7728" stroke="#2d5e21" stroke-width="0.5"/>
  <!-- Right branch -->
  <path d="M175,120 Q185,100 180,80 Q175,90 170,100 Q180,95 175,115"
        fill="#3A7728" stroke="#2d5e21" stroke-width="0.5"/>
  <path d="M178,115 Q190,95 182,72 Q176,85 174,98"
        fill="#3A7728" stroke="#2d5e21" stroke-width="0.5"/>
  <path d="M172,105 Q182,82 172,65 Q168,78 168,92"
        fill="#3A7728" stroke="#2d5e21" stroke-width="0.5"/>

  <!-- Ribbon -->
  <path d="M40,185 Q100,175 160,185 L155,200 Q100,192 45,200 Z"
        fill="#CE1126" stroke="#8B0000" stroke-width="1"/>
  <!-- Motto -->
  <text x="100" y="196" text-anchor="middle" fill="white"
        font-family="serif" font-size="9" font-weight="bold" letter-spacing="1">
    PROGRESS · PEACE · PROSPERITY
  </text>
</svg>
```

**Step 2: Verify it renders**

Open `/var/www/gsf/assets/coat-of-arms.svg` in a browser.
Expected: A blue shield with red top, green bottom, crossed tools, wreath, red ribbon with motto.

---

### Task 3: Create the CSS

**Files:**
- Create: `/var/www/gsf/assets/style.css`

**Step 1: Write the CSS**

Create `/var/www/gsf/assets/style.css`:

```css
/* ─── Variables ─────────────────────────────────────────────── */
:root {
  --red:   #CE1126;
  --blue:  #3A75C4;
  --green: #3A7728;
  --gold:  #FFD700;
  --white: #FFFFFF;
  --dark:  #0d1117;
  --card-bg: rgba(255,255,255,0.05);
  --card-border: rgba(255,255,255,0.12);
  --font-head: 'Playfair Display', Georgia, serif;
  --font-body: 'Inter', Arial, sans-serif;
}

/* ─── Reset & Base ───────────────────────────────────────────── */
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
html { scroll-behavior: smooth; }
body {
  font-family: var(--font-body);
  background: var(--dark);
  color: var(--white);
  overflow-x: hidden;
}
a { color: inherit; text-decoration: none; }
img { max-width: 100%; display: block; }

/* ─── Flag Stripe ────────────────────────────────────────────── */
.flag-stripe {
  display: flex;
  height: 6px;
  width: 100%;
}
.flag-stripe .s1 { flex: 2; background: var(--red); }
.flag-stripe .s2 { flex: 0.4; background: var(--white); }
.flag-stripe .s3 { flex: 3; background: var(--blue); }
.flag-stripe .s4 { flex: 0.4; background: var(--white); }
.flag-stripe .s5 { flex: 2; background: var(--green); }

/* ─── Navigation ─────────────────────────────────────────────── */
.nav {
  position: fixed; top: 0; left: 0; right: 0; z-index: 100;
  background: rgba(13,17,23,0.9);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
  border-bottom: 1px solid var(--card-border);
}
.nav-inner {
  max-width: 1200px; margin: 0 auto;
  display: flex; align-items: center; justify-content: space-between;
  padding: 0 2rem; height: 64px;
}
.nav-brand {
  display: flex; align-items: center; gap: 0.75rem;
  font-family: var(--font-head); font-size: 1.1rem; font-weight: 700;
  color: var(--gold);
}
.nav-brand img { width: 36px; height: 36px; }
.nav-links { display: flex; gap: 2rem; }
.nav-links a {
  font-size: 0.875rem; font-weight: 500; color: rgba(255,255,255,0.75);
  transition: color 0.2s;
}
.nav-links a:hover { color: var(--gold); }
.nav-cta {
  background: var(--red); color: var(--white) !important;
  padding: 0.5rem 1.25rem; border-radius: 6px;
  font-weight: 600; font-size: 0.875rem;
  transition: background 0.2s, transform 0.15s;
}
.nav-cta:hover { background: #a50e1e; transform: translateY(-1px); }

/* ─── Hero ───────────────────────────────────────────────────── */
.hero {
  min-height: 100vh;
  background: linear-gradient(160deg, #0d1117 0%, #0e1e3a 50%, #0d2010 100%);
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  text-align: center; padding: 6rem 2rem 4rem;
  position: relative; overflow: hidden;
}
.hero::before {
  content: '';
  position: absolute; inset: 0;
  background: radial-gradient(ellipse at 50% 40%, rgba(58,117,196,0.18) 0%, transparent 65%),
              radial-gradient(ellipse at 80% 80%, rgba(58,119,40,0.12) 0%, transparent 55%),
              radial-gradient(ellipse at 20% 80%, rgba(206,17,38,0.10) 0%, transparent 55%);
  pointer-events: none;
}
/* Animated background flag stripes */
.hero-stripes {
  position: absolute; inset: 0; pointer-events: none;
  display: flex; flex-direction: column; justify-content: stretch;
  opacity: 0.04;
}
.hero-stripes div { flex: 1; }
.hero-stripes .hs1 { background: var(--red); }
.hero-stripes .hs2 { background: var(--white); flex: 0.3; }
.hero-stripes .hs3 { background: var(--blue); flex: 1.8; }
.hero-stripes .hs4 { background: var(--white); flex: 0.3; }
.hero-stripes .hs5 { background: var(--green); }

.hero-coa {
  width: clamp(120px, 18vw, 180px);
  margin-bottom: 2rem; position: relative; z-index: 1;
  filter: drop-shadow(0 0 32px rgba(255,215,0,0.35));
  animation: float 6s ease-in-out infinite;
}
@keyframes float {
  0%, 100% { transform: translateY(0); }
  50%       { transform: translateY(-12px); }
}
.hero-eyebrow {
  font-size: 0.8rem; letter-spacing: 0.3em; text-transform: uppercase;
  color: var(--gold); margin-bottom: 1rem; position: relative; z-index: 1;
}
.hero h1 {
  font-family: var(--font-head);
  font-size: clamp(2.2rem, 6vw, 4.5rem);
  line-height: 1.1; font-weight: 700;
  background: linear-gradient(135deg, var(--white) 30%, var(--gold) 100%);
  -webkit-background-clip: text; -webkit-text-fill-color: transparent;
  background-clip: text;
  margin-bottom: 1.25rem; position: relative; z-index: 1;
}
.hero-sub {
  font-size: clamp(1rem, 2vw, 1.25rem); color: rgba(255,255,255,0.7);
  max-width: 560px; line-height: 1.6;
  margin-bottom: 2.5rem; position: relative; z-index: 1;
}
.hero-actions { display: flex; gap: 1rem; flex-wrap: wrap; justify-content: center; position: relative; z-index: 1; }
.btn-primary {
  background: linear-gradient(135deg, var(--red), #a50e1e);
  color: white; font-weight: 700; font-size: 1rem;
  padding: 0.9rem 2.2rem; border-radius: 8px;
  box-shadow: 0 4px 24px rgba(206,17,38,0.4);
  transition: transform 0.2s, box-shadow 0.2s;
  display: inline-flex; align-items: center; gap: 0.5rem;
}
.btn-primary:hover { transform: translateY(-2px); box-shadow: 0 8px 32px rgba(206,17,38,0.5); }
.btn-secondary {
  background: var(--card-bg); color: white; font-weight: 600; font-size: 1rem;
  padding: 0.9rem 2rem; border-radius: 8px;
  border: 1px solid var(--card-border);
  transition: background 0.2s, transform 0.2s;
  display: inline-flex; align-items: center; gap: 0.5rem;
}
.btn-secondary:hover { background: rgba(255,255,255,0.1); transform: translateY(-2px); }
.hero-scroll {
  position: absolute; bottom: 2rem; left: 50%; transform: translateX(-50%);
  color: rgba(255,255,255,0.3); font-size: 0.75rem; letter-spacing: 0.15em;
  text-transform: uppercase; display: flex; flex-direction: column; align-items: center; gap: 0.5rem;
  animation: bounce 2s ease-in-out infinite;
}
@keyframes bounce { 0%,100%{transform:translateX(-50%) translateY(0)} 50%{transform:translateX(-50%) translateY(6px)} }
.hero-scroll::after {
  content: ''; width: 1px; height: 40px;
  background: linear-gradient(to bottom, rgba(255,255,255,0.3), transparent);
}

/* ─── Sections ───────────────────────────────────────────────── */
section { padding: 5rem 2rem; }
.container { max-width: 1200px; margin: 0 auto; }
.section-label {
  font-size: 0.75rem; letter-spacing: 0.3em; text-transform: uppercase;
  color: var(--gold); margin-bottom: 0.75rem;
}
.section-title {
  font-family: var(--font-head); font-size: clamp(1.8rem, 4vw, 2.8rem);
  font-weight: 700; margin-bottom: 1rem;
  color: var(--white);
}
.section-intro {
  color: rgba(255,255,255,0.65); font-size: 1.05rem; line-height: 1.7;
  max-width: 680px; margin-bottom: 3rem;
}

/* ─── About ──────────────────────────────────────────────────── */
#about { background: linear-gradient(180deg, var(--dark) 0%, #0c1a2e 100%); }
.about-grid {
  display: grid; grid-template-columns: 1fr 1fr; gap: 3rem; align-items: center;
}
.about-text p { color: rgba(255,255,255,0.7); line-height: 1.8; margin-bottom: 1rem; }
.stats-row {
  display: flex; gap: 2rem; flex-wrap: wrap; margin-top: 2rem;
}
.stat { text-align: center; }
.stat-num {
  font-family: var(--font-head); font-size: 2.5rem; font-weight: 700;
  color: var(--gold); line-height: 1;
}
.stat-label { font-size: 0.8rem; color: rgba(255,255,255,0.5); letter-spacing: 0.1em; margin-top: 0.25rem; }
.about-coa {
  display: flex; justify-content: center;
}
.about-coa img { width: 200px; filter: drop-shadow(0 0 40px rgba(255,215,0,0.2)); }

/* ─── Tournament ─────────────────────────────────────────────── */
#tournament { background: #0c1a2e; }
.tournament-card {
  background: linear-gradient(135deg, rgba(58,117,196,0.15), rgba(58,119,40,0.1));
  border: 1px solid rgba(58,117,196,0.3);
  border-radius: 16px; padding: 2.5rem;
  display: grid; grid-template-columns: 1fr auto; gap: 2rem; align-items: center;
}
.tournament-badge {
  display: inline-flex; align-items: center; gap: 0.5rem;
  background: rgba(58,119,40,0.2); border: 1px solid rgba(58,119,40,0.4);
  border-radius: 20px; padding: 0.3rem 0.9rem;
  font-size: 0.8rem; color: #5cb85c; font-weight: 600;
  margin-bottom: 1rem;
}
.tournament-badge::before { content: ''; width: 8px; height: 8px; border-radius: 50%; background: #5cb85c; animation: pulse 1.5s infinite; }
@keyframes pulse { 0%,100%{opacity:1} 50%{opacity:0.4} }
.tournament-name {
  font-family: var(--font-head); font-size: 1.8rem; font-weight: 700;
  margin-bottom: 0.5rem;
}
.tournament-date { color: rgba(255,255,255,0.55); font-size: 0.9rem; margin-bottom: 1.5rem; }
.tournament-links { display: flex; gap: 1rem; flex-wrap: wrap; }
.tlink {
  background: var(--card-bg); border: 1px solid var(--card-border);
  border-radius: 8px; padding: 0.6rem 1.2rem;
  font-size: 0.875rem; font-weight: 600; color: rgba(255,255,255,0.85);
  transition: background 0.2s, border-color 0.2s, transform 0.15s;
  display: inline-flex; align-items: center; gap: 0.4rem;
}
.tlink:hover { background: rgba(255,255,255,0.1); border-color: var(--gold); transform: translateY(-1px); }
.tlink.primary { background: var(--red); border-color: var(--red); color: white; }
.tlink.primary:hover { background: #a50e1e; border-color: #a50e1e; }
.tournament-emblem img { width: 100px; opacity: 0.85; }

/* ─── Rankings ───────────────────────────────────────────────── */
#rankings { background: var(--dark); }
.rankings-frame-wrap {
  border: 1px solid var(--card-border); border-radius: 12px; overflow: hidden;
  background: #111827;
}
.rankings-frame-header {
  background: rgba(255,255,255,0.04); padding: 0.75rem 1.25rem;
  display: flex; align-items: center; justify-content: space-between;
  border-bottom: 1px solid var(--card-border);
}
.rankings-frame-header span { font-size: 0.8rem; color: rgba(255,255,255,0.45); }
.rankings-frame-header a { font-size: 0.8rem; color: var(--gold); }
.rankings-iframe {
  width: 100%; height: 500px; border: none;
  background: #fff;
}

/* ─── News ───────────────────────────────────────────────────── */
#news { background: linear-gradient(180deg, #0c1a2e 0%, var(--dark) 100%); }
.news-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 1.5rem; }
.news-card {
  background: var(--card-bg); border: 1px solid var(--card-border);
  border-radius: 12px; padding: 1.75rem;
  transition: border-color 0.2s, transform 0.2s;
}
.news-card:hover { border-color: var(--gold); transform: translateY(-3px); }
.news-tag {
  display: inline-block; font-size: 0.7rem; font-weight: 700; letter-spacing: 0.1em;
  text-transform: uppercase; padding: 0.2rem 0.6rem; border-radius: 4px;
  margin-bottom: 0.75rem;
}
.tag-tournament { background: rgba(206,17,38,0.2); color: #f87171; }
.tag-announcement { background: rgba(255,215,0,0.15); color: var(--gold); }
.tag-results { background: rgba(58,119,40,0.2); color: #6ee7b7; }
.news-card h3 {
  font-family: var(--font-head); font-size: 1.1rem; margin-bottom: 0.6rem;
  line-height: 1.4;
}
.news-card p { font-size: 0.875rem; color: rgba(255,255,255,0.6); line-height: 1.6; }
.news-card .news-date { font-size: 0.75rem; color: rgba(255,255,255,0.35); margin-top: 1rem; }

/* ─── Gallery ────────────────────────────────────────────────── */
#gallery { background: var(--dark); }
.gallery-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  grid-template-rows: auto;
  gap: 0.75rem;
}
.gallery-item {
  position: relative; overflow: hidden; border-radius: 8px;
  background: rgba(255,255,255,0.04);
  aspect-ratio: 4/3;
  cursor: pointer;
}
.gallery-item:first-child { grid-column: span 2; grid-row: span 2; aspect-ratio: auto; }
.gallery-item img { width: 100%; height: 100%; object-fit: cover; transition: transform 0.4s; }
.gallery-placeholder {
  width: 100%; height: 100%; min-height: 160px;
  background: linear-gradient(135deg, rgba(58,117,196,0.15), rgba(58,119,40,0.1));
  display: flex; align-items: center; justify-content: center;
  color: rgba(255,255,255,0.2); font-size: 0.75rem; letter-spacing: 0.1em;
  text-transform: uppercase;
}
.gallery-item:hover img { transform: scale(1.05); }
.gallery-overlay {
  position: absolute; inset: 0;
  background: linear-gradient(to top, rgba(0,0,0,0.7) 0%, transparent 50%);
  opacity: 0; transition: opacity 0.3s;
  display: flex; align-items: flex-end; padding: 1rem;
}
.gallery-item:hover .gallery-overlay { opacity: 1; }
.gallery-overlay span { font-size: 0.8rem; font-weight: 600; }

/* ─── Footer ─────────────────────────────────────────────────── */
footer {
  background: #080d14;
  border-top: 1px solid var(--card-border);
  padding: 3rem 2rem 1.5rem;
}
.footer-inner {
  max-width: 1200px; margin: 0 auto;
  display: grid; grid-template-columns: 2fr 1fr 1fr; gap: 3rem;
  margin-bottom: 2.5rem;
}
.footer-brand { display: flex; align-items: center; gap: 0.75rem; margin-bottom: 1rem; }
.footer-brand img { width: 40px; }
.footer-brand span { font-family: var(--font-head); font-size: 1rem; color: var(--gold); }
.footer-desc { font-size: 0.85rem; color: rgba(255,255,255,0.45); line-height: 1.7; }
footer h4 { font-size: 0.8rem; letter-spacing: 0.15em; text-transform: uppercase; color: var(--gold); margin-bottom: 1rem; }
footer ul { list-style: none; }
footer ul li { margin-bottom: 0.6rem; }
footer ul li a { font-size: 0.875rem; color: rgba(255,255,255,0.5); transition: color 0.2s; }
footer ul li a:hover { color: var(--white); }
.footer-bottom {
  max-width: 1200px; margin: 0 auto;
  display: flex; align-items: center; justify-content: space-between;
  padding-top: 1.5rem; border-top: 1px solid var(--card-border);
  font-size: 0.8rem; color: rgba(255,255,255,0.3);
}

/* ─── Responsive ─────────────────────────────────────────────── */
@media (max-width: 900px) {
  .about-grid { grid-template-columns: 1fr; }
  .about-coa { order: -1; }
  .tournament-card { grid-template-columns: 1fr; }
  .tournament-emblem { display: none; }
  .gallery-grid { grid-template-columns: repeat(2, 1fr); }
  .gallery-item:first-child { grid-column: span 2; }
  .footer-inner { grid-template-columns: 1fr; gap: 2rem; }
  .nav-links { display: none; }
}
@media (max-width: 600px) {
  .hero h1 { font-size: 2rem; }
  .gallery-grid { grid-template-columns: repeat(2, 1fr); }
  .hero-actions { flex-direction: column; align-items: center; }
}
```

**Step 2: Verify file is at the right path**

```bash
ls -la /var/www/gsf/assets/style.css
```
Expected: file exists.

---

### Task 4: Create the landing page HTML

**Files:**
- Create: `/var/www/gsf/index.html`

**Step 1: Write the HTML**

Create `/var/www/gsf/index.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Gambia Scrabble Federation — Tournament Portal</title>
  <meta name="description" content="Official tournament portal of the Gambia Scrabble Federation. Live pairings, standings, and scores.">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@700;800&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="/assets/style.css">
</head>
<body>

<!-- Flag stripe top -->
<div class="flag-stripe" aria-hidden="true">
  <div class="s1"></div><div class="s2"></div>
  <div class="s3"></div><div class="s4"></div>
  <div class="s5"></div>
</div>

<!-- Navigation -->
<nav class="nav" role="navigation">
  <div class="nav-inner">
    <a href="/" class="nav-brand">
      <img src="/assets/coat-of-arms.svg" alt="Gambia coat of arms">
      GSF
    </a>
    <div class="nav-links">
      <a href="#about">About</a>
      <a href="#tournament">Tournament</a>
      <a href="#rankings">Rankings</a>
      <a href="#news">News</a>
      <a href="#gallery">Gallery</a>
      <a href="/tournament" class="nav-cta">Live Portal →</a>
    </div>
  </div>
</nav>

<!-- Hero -->
<section class="hero" role="banner">
  <div class="hero-stripes" aria-hidden="true">
    <div class="hs1"></div><div class="hs2"></div>
    <div class="hs3"></div><div class="hs4"></div>
    <div class="hs5"></div>
  </div>
  <img src="/assets/coat-of-arms.svg" alt="Gambia coat of arms" class="hero-coa">
  <p class="hero-eyebrow">The Gambia Scrabble Federation</p>
  <h1>Where Words<br>Build Nations</h1>
  <p class="hero-sub">
    Official home of competitive Scrabble in The Gambia. Live tournament pairings,
    standings, and the national player rankings — all in one place.
  </p>
  <div class="hero-actions">
    <a href="/tournament" class="btn-primary">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polygon points="5 3 19 12 5 21 5 3"/></svg>
      Enter Tournament Portal
    </a>
    <a href="#about" class="btn-secondary">
      Learn About GSF
    </a>
  </div>
  <div class="hero-scroll" aria-hidden="true">Scroll</div>
</section>

<!-- About -->
<section id="about">
  <div class="container">
    <div class="about-grid">
      <div class="about-text">
        <p class="section-label">About Us</p>
        <h2 class="section-title">Gambia Scrabble Federation</h2>
        <p>
          The Gambia Scrabble Federation (GSF) is the national governing body for
          competitive Scrabble in The Gambia, affiliated with the World English-language
          Scrabble Players' Association (WESPA).
        </p>
        <p>
          We organise national championships, develop junior talent, and represent
          Gambian players at regional and international tournaments. Our mission is to
          grow the game across every region of the country.
        </p>
        <div class="stats-row">
          <div class="stat">
            <div class="stat-num">15+</div>
            <div class="stat-label">Nationals Held</div>
          </div>
          <div class="stat">
            <div class="stat-num">100+</div>
            <div class="stat-label">Registered Players</div>
          </div>
          <div class="stat">
            <div class="stat-num">2005</div>
            <div class="stat-label">Founded</div>
          </div>
        </div>
      </div>
      <div class="about-coa">
        <img src="/assets/coat-of-arms.svg" alt="Coat of Arms of The Gambia">
      </div>
    </div>
  </div>
</section>

<!-- Tournament -->
<section id="tournament">
  <div class="container">
    <p class="section-label">Current Event</p>
    <h2 class="section-title">Live Tournament</h2>
    <p class="section-intro">
      Follow the action as it happens. Pairings, scores, and standings update live
      during every round.
    </p>
    <div class="tournament-card">
      <div>
        <div class="tournament-badge">Live Now</div>
        <div class="tournament-name">GSF Nationals 2025</div>
        <div class="tournament-date">November 28–29, 2025 · Banjul, The Gambia</div>
        <div class="tournament-links">
          <a href="/tournament" class="tlink primary">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polygon points="5 3 19 12 5 21 5 3"/></svg>
            Enter Portal
          </a>
          <a href="/tournament/division/a/index.html" class="tlink">📊 Standings</a>
          <a href="/tournament/A-pairings-001.html" class="tlink">🃏 Pairings</a>
        </div>
      </div>
      <div class="tournament-emblem">
        <img src="/assets/coat-of-arms.svg" alt="">
      </div>
    </div>
  </div>
</section>

<!-- Rankings -->
<section id="rankings">
  <div class="container">
    <p class="section-label">National Rankings</p>
    <h2 class="section-title">Player Rankings</h2>
    <p class="section-intro">Current national rankings updated after each sanctioned event.</p>
    <div class="rankings-frame-wrap">
      <div class="rankings-frame-header">
        <span>Division A — Live Ratings</span>
        <a href="/tournament/division/a/index.html" target="_blank">Open full report ↗</a>
      </div>
      <iframe
        src="/tournament/division/a/index.html"
        class="rankings-iframe"
        title="National Player Rankings"
        loading="lazy">
      </iframe>
    </div>
  </div>
</section>

<!-- News -->
<section id="news">
  <div class="container">
    <p class="section-label">Latest</p>
    <h2 class="section-title">News &amp; Announcements</h2>
    <div class="news-grid">
      <div class="news-card">
        <span class="news-tag tag-tournament">Tournament</span>
        <h3>GSF Nationals 2025 — Registration Open</h3>
        <p>Registration for the 2025 Gambia Scrabble Nationals is now open. The tournament will be held in Banjul on November 28–29.</p>
        <div class="news-date">November 2025</div>
      </div>
      <div class="news-card">
        <span class="news-tag tag-results">Results</span>
        <h3>Gambia Dominates Regional Cup 2025</h3>
        <p>GSF players claimed three podium spots at the West Africa Regional Scrabble Cup, with strong performances across all divisions.</p>
        <div class="news-date">October 2025</div>
      </div>
      <div class="news-card">
        <span class="news-tag tag-announcement">Announcement</span>
        <h3>New Junior Development Programme Launched</h3>
        <p>The GSF is launching a nationwide junior Scrabble development programme targeting players under 18, in partnership with schools across the country.</p>
        <div class="news-date">September 2025</div>
      </div>
    </div>
  </div>
</section>

<!-- Gallery -->
<section id="gallery">
  <div class="container">
    <p class="section-label">Gallery</p>
    <h2 class="section-title">Tournament Moments</h2>
    <p class="section-intro">Drop photos into <code>/var/www/gsf/assets/gallery/</code> and replace the placeholders below.</p>
    <div class="gallery-grid">
      <div class="gallery-item">
        <div class="gallery-placeholder">Feature Photo</div>
        <div class="gallery-overlay"><span>GSF Nationals 2025 — Opening Ceremony</span></div>
      </div>
      <div class="gallery-item">
        <div class="gallery-placeholder">Photo</div>
        <div class="gallery-overlay"><span>Round 1 Pairings</span></div>
      </div>
      <div class="gallery-item">
        <div class="gallery-placeholder">Photo</div>
        <div class="gallery-overlay"><span>Top Board</span></div>
      </div>
      <div class="gallery-item">
        <div class="gallery-placeholder">Photo</div>
        <div class="gallery-overlay"><span>Prize Giving</span></div>
      </div>
      <div class="gallery-item">
        <div class="gallery-placeholder">Photo</div>
        <div class="gallery-overlay"><span>Junior Players</span></div>
      </div>
    </div>
  </div>
</section>

<!-- Footer -->
<footer>
  <div class="footer-inner">
    <div>
      <div class="footer-brand">
        <img src="/assets/coat-of-arms.svg" alt="GSF">
        <span>Gambia Scrabble Federation</span>
      </div>
      <p class="footer-desc">
        The national governing body for competitive Scrabble in The Gambia.
        Affiliated with WESPA.
      </p>
    </div>
    <div>
      <h4>Portal</h4>
      <ul>
        <li><a href="/tournament">Live Tournament</a></li>
        <li><a href="/tournament/division/a/index.html">Standings</a></li>
        <li><a href="#rankings">Rankings</a></li>
      </ul>
    </div>
    <div>
      <h4>Federation</h4>
      <ul>
        <li><a href="#about">About GSF</a></li>
        <li><a href="#news">News</a></li>
        <li><a href="mailto:info@gambiascrabblefederation.net">Contact</a></li>
      </ul>
    </div>
  </div>
  <div class="footer-bottom">
    <span>© 2025 Gambia Scrabble Federation. All rights reserved.</span>
    <span>Powered by <a href="https://github.com/esaye/-TSH-" style="color:rgba(255,255,255,0.5)">TSH</a></span>
  </div>
  <div class="flag-stripe" style="margin-top:1.5rem" aria-hidden="true">
    <div class="s1"></div><div class="s2"></div>
    <div class="s3"></div><div class="s4"></div>
    <div class="s5"></div>
  </div>
</footer>

</body>
</html>
```

**Step 2: Verify file exists**

```bash
ls -lh /var/www/gsf/index.html
```
Expected: file ~8-10KB

---

### Task 5: Enable TSH web server

**Files:**
- Modify: `GSF-Nationals-2026/config.tsh` — add `config port = 7779`
- Create: `start-tsh-server.sh`

**Step 1: Add port config to TSH tournament**

Add at the end of `Development/TSH/GSF-Nationals-2026/config.tsh`:
```
config port = 7779
```

**Step 2: Create startup script**

Create `/home/ebrimasaye/Development/TSH/start-tsh-server.sh`:

```bash
#!/bin/bash
# Start TSH web server for GSF Nationals
cd /home/ebrimasaye/Development/TSH
exec perl tsh.pl GSF-Nationals-2026
```

```bash
chmod +x /home/ebrimasaye/Development/TSH/start-tsh-server.sh
```

**Step 3: Verify TSH starts and listens**

In one terminal:
```bash
cd /home/ebrimasaye/Development/TSH && perl tsh.pl GSF-Nationals-2026 &
sleep 3
curl -s http://localhost:7779/ | head -5
```
Expected: HTML from TSH (or a TSH index page). Kill background process after test.

---

### Task 6: Update Cloudflared config

**Files:**
- Modify: `/home/ebrimasaye/.cloudflared/config.yml`

**Step 1: Add new ingress rule**

Update `~/.cloudflared/config.yml` — add the GSF hostname **before** the catch-all:

```yaml
tunnel: 3205f896-0c3c-4a5d-99f9-a923bac2c2cb
credentials-file: /home/ebrimasaye/.cloudflared/3205f896-0c3c-4a5d-99f9-a923bac2c2cb.json
protocol: http2

ingress:
  - hostname: music.ebrimasaye.com
    service: http://localhost:8096
    originRequest:
      noTLSVerify: true
  - hostname: scrabble.gambiascrabblefederation.net
    service: http://localhost:80
  - service: http_status:404
```

**Step 2: Verify config is valid**

```bash
cloudflared tunnel ingress validate
```
Expected: `Validating rules from /home/ebrimasaye/.cloudflared/config.yml` with no errors.

**Step 3: Add DNS route via Cloudflare dashboard or CLI**

```bash
cloudflared tunnel route dns 3205f896-0c3c-4a5d-99f9-a923bac2c2cb scrabble.gambiascrabblefederation.net
```
Expected: `Added CNAME scrabble.gambiascrabblefederation.net...`

**Step 4: Restart cloudflared**

```bash
sudo systemctl restart cloudflared
sudo systemctl status cloudflared
```
Expected: `active (running)`

---

### Task 7: End-to-end verification and commit

**Step 1: Test local Apache serves the landing page**

```bash
curl -s http://localhost/ | grep -o '<title>.*</title>'
```
Expected: `<title>Gambia Scrabble Federation — Tournament Portal</title>`

**Step 2: Test proxy to TSH works (once TSH is running)**

```bash
curl -s http://localhost/tournament/ | head -10
```
Expected: HTML from TSH server.

**Step 3: Test live domain**

```bash
curl -s https://scrabble.gambiascrabblefederation.net/ | grep -o '<title>.*</title>'
```
Expected: `<title>Gambia Scrabble Federation — Tournament Portal</title>`

**Step 4: Commit all files**

```bash
git add Development/TSH/GSF-Nationals-2026/config.tsh
git add Development/TSH/start-tsh-server.sh
git add Development/TSH/docs/
git commit -m "feat: add GSF portal landing page, Apache config, and TSH server setup"
```
