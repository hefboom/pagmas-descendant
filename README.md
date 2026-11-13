# pagmas-descendant

A template for a [pagma](https://github.com/hefboom/pagma) descendant: your own
versioned cellar of agent skills and subagents, with the engine already mounted at
`forge/engine/` (pagma v0.1.31, a git subtree pinned by tag).

*Use this template* on GitHub, clone the result, then:

```bash
just forge install && just forge render        # needs bun, just, jq, fzf, python3 — or /pagma-install in Claude Code
ln -s "$PWD/home/claude/skills" ~/.claude/skills
ln -s "$PWD/home/claude/agents" ~/.claude/agents
ln -s "$PWD/home/claude/tools" ~/.claude/tools
ln -s "$PWD/home/claude/repos/hub/skills" .claude/skills    # the hub's own skills: /pagma-update, /pagma-uninstall
just forge status
```

Or hand the setup to a coding agent, in the clone:

```
Install pagma here: read and follow https://github.com/hefboom/pagma/blob/main/INSTALL.md
```

Later: `/pagma-update` to follow the engine's tags, `/pagma-uninstall` to leave.

What is here: `forge/elections.json` (the manifest, one harness), the starter set as the
first cellar entries (the `hello`, `prime-forge` and `systems-architect` skills, the
`doc-section` tool and the six tier agents; `pagma-update` and `pagma-uninstall` in the
`hub` scope, for sessions opened here),
a root `justfile` that
mounts the engine's verbs under `just forge`. The mechanism, the authoring loop and the
upgrade path are in the engine's [README](https://github.com/hefboom/pagma#readme).
