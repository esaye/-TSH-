# TSH — Tournament Shell

TSH is a Perl program for managing Scrabble tournaments. It handles player registration, round-by-round pairings, score entry, standings, ratings, and HTML report generation. It supports an interactive CLI shell and a web-server mode.

## Requirements

- Perl 5.8.1 or later (5.10+ recommended)
- On Windows: [Strawberry Perl](https://strawberryperl.com/)

## Installation

Download and extract the TSH distribution, then run from the `TSH/` directory. TSH resolves all paths relative to the working directory, so it must always be launched from the project root.

## Usage

```bash
# Start interactive shell for a tournament directory
./tsh.pl my-tournament/

# Example with a bundled sample
./tsh.pl sample2
```

At the TSH prompt, type `help` for a list of commands or `help <command>` for details on a specific command.

### Basic workflow

1. Create an event directory with a `config.tsh` file and one `.t` player file per division.
2. Enter player names and ratings into the `.t` files.
3. Run `./tsh.pl your-event/` and use the `pair` command to generate round pairings.
4. After each round, enter scores with the `addscore` command.
5. Use `standings`, `scoreboard`, and related commands to view results.
6. Use `exportratings` or `submit` to submit results to the relevant rating body.

## Running Tests

```bash
# Run all regression tests
perl util/regression.pl lib/test/*.txt

# Run a single test
perl util/regression.pl lib/test/addscore.txt
```

## Documentation

Full reference documentation is in `doc/`:

- `doc/intro.html` — Getting started
- `doc/install.html` — Installation instructions
- `doc/commands.html` — Command reference
- `doc/config.html` — Configuration options
- `doc/pairing.html` — Pairing theory
- `doc/all.html` — Single-page reference

## License

TSH was written by John Chew. Contact John Chew for licensing information.
