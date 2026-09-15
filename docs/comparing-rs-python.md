# Comparing RS — Python option

Runs a full surrogate MDS comparison between two choice datasets and returns a p-value: are the
perceptual maps for two datasets genuinely different, or could the difference be explained by chance?

See [Installation](install-comparing-conversion.md) to set this up.

```python
from rs_tools.compare import compare
from src.rs_py.utils.util import load_choices

# load two datasets
resp1, rep1, _, stims1 = load_choices("choices_A.mat")
resp2, rep2, _, stims2 = load_choices("choices_B.mat")

result = compare(resp1, rep1, stims1, resp2, rep2, stims2,
                 dim=3, n_surrogates=100)

print("p-value:", result['p_value'])
print("Real disparity:", result['real_disparity'])
print("Surrogate mean:", result['surrogate_mean'])
```

**Output:**

- Log-likelihood and Procrustes disparity for each dataset
- Null distribution of surrogate disparities vs. the real disparity
- p-value: fraction of surrogates with disparity ≥ real

### Resampling methods

| Method | Description |
|---|---|
| `with_replacement` | Draw observations with replacement from pooled data (default) |
| `without_replacement` | Draw without replacement from pooled data |
| `without_replacement_paired` | Draw without replacement, keeping A and B draws non-overlapping |

```python
result = compare(resp1, rep1, stims1, resp2, rep2, stims2,
                 dim=3, n_surrogates=100,
                 method='without_replacement_paired')
```

### Random seed control

By default each surrogate seeds deterministically from its own index, so re-running with the same
`n_surrogates` reproduces the same surrogate set. For the real-data fit specifically, control the
starting point with `rng_control.initialize_random_state(if_frozen)` before calling `compare` — see
[Comparing RS → Streamlit option](comparing-rs-streamlit.md) for what each `if_frozen` value means.

For the full function reference, see [Comparing RS → Function reference](function-index-python.md).
