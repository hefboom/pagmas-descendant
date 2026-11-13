# examples/descendant

The rare book: the smallest working descendant. One harness (`claude-code`), one
cellar scope (`global`), three skills (`hello`, `prime-forge`, `systems-architect`), one tool (`doc-section`), one agent (`shim`, in six variants), one
manifest that elects them. `scripts/init.sh` copies this tree into a fresh repo.

Render it in place without installing anything:

```bash
FORGE_ROOT=$PWD/examples/descendant just render --check   # from the pagma repo root
```
