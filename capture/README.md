# Demo capture

The demo pages in the documentation show what each demo prints and the figures it
draws. Producing that needs MATLAB, so it happens **locally, on demand**, and the
result is committed. The documentation build itself needs only Python.

## When to run it

Whenever you change a file in `src/demos`, or change code that alters what a demo
prints or plots, the test `docs/test_demo_captures_current.py` will fail, indicating that
you need to re-run the capture.

## How to run it

From the repository root, with MATLAB on `PATH` (or `MATLAB` set to its full path)
and `perceptual_space_geometry` already in MATLAB's path, run:

```bash
python docs/update_demo_docs.py rs_knit_coordsets_demo   # one demo, seconds to minutes
python docs/update_demo_docs.py                          # all 15, about 15 minutes
```

That runs three stages:

1. `docs/build_demo_specs.py` writes `build/capture/<demo>.spec.json`: the code
   chunks, the scripted answers to interactive prompts, and where output goes.
2. `capture/matlab/run_all.m` runs each spec through `run_capture.m`, which
   evaluates the chunks, exports figures, and writes `<demo>.manifest.json`.
3. `docs/render_demo_pages.py` renders `docs/mfiles/demos/<demo>.md` from the demo
   source plus that manifest, and records the demo's source hash in
   `capture/demo_capture_index.json`.

Then review and commit:

```bash
git status                  # page, figures, index
mkdocs serve                # check the pages read well
git add docs/mfiles/demos docs/images/demos capture/demo_capture_index.json
```

`build/` is scratch and is not committed.

## What is committed, and what is generated

| Path | |
| --- | --- |
| `docs/mfiles/demos/*.md` | committed, rendered by the capture |
| `docs/images/demos/*.png` | committed, exported by the capture |
| `capture/demo_capture_index.json` | committed, one entry per demo |
| `docs/mfiles/*.md`, `docs/demos.md` | generated on every build |
| `build/capture/*` | scratch, local only |

## Notes

- **Interactive demos** need a `%#demo-input: <answer>` comment on each line that
  prompts; an empty answer means "press enter for the default". A missing directive
  makes the capture hang or fail.
- **Figures** are exported at 96 dpi as they are created, keeping at most 20 open at
  once; `capture/matlab/run_capture_test.m` checks that, and the snapshot directive described next. Run it
  with `matlab -batch "addpath('capture/matlab'); run_capture_test"`. A figure is saved once, when
  the code block that opened it ends. To save it again after a later block draws on
  it, end a code line of that block with `%#demo-snapshot` (the current figure) or
  `%#demo-snapshot: all` (every figure still open from earlier blocks).
- **Directives** (`%#demo-input:`, `%#demo-snapshot`) count only at the end of a code
  line or alone on a line; inside a prose comment they are plain text.
- **On Linux and macOS** the capture runs with `-nodisplay`. Without it MATLAB tries
  hardware OpenGL in batch mode and exports solid black images without failing.
- **On Windows** the capture runs with `-wait` instead, because the `matlab` command
  otherwise returns to the shell before MATLAB has finished. That flag is not trusted
  either: `run_all.m` deletes `build/capture/run_all.done` when it starts and writes it
  when it has run every spec, and `update_demo_docs.py` waits for that file before
  rendering. If MATLAB is still running, the script says so and waits; interrupt it with
  Ctrl-C if MATLAB is no longer there. Rendering a demo whose manifest is missing never
  overwrites the page already on disk, so a stray run cannot replace captured output
  with a page of code only. Pages, the index and the specs are written with Unix line
  endings, and demo sources are hashed with line endings normalized, so a capture made
  on Windows matches one made on Linux or macOS.
- **A demo that errors** is still captured: the error appears on its page where it
  happened, and in the index.
- Re-capturing rewrites that demo's PNGs, and every version stays in git history.
  Capture only the demos you changed, so that the repository stays small.
