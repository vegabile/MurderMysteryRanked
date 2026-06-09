# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project
Language: write Luau, not generic Lua

Use the task library: task.wait, task.spawn, task.defer, task.delay.
NEVER use the deprecated wait(), spawn(), delay().
Do not invent Roblox APIs. If unsure a method/property exists or its signature,
stop and verify against the type definitions (luau-lsp preloads current Roblox types)
rather than guessing.
Prefer Luau idioms and type annotations over patterns translated from other languages.

Verification (do this every change — it is the most important rule)
You cannot run the game. Match the verification to the layer of code:

ALWAYS, after any edit: a clean static pass is the gate.

Types/analysis: luau-lsp analyze (run rojo sourcemap first if needed).
Lint: selene.
A change is not "done" until both pass with no new warnings.


Pure-logic modules (no Roblox API / runtime dependency — formulas, validation,
state machines, inventory math): cover with TestEZ tests and run them under Lune.
These are the ONLY unit-test targets.
Runtime / visual / network behavior (Workspace, RemoteEvents, tweens, UI, NPC
feel): you CANNOT verify this. Do not write engine-mocking tests and claim success.
Instead, end the task with a clean static pass plus a short, specific manual test
plan for the human to run in Studio (exact steps + expected result).


StyLua handles formatting automatically via hook — do not hand-format or reformat.

No comments

Do NOT write comments. This is a full ban: no inline comments, no block comments,
no doc comments, no commented-out code, no TODO/FIXME/NOTE markers, no section-header
banners. Code must explain itself through clear names and structure. If a piece of
logic is so unclear it seems to need a comment, rewrite it to be obvious instead.
Do not add comments to code you generate, and do not reintroduce comments when editing
existing code. The only exception is when the human explicitly asks for a comment in
a specific place. Leave comments already present in untouched code alone — removing
them is its own change and is out of scope unless asked.

Surgical changes & no overengineering

Touch ONLY what the task requires. No adjacent refactors, no renaming, no reformatting,
no "while I'm here" cleanup, no editing comments you weren't asked to change.
Write the minimum code that solves the problem. No speculative abstractions, no config
or "flexibility" that wasn't requested, no error handling for impossible cases.
No new frameworks, DI systems, or class hierarchies unless the task genuinely needs them
and I approve the approach in plan mode first. This is a game, not a platform.
Self-test: would a senior engineer call this overcomplicated? If 200 lines could be 50,
rewrite it. Prefer editing existing files over adding new ones.
Explore the codebase before changing it; reuse existing patterns instead of reinventing.

Git & PR discipline

Each task gets its own branch. Never commit straight to main.
Keep PRs small: one logical change per PR. If a plan spans multiple concerns,
split it into multiple branches/PRs.
Each commit is ONE coherent change. Name commits for what they do.
Never squash unrelated fixes into a single commit.
Where work is parallelizable, fan out with /batch into worktrees so independent
changes proceed concurrently.

Mandatory adversarial review loop before pushing

No change may be pushed until it has passed the codex adversarial reviewer. This is a
hard gate, not a suggestion. After implementing (and after the clean static pass), run
the adversarial reviewer provided via codex on the change. Address every finding —
make one focused commit per finding, named for that finding — then run the reviewer
again. Repeat this loop: review, fix, re-review, until the reviewer returns no
outstanding findings. Only once a full review pass comes back clean may you push. Never
push a change that has unaddressed review findings or that has not been reviewed since
its last edit.

Adversarial review focus (Roblox)
Static analysis already catches type errors and lint issues — don't just re-report those.
Point review at what tools can't see:

Client/server trust boundary: never trust client input. Validate on the server.
Flag any RemoteEvent/RemoteFunction handler that acts on unvalidated client data.
Race conditions and ordering across server/client and across task scheduling.
Memory/connection leaks: are signal :Connects and instances cleaned up?