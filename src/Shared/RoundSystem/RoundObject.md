# RoundObject

`RoundObject` is the authoritative state of a single competitive match: who is on which
team, who is alive, the score, and whether the match is over. It is pure logic with no
RemoteEvents, no teleporting, and no map loading — those are wired separately. It is the
brain a GameServer round runner drives; it does not drive itself.

## Match model

A match is **N teams**, each holding one or more players:

| Mode | Teams | Players per team |
| ---- | ----- | ---------------- |
| 1v1  | 2     | 1 |
| 2v2  | 2     | 2 |
| 3v3  | 2     | 3 |
| 4v4  | 2     | 4 |
| FFA  | one team per player | 1 |

A match is a sequence of **rounds**. Each round everyone spawns; players die until only
one team has anyone left alive; that team is awarded one point; the round resets and the
next one begins. The first team to reach `WinningScore` points wins the match
(`DefaultWinningScore = 5`).

The mode is never stored — it is derived from the team shape via `ClassifyMode`. The team
rosters come from the matchmaking/teleport payload, so the round object just receives the
already-formed teams through `AddPlayer`.

## Construction

```lua
RoundObject.new(teamCount: number?, winningScore: number?): RoundObject
```

- `teamCount` defaults to `2`. A value that is not an integer `>= 2` is rejected with a
  `warn` and falls back to `2`. For FFA pass the player count (e.g. `RoundObject.new(6)`).
- `winningScore` defaults to `DefaultWinningScore` (5). A non-positive-integer value is
  rejected with a `warn` and falls back to the default.
- `new` always returns a valid object (never `nil`), so existing callers using `new()` with
  no arguments keep working.

## Alive state is reactive, with one writer

The match never trusts a stored "is this player alive" flag from anywhere except the death
signal. At runtime the round runner connects each character's `Humanoid.Died` to
`round:MarkDead(player)`. `MarkDead` is the **only** writer of alive state and death
ordering:

- `MarkDead(player)` sets `isAlive = false` and records the death against the player's team
  with a strictly increasing counter, so each team remembers the order of its most recent
  death. It refuses (with a `warn`) to mark a player who is not in the round or who is
  already dead, so the counter never double-counts.
- `ResetRound()` re-arms everyone for the next round: `isAlive = true`, the per-team death
  records are cleared, and the death counter is reset to zero.
- `LogPlayerInfo` accepts only `{ Kills, Deaths }` and writes only those; alive state has
  no way in through it.
- `GetPlayerInfo` returns a snapshot **copy**, so a caller cannot reach in and flip
  `isAlive` behind `MarkDead`'s back.

Because alive state is derived from one signal and never duplicated, it cannot drift.

## Reading the round

- `IsTeamEliminated(teamIndex): boolean` — true when no member of the team is alive. This
  is the single definition of a dead team; everything else builds on it.
- `GetLivingTeams(): { number }` — indices of teams with at least one living member.
- `GetRoundOutcome(): RoundOutcome` — a pure read (no mutation). It returns
  `{ Status = "Ongoing" }` while two or more teams are alive, `{ Status = "Awarded",
  TeamIndex = i }` when exactly one team remains, and on a double knockout (zero teams
  alive) awards the team that died **last** by each team's recorded last-death order. If
  no team is alive and no deaths were recorded (e.g. an empty round) it stays `Ongoing`
  rather than awarding anyone.

Outcome detection is separated from scoring so it can be called freely (e.g. on every
death) without committing a point. The runner commits the point itself:

- `AwardPoint(teamIndex): boolean` — adds one point to a team (validated).
- `GetPoints(teamIndex): number?`
- `GetWinner(): number?` — the first team whose points reached `WinningScore`, else `nil`.
- `IsOver(): boolean`

A typical runner loop: on each death call `GetRoundOutcome`; if `Status == "Awarded"` call
`AwardPoint`, then either end the match (`IsOver`) or `ResetRound` and start the next round.

## Double knockout ("who died first")

If two teams are wiped in the same round, the point goes to whichever team's last death
happened later — i.e. the team that survived a fraction longer. The order comes from a
monotonic counter incremented once per death and recorded per team, so two deaths can never
share an order and a true tie cannot occur in practice. Holding the order at the team level
means it survives a dead player being removed from the round. If the data is ever malformed
and orders do tie, the lowest team index is awarded and a `warn` is emitted.

## Map-load gate (infrastructure, feature-locked)

`BeginGame` is the hook for "load the chosen map after the vote, then start the game once it
is loaded or a timeout elapses". It is wired but disabled by default:

```lua
RoundObject.MapLoadGateEnabled = false
RoundObject.DefaultMapLoadTimeout = 10
round:BeginGame(loadMap: (() -> boolean)?, timeout: number?): boolean
```

- `BeginGame` only starts from `PRE_GAME`.
- When `MapLoadGateEnabled` is true and a `loadMap` callback is supplied, it runs the
  callback in a protected task and waits (accumulating real elapsed time) until the load
  finishes or `timeout` seconds pass. It always proceeds to `GAME` afterwards — never
  blocking forever — and `warn`s the specific reason if it timed out, if the loader
  errored, or if the loader reported failure.
- When disabled (the default) or with no callback, it just transitions to `GAME`.

The `loadMap` callback is injected, so `RoundObject` stays decoupled from real map assets.
The vote winner is produced elsewhere (`MapVote:getWinner()`); wiring the vote result into a
`loadMap` and flipping `MapLoadGateEnabled` is the activation step.

## Mode classification

```lua
RoundObject.ClassifyMode(teamSizes: { number }): Mode?
```

Returns `"1v1".."4v4"` for two equal teams of size 1–4, `"FFA"` for three or more solo
teams, and `nil` (with a `warn`) for any other shape.

## Out of scope (wiring follow-ups, not in this module)

- Connecting `Humanoid.Died` to `MarkDead` and running the round loop.
- Removing HP healing (disable the default Humanoid regen).
- Making knife/gun hits reliably kill (set `Humanoid.Health = 0` on a confirmed hit).
- Building a real `loadMap` from the vote winner and enabling `MapLoadGateEnabled`.

## Testing

The pure decision logic is unit-tested under Lune in `tests/roundobject.spec.luau`
(`ClassifyMode`, `DecideOutcome`, `FindWinner`, and the score/win path). The player-bound
methods (`AddPlayer`, `MarkDead`, `GetRoundOutcome` over real rosters, `BeginGame`) require
real `Player`/`Humanoid` instances and are verified manually in Studio.
