# Multi-Place Setup (Lobby + GameServer)

This repo builds **two Roblox places out of one codebase**: a **Lobby** and a **GameServer**.
They share all common infrastructure (everything in `ReplicatedStorage` plus the Wally
package folders) and differ only in their server/client code. You serve each place
independently with Argon.

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
│   ├── Shared/             ReplicatedStorage — used by BOTH places
│   │   ├── ReplicatedModules/
│   │   ├── Remotes/
│   │   └── ReplicatedAssets/
│   ├── Lobby/
│   │   ├── Server/         ServerScriptService (Lobby only)
│   │   └── Client/         StarterPlayerScripts (Lobby only)
│   └── GameServer/
│       ├── Server/         ServerScriptService (GameServer only)
│       └── Client/         StarterPlayerScripts (GameServer only)
├── Packages/               Wally shared deps   — used by BOTH places
├── ServerPackages/         Wally server deps   — used by BOTH places
├── lobby.project.json
└── gameserver.project.json
```

Both project files map `ReplicatedStorage → src/Shared`, `…/Packages → Packages`, and
`ServerScriptService/ServerPackages → ServerPackages`. The only difference between them is
which `Server`/`Client` folders feed `ServerScriptService` and `StarterPlayerScripts`.

> Requires in this codebase use **absolute service paths**
> (`game:GetService("ServerScriptService"):WaitForChild("SaveHandler")`), not file paths. Moving
> a folder **within the same service** — like `src/Server` → `src/Lobby/Server`, both under
> `ServerScriptService` — leaves the instance tree unchanged, so no code changes. Moving a module
> **between `Shared` and a place folder is different**: it crosses services
> (`ReplicatedStorage` ↔ `ServerScriptService`/`StarterPlayerScripts`), which changes both its
> `require` path and whether it replicates to clients — so that code, and anything requiring it,
> must be updated.

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

- **Both places need it** (data modules, remotes, types, replicated assets, anything under
  `ReplicatedStorage`) → put it in `src/Shared/…`. One file, both places.
- **Only one place needs it** (lobby matchmaking, in-match combat) → put it under that place's
  `src/Lobby/…` or `src/GameServer/…`.

The GameServer folders ship empty (each holds a `.gitkeep` so the empty folder survives a fresh
clone; the `globIgnorePaths` entry in the project file keeps that marker out of the synced
tree). To
give the GameServer an entry point, drop a script in `src/GameServer/Server/`, e.g.
`Bootstrap.server.luau`. Add client code under `src/GameServer/Client/`. The `.gitkeep` can
stay or be deleted once a real file exists.

## Static analysis (sourcemap)

`luau-lsp` analyses against a sourcemap. Because there's no `default.project.json`, generate
it from a named project — use the Lobby project, which currently contains every place with
code:

```sh
rojo sourcemap lobby.project.json -o sourcemap.json
```

`sourcemap.json` is git-ignored and regenerated on demand. When you start writing GameServer
code, generate a second sourcemap from `gameserver.project.json` to analyse that tree.
