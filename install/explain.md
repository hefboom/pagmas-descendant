# Why each piece is there

Part of `INSTALL.md`: read this when the person picks "Explain first".

## The layout

An explanation is a list of blocks, one block per piece. The blocks below are already in
that layout: copy the ones that were asked for.

| Part of a block | Rule |
|---|---|
| the name | alone on its own line, in bold |
| under it | two to four lines, each starting with a dash, one fact per line |
| the last of those lines | what stops without the piece: `without it: …` |
| between blocks | one blank line |

| The person asks for | You write |
|---|---|
| one tool, or one file | that block |
| one row of the plan | the block of every piece in that row |
| all of it | every block below, in the order below |
| something with no block here | a block in the same layout, from what you read during this install (for an installer script, the script itself and `install/installers.md`). Leave the `without it` line out when the thing is not a piece pagma needs. Say so when you do not know |

Never a paragraph, never two pieces in one sentence, and no table: sentences in table
cells wrap badly in a terminal. You may swap a word for the one the person used; do not
merge lines or drop the `without it` line of a block below.

The blocks are ordinary message text, the last thing you write before the question, and
never an option's preview pane. Then ask the four choices again.

## The blocks

Explain from these, not from memory.

**git**
- mounts the engine inside your hub, pinned to a version tag
- an update pulls the next tag
- without it: no install and no update

**bun**
- runs the renderer: the program that turns the manifest (the list of what is live) into the skill and agent files your harness reads
- without it: nothing renders

**just**
- the command runner: every pagma command (`just forge render`, `status`, `elect-exact`) is a recipe it runs
- the engine's recipe file needs version 1.31 or newer
- without it: no commands

**jq**
- reads and edits the manifest, `forge/elections.json`, inside those commands
- writes the ledger
- without it: you cannot change which version of a skill is live

**fzf**
- the pickers in the commands you run by hand (`view`, `elect`, `move`, `retire`, `discover`)
- each is the by-hand twin of a command your agent runs with arguments (`show`, `elect-exact`, `move-exact`)
- pagma is built to be driven by agents; fzf is for you, to see and try what your agent can do
- without it: the agent's commands still work and you lose the pickers. Recommended, and the setup check asks for it

**python3**
- one read-only report, `just forge edges`
- without it: only that report stops; the setup check notes it and carries on

**`~/.config/pagma/env`**
- records where your hub is (`FORGE_ROOT`)
- puts bun and just on your `PATH`, since both install outside the default one (not on Windows, where winget does that)
- without it: new shells find neither the tools nor the hub

**the rc lines**
- one line in each shell startup file, which reads the env file
- two files, because login shells and the shells that tools start read different ones
- without them: the env file is never read

**the ledger**
- the record of everything this install creates or changes
- uninstall walks it, so removal is exact and can end on "nothing remains"
- without it: uninstall has to inspect the machine instead

**the descendant**
- the hub: the one repo all your skills and agents are managed from
- holds every version you write, the manifest of which version is live, and the engine mounted inside
- a skill made live there is global, or aimed at one repo
- without it: nowhere for your skills to live, and nothing to choose from

**the manifest**
- one file in your hub, `forge/elections.json`: which version of each skill, agent and tool is live, and where (every session, or one repo)
- rendering writes exactly that list into the folders your harness reads; what is not on the list is not there
- you change it with a command (`just forge elect-exact <skill> <version>`); a change that would not render is refused and the file stays as it was
- without it: nothing says what should be live, so nothing renders

**the three links**
- your harness reads `~/.claude/…`; the engine renders inside the hub
- the links join the two
- without them: the harness sees no rendered skills
