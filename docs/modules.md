# Modules

The library is organized in different modules

## Data input

### Raw triplet responses

Behavioral data can be input as raw triplet responses, that is, the responses as they occur during the experiment, with each row corresponding to a trial.

This type of input needs (?) to be transformed to an aggregated format. This step can be done with function
`aggregate_triplets`. For example,

```
data = readcsv(...)
agg_data = aggregate_triplets(data)
```

returns the variable `agg_data` with the aggregated data.


### Aggregated triplet responses

Input can also be triplet responses tallied across repetitions.
In this case ...

...




## Data transformation

...
...


## Utilities

- [`procrustes_consensus`](mfiles/procrustes_consensus.md) Procrustes_consensus
- [`procrustes_consensus-corrected-style`](mfiles/procrustes_consensus_corrected_style.md) Procrustes_consensus
- ...



