# Demo capture

The demo pages in the documentation show what each demo prints and the figures it
draws. Producing that needs MATLAB, so it happens **locally, on demand**, and the
result is committed. The documentation build itself, here and in CI, needs nothing
but Python.

## When to run it

Whenever you change a file in `src/demos`, or change code that alters what a demo
prints or plots. `docs/test_demo_captures_current.py` fails if you do not, naming
the demos that drifted, so CI will tell you.

## How to run it

From the repository root, with MATLAB on `PATH` (or `MATLAB` set to its full path)
and `perceptual_space_geometry` findable (see `run_all.m`):

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
  once; `capture/matlab/run_capture_test.m` checks that. Run it with
  `matlab -batch "addpath('capture/matlab'); run_capture_test"`.
- **On Linux and macOS** the capture runs with `-nodisplay`. Without it MATLAB tries
  hardware OpenGL in batch mode and exports solid black images without failing.
- **On Windows** the capture runs with `-wait` instead, because the `matlab` command
  otherwise returns to the shell before MATLAB has finished, and the pages would be
  rendered from the previous capture. Pages, the index and the specs are written with
  Unix line endings, and demo sources are hashed with line endings normalized, so a
  capture made on Windows matches one made on Linux or macOS. This path has not been
  run on Windows yet; say so if it misbehaves.
- **A demo that errors** is still captured: the error appears on its page where it
  happened, and in the index. Three demos error today, which is tracked separately.
- Re-capturing rewrites that demo's PNGs, and every version stays in git history.
  Capture only the demos you changed, and the repository stays small.
