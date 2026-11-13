# pagma-descendant

A template for a [pagma](https://github.com/hefboom/pagma) descendant: your own
versioned cellar of agent skills and subagents, with the engine already mounted at
`forge/engine/` (pagma v0.1.1, a git subtree pinned by tag).

*Use this template* on GitHub, clone the result, then:

```bash
just forge install && just forge render        # needs bun, just, jq, fzf, python3
ln -s "$PWD/home/claude/skills" ~/.claude/skills
ln -s "$PWD/home/claude/agents" ~/.claude/agents
just forge status
```

Or hand the setup to a coding agent, in the clone:

```
Install pagma here: read and follow https://github.com/hefboom/pagma/blob/main/INSTALL.md
```

What is here: `forge/elections.json` (the manifest, one harness, one skill elected), the
`hello` skill and the `shim` agent as the first cellar entries, a root `justfile` that
mounts the engine's verbs under `just forge`. The mechanism, the authoring loop and the
upgrade path are in the engine's [README](https://github.com/hefboom/pagma#readme).
