# Mastermind — Terminal Edition (API-Backed)

A colorful, emoji-rich Mastermind you can play in your terminal with two modes:

- **Online:** talks to the public Mastermind API (`https://mastermind.darkube.app`) for secret generation and scoring.  
- **Local:** lets you provide the secret and plays entirely on your machine.

The client tracks attempts, hints, history, and simple session stats. Output uses ANSI styling for a polished UX.

---

## Features

- **Two play modes:** Online (API) and Local (offline).
- **Smart hint:** lightweight suggestion based on your guess history.
- **History & give-up:** review past guesses or end the round.
- **Replay flow:** quick “play again / main menu / quit” prompts.
- **Stats persistence:** total games, best attempts, last round time saved to `~/.mastermind_stats.json`.
- **Portable Swift:** works on macOS, Linux, and Windows (Swift toolchain).

---

## How it works

### Online mode
- Creates a game via `POST /game`, receives a `game_id`.
- Each guess is sent to `POST /guess` with `{ game_id, guess }`.
- The server returns peg counts `{ black, white }`.
- On exit or give-up, the client calls `DELETE /game/{game_id}`.

> The server is intentionally minimal: it does not store attempts, elapsed time, or guess history. The client maintains all gameplay context and stats locally.

### Local mode
- You provide the secret (4 digits from 1–6).
- All scoring is computed locally with the same rules the server uses.

---

## Commands (during a game)

- `hint` — prints a suggestion based on prior feedback  
- `giveup` — terminates the current round (and online game if applicable)  
- `history` — shows all guesses with peg counts  
- `restart` — start a new round  
- `menu` — return to the main menu  
- `exit` — quit the app immediately

---

## Pegs & rules (quick refresher)

- Valid guess: **4 digits**, each **1–6**.
- Response shows pegs and numbers:
  - `⬛` (Black) = right digit in the right position.
  - `⚪` (White) = right digit in the wrong position.
- Win when you reach **4 black** pegs.

---

## Requirements

- Swift 5.7+ (recommended Swift 6+)
- Terminal with ANSI color support

The source uses:

- `Foundation` and `FoundationNetworking` (auto-imported on Linux)
- No 3rd-party dependencies

---

## Build & Run

### macOS / Linux
```bash
swiftc Mastermind.swift -o Mastermind
./Mastermind
```

Or run with the shebang:
```bash
chmod +x Mastermind.swift
./Mastermind.swift
```

### Windows
Install the Swift toolchain for Windows, then:
```powershell
swiftc Mastermind.swift -o Mastermind.exe
.\Mastermind.exe
```

> If you see networking errors on Linux, ensure `libcurl` is installed. On Windows, make sure the Swift runtime is on `PATH`.

---

## Usage

Launch the app and choose a mode:
```
Choose: 1) Online  2) Local  3) Stats  4) Help  5) Quit  →
```

- **Online:** the client contacts the API and starts a round.
- **Local:** you’ll be prompted to enter a valid secret (e.g., `1234`).

During play:
```
Attempt 1 -> 1122
Result: ⬛⚪  (B=1, W=1)
```

Type `hint`, `history`, `giveup`, `restart`, `menu`, or `exit` at any time.

---

## Stats

A small JSON file stores cumulative stats:

- `games`: total completed rounds
- `best_attempts`: fewest attempts taken to win
- `last_time`: duration (seconds) of the last completed round

Location: `~/.mastermind_stats.json` (the code uses your home directory via `FileManager.default.homeDirectoryForCurrentUser.path`).

---

## API Contract (used by the client)

Base URL: `https://mastermind.darkube.app`

- `POST /game` → `{"game_id": "<id>"}`  
- `POST /guess` with body `{"game_id":"<id>","guess":"1234"}` → `{"black":N,"white":M}`  
- `DELETE /game/{game_id}` → 204/200 on success

Errors return `{"error":"message"}`; the client prints a friendly error and keeps you in control.

---

## Troubleshooting

- **Network timeouts / empty response:** try again or switch to Local mode. The client uses short timeouts to keep the UI responsive.
- **Windows path formatting:** the stats file path may show mixed separators but will still be written correctly.
- **Swift 6 concurrency warnings:** this version uses a synchronous request pattern that avoids mutating multiple captured variables from a concurrent context.


