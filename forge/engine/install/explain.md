# Why each piece is there

Part of `INSTALL.md`: read this when the person picks "Explain first".

Why each piece is there. Explain from this, not from memory:

| Piece | What pagma uses it for | Without it |
|---|---|---|
| `git` | mounts the engine inside the descendant as a subtree pinned to a tag; an update pulls the next tag | no install, no update |
| `bun` | runs the renderer, the TypeScript that turns the manifest into the skill and agent files the harness reads | nothing renders |
| `just` | the command runner: every verb (`just forge render`, `status`, `elect-exact`) is a recipe in the engine's justfile, which needs 1.31 for its syntax | no verbs |
| `jq` | reads and edits the manifest `forge/elections.json` inside the verbs, and writes the ledger | no election can change |
| `fzf` | the pickers in the interactive verbs (`view`, `elect`, `move`, `retire`, `discover`). Each is the hand-operated twin of a verb the agent runs (`show`, `elect-exact`, `move-exact`, …): the same engine, a picker in place of arguments. pagma is built to be driven by agents, and fzf is for the person: doing a step by hand once shows them what their agent can do | the agent's `-exact` verbs still work; the person loses the way to see and try them. Recommended, and the setup check asks for it |
| `python3` | one read-only report, `just forge edges` | only that report stops; the setup check notes it and carries on |
| `~/.config/pagma/env` | bun and just install outside the default `PATH`; this file puts them on it and records where the descendant is (`FORGE_ROOT`) | new shells find neither the tools nor the descendant |
| the rc lines | one line per startup file that reads the env file; two files because login shells and the shells tools start read different ones | the env file is never read |
| the ledger | the record uninstall walks, so removal is exact and can end on "nothing remains" | uninstall falls back to inspecting the machine |
| the descendant | the hub: the one repo every skill and agent is managed from. It holds every version the person writes, the manifest of which version is live, and the engine mounted inside. A skill elected there is global, or aimed at one repo | nowhere for their skills to live, nothing to elect from |
| the three links | the harness reads `~/.claude/…`, the engine renders inside the descendant; the links join the two | the harness sees no rendered skills |
