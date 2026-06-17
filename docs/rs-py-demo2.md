# Demo 2: Detailed Choice File → Combined Choice File

This demo aggregates repeated comparisons from a detailed choice file into a combined choice file.

#### Run the demo

```bash
cd rs-software
python -m src.rs_py.demos.demo_combined_choices.py
```

#### Inputs

| Prompt                             | What the parameter is                             |
| ---------------------------------- | ------------------------------------------------- |
| Path to detailed choices .mat file | Output file produced by Demo 1                    |
| Output directory                   | Directory where the combined file will be written |
| Experiment/paradigm name           | Used when naming output files                     |
| Subject ID                         | Used when naming output files                     |

To use the sample data included with the repository, enter:

```text
0
```

for all prompts.

#### Example terminal output

```text
Combining trial wise judgments.
  Input detailed .mat: /path/to/animals_detailed_choices_S4.mat
  Output dir:         /path/to/output
  Exp name:           animals
  Subject:            S4

Writing combined file in three-column format (ref, s1, s2).
Saved results to /path/to/output/animals_combined_choices_S4.mat

Done.
```

#### Output file

```text
animals_combined_choices_S4.mat
```

#### Contents of the output file

The file contains:

```text
metadata
response_colnames
responses
```

The metadata field is carried over from Demo 1.

##### response_colnames

```text
ref
s1
s2
N(D(ref, s1) > D(ref, s2))
N_Repeats(D(ref, s1) > D(ref, s2))
```

##### responses

For the sample dataset:

```text
5994 rows × 5 columns
```

Unlike the detailed choice file, there is no `trial` column. Repeated occurrences of the same comparison have been combined into a single row.

Example:

```text
ref   s1   s2   N(D(ref,s1) > D(ref,s2))   N_Repeats(D(ref,s1) > D(ref,s2))
16     3   13              5                              5
```

Using `metadata.stim_list`:

```text
3  = bear
13 = elephant
16 = giraffe
```

This row corresponds to:

```text
(ref, s1, s2)
(giraffe, bear, elephant)
```

The final two columns indicate that this comparison appeared 5 times in the experiment and the same outcome was observed on all 5 occasions.

Compared to the detailed choice file, many repeated comparisons have been merged, reducing the number of rows from 31,080 to 5,994.

#### Next step

The output of this demo becomes the input to **Demo 3**, which fits geometric models to the similarity judgments.
