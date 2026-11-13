# pagma

Your own package manager for AI skills, agents and the tools they call. One repo holds
every version you have written, a manifest says which version is live and where, and one
command makes it so.

It is for people who already write skills for Claude Code and have started to feel the
mess.

## The mess it clears up

I built this out of friction I kept hitting while learning skills, agents, models and
harnesses:

- **Copies drift.** I improved a skill in one repo and the copy in another stayed old.
  Then the other way round.
- **The global folder bloats every session.** Keeping everything in `~/.claude/skills`
  stops the drift, but then every session in every repo loads every description, and the
  context window pays for skills that repo never uses.
- **Trying a variation means one more copy.** The same skill on a stronger model, at
  another effort level, with a different tool: each experiment was another file to drift.
- **A fix can make a skill worse.** A patch that reads better can perform worse. Git can
  bring the old text back, but with enough friction that I rarely did.

pagma is what I ended up with: one hub that everything is managed from, and that you can
keep building on. Skills, prompt templates and the tools paired with them are your own
body of work. They deserve a place where they are kept, versioned and improved for years.

## What you get

| The friction | With pagma |
|---|---|
| copies drift between repos | one source per skill, in the hub. A repo does not hold a copy: it links to output built from that source, so there is nothing to keep in sync |
| global skills bloat the context | aim a skill at one repo and only sessions in that repo load it. Global is for what you want everywhere |
| a new version might be worse | every version stays on disk in its own folder. Making another one live, newer or older, is one command |
| testing on another model or effort | a skill names a tier (`lightweight`, `workhorse`, `sota`), not a model. Move one skill to another tier with one command, or change what a tier means for all of them in one place |
| the agent manages skills at random | every action is a command with exact arguments, built for an agent to run, and `/prime-forge` teaches your agent the whole system in one step |

I lean on AI to write my skills, so mistakes had to be cheap: nothing is overwritten, and
the version that worked is always one command away.

## Install

Open your coding agent in the folder that should become your hub, a new empty one is
fine, and paste:

```
Install pagma here: read and follow https://github.com/hefboom/pagma/blob/main/INSTALL.md
```

Or clone this repo and type `/pagma-install` in Claude Code inside it. That way it asks
where the hub should live and suggests `~/pagmas-descendant`.

The agent shows you a plan and waits for your go-ahead before it changes anything. Then it:

- installs the tools that are missing (`bun`, `just`, `jq`, `fzf`)
- sets up your hub: a git repo with the engine inside and a starter set of skills. The
  docs call the hub a *descendant*
- links `~/.claude/skills`, `agents` and `tools` to the hub's output. If you already have
  skills there, it offers to adopt them as `v1.0.0`, and it keeps your original folder
- writes down everything it created, so that `/pagma-uninstall` can remove exactly that
  and tell you when nothing is left

<details>
<summary>Without an agent, or by hand</summary>

Start from the template, [hefboom/pagmas-descendant](https://github.com/hefboom/pagmas-descendant):
*Use this template*, then clone it. Or build the hub yourself. You need `bun`, `just`,
`jq`, `fzf` and `git`:

```bash
mkdir pagmas-descendant && cd pagmas-descendant && git init && git commit --allow-empty -m init
git subtree add --prefix forge/engine https://github.com/hefboom/pagma.git v0.1.30 --squash
bash forge/engine/scripts/init.sh          # manifest, starter set, justfile, first render
just forge status                          # one row per election, LIVE column says ok
ln -s "$PWD/home/claude/skills" ~/.claude/skills    # and the same for agents and tools
```

`init.sh` never touches your home folder. The links are yours to make.

</details>

## Using it

The workflow is short. In any repo:

1. Run `/prime-forge`. Your agent now knows how the hub works, what is live, and how the
   hub relates to your other repos.
2. Ask for what you want.

A good moment is a tedious step you keep doing by hand, or one the agent does differently
every time. Committing, for example. Commit the way you like it a few times, then:

```
Look at how I wrote my last commits and break the pattern down. Then run /prime-forge.
After that I want to work out, with you, a skill that commits the way I do.
```

The agent writes the skill into the hub as `v1.0.0` and makes it live; your next session
has it. Want a change? It writes `v1.0.1` beside the first and switches to it. Turned out
worse? Tell it to go back, and `v1.0.0` is live again. Both versions stay on disk.

Everything the agent does, you can do by hand with a picker. Try it once: you will know
what your agent can do because you have done it yourself.

| By hand | What an agent runs | Does |
|---|---|---|
| `just forge view` | `just forge show <label>` | shows one skill: its versions, which is live, its tier |
| `just forge elect` | `just forge elect-exact <label> <version>` | makes a version live |
| `just forge move` | `just forge move-exact <label> <scope>` | moves a skill between global and one repo |
| `just forge retire` | `just forge retire-exact <label>` | takes a skill out of service and keeps its versions |

### Starter set

What a fresh hub holds. It is copied once and is yours from then on: change it, version
it, retire it.

| Name | Kind | What it is for |
|---|---|---|
| `prime-forge` | skill | teaches a fresh agent how the hub works and what is live, so it can write, version and switch skills for you. Run it first, then ask your agent anything |
| `systems-architect` | skill | takes a system, a document or a design apart into its working parts, how they act on each other, and one governing analogy. Tag the topic `understand`, `debug` or `audit`. Runs on the top tier. To run it in a subagent, spawn `sota` and name the skill |
| `hello` | skill | the smoke test: one line that proves the hub works end to end |
| `doc-section` | tool | reads one section of a markdown file by its heading. `prime-forge` uses it to load only the parts of `AUTHORING.md` it needs |
| `lightweight`, `workhorse`, `sota` | agents | nothing but a model tier: spawn one to run a prompt, or a named skill, on that tier |
| `lightweight-ro`, `workhorse-ro`, `sota-ro` | agents | the same three with the editing tools removed: they report and never change files |

## How it works

```text
forge/skills/global/commit/v1.0.1/SKILL.md    the cellar: every version, never edited again
        ↓  forge/elections.json: global/commit → v1.0.1
        ↓  just forge render
home/claude/skills/commit/SKILL.md            the output: rebuilt on every render
        ↑  ~/.claude/skills links here, made once at install
```

Three parts. The **cellar** stores every version as its own folder. The **manifest** is
one file that says which version is live and where. **Render** builds the folders your
harness reads from those two, and `just forge render --check` proves the output still
matches. The storage idea is Homebrew's Cellar; the build step is a compiler's.

A skill in the `global` scope reaches every session. A skill scoped to one repo is
rendered for that repo alone, and the repo holds a single link to it.

[`AUTHORING.md`](./AUTHORING.md) has the whole model: layout, tiers, tools, agents,
naming, and the commands for each step.

## Update and uninstall

- **Update:** `/pagma-update` in the hub. It shows what changed between your version and
  the newest, asks, then applies it. New starter content is offered, never forced.
- **Uninstall:** `/pagma-uninstall`. It walks the record the install kept, asks per item,
  and ends by telling you that nothing remains. Your own skills are never removed without
  an explicit yes.

Any other agent can do the same from [`UPDATE.md`](./UPDATE.md) and
[`UNINSTALL.md`](./UNINSTALL.md).

## Status

- **Harness:** Claude Code. The manifest is keyed by harness so that others can follow;
  none is built yet.
- **Systems:** macOS and Linux. Windows works natively through Git Bash, which Claude
  Code already uses there; it is new and still being proven (`install/windows.md`), and
  aiming a skill at one repo does not run on Windows yet.
- **Testing versions against each other:** today you switch and try. A harness that runs
  and compares versions is planned.
- **Stability:** before v1 there is no promise. I run my own setup on this exact engine
  every day, pinned by tag. The manifest's shape and the `-exact` commands are the parts
  least likely to move.
- Issues and patches are welcome. The harvest, stamp and keg scripts in `scripts/` belong
  to my own publishing pipeline and are not general yet.

## The name

Pagma is the legendary blacksmith in *Overgeared*. Your hub is his *descendant*: it
carries the engine inside and takes its updates from it. The scaffold a new hub starts
from is the *rare book*. Those two nouns are the whole borrowed vocabulary. The commands
stay plain, and they say `forge` because that is the folder the hub works in.

## Docs

- [`AUTHORING.md`](./AUTHORING.md): how the hub works once installed, and how to write,
  version and release a skill in it. What `prime-forge` reads.
- [`INSTALL.md`](./INSTALL.md), [`UPDATE.md`](./UPDATE.md), [`UNINSTALL.md`](./UNINSTALL.md):
  the three procedures, written for the agent that carries them out.
- [`CHANGELOG.md`](./CHANGELOG.md): one entry per tag.
- [`scripts/README.md`](./scripts/README.md): every script and the full manifest contract.
- [`examples/descendant/`](./examples/descendant/): the rare book, readable in two minutes.

MIT, see [LICENSE](./LICENSE).
