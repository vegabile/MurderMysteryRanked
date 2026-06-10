# Multi-Place Setup (Lobby + GameServer)

This repo builds **two Roblox places out of one codebase**: a **Lobby** and a **GameServer**.
They share a common `Shared` folder (plus the Wally package folders) and each has its own
server, client, and replicated content. You serve each place independently with Argon.

## How it works

Argon (like Rojo, which it's compatible with) treats **any `*.project.json` file** as a
project. A single repo can hold as many as you want. Each defines its own instance tree, but
they can all point `$path` at the same shared source folders — so the shared code is *one set
of files*, not copies. Edit it once, both places get it.

There are two project files:

| File | Place | Port | Place ID |
| --- | --- | --- | --- |
| `lobby.project.json` | Lobby | `8000` | `96463089590097` |
| `gameserver.project.json` | GameServer | `8001` | `87032497790232` |

The port and place ID live **inside** each project file, so the two can serve at the same
time without colliding, and the Argon plugin refuses to sync a project into a place whose ID
doesn't match (see [Place targeting](#place-targeting)).

## Folder layout

```
MMR/
├── src/
│   ├── Shared/                  → ReplicatedStorage.Shared (BOTH places; empty for now)
│   ├── Lobby/
│   │   ├── ReplicatedStorage/   → ReplicatedStorage.Lobby (Lobby-only replicated)
│   │   │   ├── ReplicatedModules/
│   │   │   ├── Remotes/
│   │   │   └── ReplicatedAssets/
│   │   ├── Server/              → ServerScriptService (Lobby only)
│   │   └── Client/              → StarterPlayerScripts (Lobby only)
│   └── GameServer/
│       ├── ReplicatedStorage/   → ReplicatedStorage.GameServer (GameServer-only)
│       ├── Server/              → ServerScriptService (GameServer only)
│       └── Client/              → StarterPlayerScripts (GameServer only)
├── Packages/                    Wally shared deps — used by BOTH places
├── ServerPackages/              Wally server deps — used by BOTH places
├── lobby.project.json
└── gameserver.project.json
```

Each project mounts `ReplicatedStorage` from three sources, as named children: `Shared`
(`src/Shared`, common to both places), the place's own folder (`Lobby` or `GameServer`, from
`src/<Place>/ReplicatedStorage`), and `Packages`. `ServerScriptService` likewise maps each
place's own `Server` folder, with the shared `ServerPackages` as a child. The places differ
only in their own `ReplicatedStorage`/`Server`/`Client` folders. So in-game a script reaches
shared content at `ReplicatedStorage.Shared.…` and place-specific replicated content at
`ReplicatedStorage.Lobby.…` (or `.GameServer.…`). The empty mounted folders — `Shared`, and the
GameServer's `ReplicatedStorage` — carry an `init.meta.json` declaring them a `Folder` so they
exist in-game even while empty; Lobby's `ReplicatedStorage` materializes from its own content.

> Requires use **absolute instance paths**
> (`ReplicatedStorage:WaitForChild("Lobby"):WaitForChild("ReplicatedModules")…`), not file
> paths — so the folder a script lives in on disk doesn't matter, only where it lands in the
> instance tree. A module's require path therefore includes its `ReplicatedStorage` sub-folder:
> moving a module between `src/Shared` and a place's `src/<Place>/ReplicatedStorage` changes its
> path from `ReplicatedStorage.Shared.X` to `ReplicatedStorage.<Place>.X` (and changes which
> places can see it), so that code — and anything requiring it — must be updated.

## Serving a place

Install Argon separately from the repo toolchain (the `aftman.toml` toolchain pins Rojo, not
Argon): see <https://argon.wiki>. Then, from the repo root:

```sh
argon serve lobby.project.json          # Lobby on :8000
argon serve gameserver.project.json     # GameServer on :8001
```

To run both at once, open two terminals — one per command. The ports come from the project
files, so you don't pass `--port`. Add `-A` / `--async` to release the terminal if you prefer.

Then in Roblox Studio:

1. Open the matching place (Lobby place, or GameServer place).
2. Open the **Argon** plugin and **Connect** (it points at `localhost` and the project's port).
3. The file tree syncs in. Enable **Two-Way Sync** in the plugin if you want Studio edits to
   write back to disk.

> The project files use Rojo-compatible field names (`servePort`, `servePlaceIds`,
> `globIgnorePaths`); Argon accepts these as aliases for its native `port` / `placeIds` /
> `ignoreGlobs`. That keeps the repo's pinned Rojo working too — `rojo serve lobby.project.json`
> and `rojo sourcemap lobby.project.json` read the same files.

## Place targeting

Each project file declares `servePlaceIds`. When you Connect the Argon plugin, it checks the
open place's ID against that list and **refuses to sync a project into a place whose ID isn't
listed** — so you can't accidentally push the Lobby tree into the GameServer place or
vice-versa. You still choose the right place and port yourself when you Connect; the list is a
guard, not an auto-selector.

If you re-publish either place and its ID changes, update the `servePlaceIds` array in the
corresponding project file. To also gate by the whole experience, add a `gameId` field (the
universe ID); it isn't required here because each `servePlaceIds` value already identifies one
place uniquely.

## Adding code: shared vs place-specific

- **Both places need it** (shared data modules, types) → `src/Shared/…` → appears at
  `ReplicatedStorage.Shared`. One file, both places.
- **One place's replicated content** (its UI data, remotes, assets) →
  `src/Lobby/ReplicatedStorage/…` or `src/GameServer/ReplicatedStorage/…` → appears at
  `ReplicatedStorage.Lobby` / `.GameServer`.
- **One place's server or client code** → `src/<Place>/Server/…` or `src/<Place>/Client/…`.

Empty mounted folders keep an `init.meta.json` so they exist as `Folder`s while empty (today
that's `Shared` and the GameServer's `ReplicatedStorage`); the empty `Server`/`Client`
scaffolds keep a `.gitkeep` (ignored via `globIgnorePaths`). To give the GameServer an entry point, drop a script in
`src/GameServer/Server/`, e.g. `Bootstrap.server.luau`.

## Static analysis (sourcemap)

`luau-lsp` analyses against a sourcemap. Because there's no `default.project.json`, generate
it from a named project — use the Lobby project, which currently contains every place with
code:

```sh
rojo sourcemap lobby.project.json -o sourcemap.json
```

`sourcemap.json` is git-ignored and regenerated on demand. When you start writing GameServer
code, generate a second sourcemap from `gameserver.project.json` to analyse that tree. Empty
folders (`Shared`, the GameServer `ReplicatedStorage`) are pruned from the sourcemap but still
exist in the built/synced place.
