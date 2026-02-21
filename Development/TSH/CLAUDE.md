# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Is

**TSH** (Tournament Shell) is a Perl-based Scrabble tournament management system. It manages player registration, round-by-round Swiss/bracket pairings, score entry, standings, and ratings submissions. It supports both an interactive CLI shell and a web-server mode.

## Running TSH

```bash
# Interactive shell (from project root, must run from TSH/ directory)
./tsh.pl [directory]

# Example with a sample tournament
./tsh.pl sample2

# Syntax-check a module without running
perl -c tsh.pl
perl -c tourney.pl
perl -c lib/perl/TSH/Division.pm
```

TSH must be run from the project root directory (`TSH/`) because it resolves `lib/` paths relative to `./`.

## Running Tests

Tests live in `lib/test/*.txt`. Each file is a self-contained test specifying config, input files, commands, expected stdout, and expected stderr in a structured text format.

```bash
# Run all regression tests (from TSH/ directory)
perl util/regression.pl lib/test/*.txt

# Run a single test file
perl util/regression.pl lib/test/addscore.txt

# Run with a plugin enabled
perl util/regression.pl --plugin <plugin-name> lib/test/somefile.txt

# Preserve temp directories on failure (useful for debugging)
perl util/regression.pl --preserve lib/test/addscore.txt
```

The runner spawns `./tsh.pl` as a subprocess and compares actual stdout/stderr against the expected values in each test file.

### Test File Format

```
#begintest <name> [null|...]
#beginconfig
  division <div> <file.t>
  config key = value
#endconfig
#beginifile <file.t>
  <player data lines>
#endifile
#begincommands
  <tsh commands>
  q
#endcommands
#beginstdout
  <expected output>
#endstdout
#beginstderr
  <expected stderr (usually empty)>
#endstderr
#endtest
```

## Architecture

### Entry Points

- **`tsh.pl`** — Interactive tournament shell. Loads config, instantiates `TSH::Tournament`, hands off to `TSH::Processor` for command loop.
- **`tourney.pl`** — Standalone calculation utility (pairing, standings math).
- **`get-tsh.pl`** — Self-updater / installer.
- **`ratings.pl` / `ratings2.pl`** — Legacy rating calculators.

### Core Module Hierarchy (`lib/perl/TSH/`)

| Module | Role |
|---|---|
| `Tournament.pm` | Top-level container: loads config, divisions, handles locking |
| `Config.pm` | Reads/writes `config.tsh`; manages all user-configurable options |
| `Division.pm` | All per-division logic: pairings, standings, score entry, boards |
| `Player.pm` | Per-player data: scores, ratings, board assignments, stats |
| `Processor.pm` | Command interpreter — runs the interactive REPL or server loop |
| `Command/` | ~130+ individual command implementations (one `.pm` per command) |
| `Utility.pm` | Debug tracing, color terminal output, shared helpers |
| `Log.pm` | Structured tournament logging |
| `PlugInManager.pm` | Loads plugins from `./plugins/` per `lib/plugins.txt` |
| `Server/` | HTTP server for web-based tournament access |
| `Report/` | Report generation (HTML standings, pairings, cross-tables) |

### Data Flow

1. `tsh.pl` starts → reads `config.tsh` via `TSH::Config` → creates `TSH::Tournament`
2. `TSH::Tournament` loads `.t` player files and instantiates `TSH::Division` objects
3. `TSH::Processor` runs a read-eval loop, dispatching text commands to `TSH::Command` subclasses
4. Each command mutates `Division`/`Player` state and writes updated `.t` files and HTML reports

### Tournament Data Files

- **`config.tsh`** — Tournament configuration (in each tournament directory)
- **`<division>.t`** — Player data for a division (space-delimited, one player per line)
- **`lib/ratings/<system>/`** — Rating lookup tables (NSA, NASPA-CSW, KEN, PAK, NOR)
- **`lib/messages.txt`** — Localized user-facing strings (English, DEU, NOR, POL)

### Pairing Strategies

`Division.pm` and `Command/` implement multiple pairing algorithms:
- **Swiss** (default) — standard Swiss with Gibson/spread adjustments
- **RoundRobin**, **Bracket**, **Cambridge**, **Chew**, **Factor**, **KOTH**, **AUPAIR**
- Bye assignment is configurable (top-down, bottom-up, always-bottom, team mode)

### Plugin System

External plugins extend the command set. Place plugin modules in `./plugins/`, register in `lib/plugins.txt`. The `TSH_PLUGINS` environment variable selects active plugins (used by the test runner).

## Key Development Notes

- **Perl 5.8.1+ required** (hardcoded `require 5.008_001` at top of `tsh.pl`).
- Threading is **optional**: TSH checks for `lib/threads.txt` at startup; if present, it `require`s `threads`.
- All paths are relative to the **working directory** at launch — always run from the `TSH/` project root.
- The `DEBUG` command at the TSH prompt enables verbose tracing (`TSH::Utility::DebugOn`).
- `doc/` contains comprehensive HTML reference documentation; `doc/all.html` is the single-page reference.
