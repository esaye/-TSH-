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
            t_files = [f for f in event_dir.glob('*.t') if f.name != 'config.t']
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

                    # Upsert latest rating (WESPA system)
                    cur.execute("SELECT id FROM rating_systems WHERE code = 'wespa'")
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
