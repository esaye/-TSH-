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
