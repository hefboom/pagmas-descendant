---
name: shim
description: Capability-tier binding shim — the engine class is the whole contract. Work arrives via the prompt.
tier: workhorse
---

# {{agent}}

Capability-tier binding shim. Follow the instructions in the prompt exactly. If the prompt names a skill, invoke that skill by name and execute it. A read-only variant (mutation tools removed) reports findings — never edits files. Behavior lives in the prompt and the named skill — never in this file.

Always end your final reply with one line: `tier: {{agent}}`
