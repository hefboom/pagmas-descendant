# examples/descendant

The rare book: the smallest working descendant. One harness (`claude-code`), two cellar scopes (`global`, and `hub` for the descendant itself), five skills (`hello`, `prime-forge`, `systems-architect`; `pagma-update` and `pagma-uninstall` in `hub`), one tool (`doc-section`), one agent (`shim`, in six variants), one
manifest that elects them. `scripts/init.sh` copies this tree into a fresh repo.

Render it in place without installing anything:

```bash
FORGE_ROOT=$PWD/examples/descendant just render --check   # from the pagma repo root
```
