from flask import Flask, jsonify, abort, request
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
    return jsonify([dict(r) for r in rows])

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
                    'ratings': [dict(r) for r in ratings],
                    'tournaments': [dict(t) for t in tournaments]})

# ── Rankings ──────────────────────────────────────────────────────────────────

@app.get('/api/rankings')
def rankings():
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
    return jsonify([dict(r) for r in rows])

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
    return jsonify([dict(r) for r in rows])

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
                    'divisions': [dict(d) for d in divisions],
                    'standings': [dict(s) for s in standings]})

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
    return jsonify([dict(r) for r in rows])

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
    return jsonify([dict(g) for g in games])

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=int(os.environ.get('FLASK_PORT', 5000)),
            debug=os.environ.get('FLASK_ENV') == 'development')
