# Project instructions

## graphify knowledge graph — navigate before you read

`graphify-out/` holds a pre-built knowledge graph of this repo — every file,
class and symbol with its line number (~59x fewer tokens than reading sources).

**Before opening source files, in this order:**

1. `graphify-out/FILE_INDEX.md` — every file mapped to its community and its
   most connected symbols with line numbers. Usually enough to pick the one
   file worth opening, or to answer without opening any.
2. `graphify-out/wiki/index.md` — one short article per community, for
   architectural context.
3. `graphify explain "<symbol>"` · `graphify query "<question>"` ·
   `graphify path "<A>" "<B>"` — traversal when the index is not enough.

Read the actual source only when the graph lacks the detail you need (exact
code, formatting, behaviour added after the last graph build).

**After changing code**, refresh the graph so the next session does not have to
re-read everything:

```bash
graphify update .                                             # re-extract changed files
$(cat graphify-out/.graphify_python) graphify-out/tools/agent_index.py   # prune noise + rebuild FILE_INDEX.md
graphify export html                                          # refresh the visualisation
```
