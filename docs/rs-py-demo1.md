# Demo 1: Raw Rankings → Detailed Choice File

This demo converts raw ranking responses collected using the Waraich & Victor paradigm into a detailed choice file.

### Run the demo

From the terminal:

```bash
cd rs-software
python -m src.rs_py.demos.demo_detailed_choices.py
```


### Inputs

The demo will prompt you for the following:

| Prompt                   | What the parameter is                                                                   |
| ------------------------ |-----------------------------------------------------------------------------------------|
| Path to subject data     | Folder containing raw response CSV files from the Waraich and Victor paradigm           |
| Output directory         | Directory where any output files will be written                                        |
| Experiment/paradigm name | Name of the condition or experiment. It is used when naming output files                |
| Subject ID               | Subject identifier, used when naming output files                                       |
| Judgment type            | `triadic` or `tetradic` (see [Notes on Comparison Formats](#notes-on-comparison-formats)|                                   |
| Total number of trials   | Stored as metadata                                                                      |
| Total number of sessions | Stored as metadata                                                                      |

To use the sample data included with the repository, enter:

```text
0
```

for all prompts.




### What the user sees

The script will display the following prompts:

```text
Path to subject data:
Output directory:
Experiment/paradigm name (for output filename):
Subject ID (for output filename):
Judgment type: (triadic or tetradic)
For metadata
    provide total number of trials (optional):
For metadata
    provide total number of sessions (optional):
```


### Example terminal output

```text
Processing raw data...
  Input directory: /path/to/S4
  Output directory: /path/to/output
  Subject: S4
  Experiment: animals
  Types of judgments: triadic

Saved results to /path/to/output/animals_detailed_choices_S4.mat

Done.
```



### Output file

```text
animals_detailed_choices_S4.mat
```



### Contents of the output file

The file contains three fields:

```text
metadata
response_colnames
responses
```

#### `metadata`

Information describing the dataset:

```text
subject = S4
exp_name = animals
num_trials = 1110
num_sessions = 10
judgment_type = triadic
stim_list = [...]
```

#### `response_colnames`

```text
trial
ref
s1
s2
N(D(ref, s1) > D(ref, s2))
```

#### `responses`

For the sample dataset:

```text
31080 rows × 5 columns
```

Each row represents a single triadic comparison derived from a ranking response.

Example:

```text
trial   ref   s1   s2   N(D(ref,s1) > D(ref,s2))
1       16    3    13            1
```

The first column indicates the trial from which the comparison originated. In this example, both rows come from trial 1.

The stimulus IDs correspond to entries in:

```text
metadata.stim_list
```

In this example, the stimulus IDs correspond to these stimuli:
```text
3  = bear
7  = cow
13 = elephant
16 = giraffe
```

Thus the first row corresponds to the comparison:

```text
(ref, s1, s2)
(giraffe, bear, elephant)
```
The participant's response of 1 indicates that they considered 'giraffe' to be more similar 'elephant' than to 'bear.'
In other words, when asked to click the most similar stimulus to 'giraffe', they clicked on 'elephant' before clicking on 'bear'.

To determine the name associated with any stimulus ID, look it up in:

```text
metadata.stim_list
```

within the same file.

The output of this demo becomes the input to **Demo 2**, which aggregates repeated occurrences of the same comparison across trials and sessions.



## Notes on Comparison Formats

The Waraich & Victor paradigm produces **triadic judgments**, in which two stimuli are compared relative to a common reference:

```text
Is A more similar to ref than B is?
```
The same judgment can be stored in two formats.

### Triadic format (recommended)
`(ref, A, B)`

Example:
`(cat, dog, wolf)`

corresponding to:
`D(cat,dog) > D(cat,wolf)`


This format is more compact and is the format used in the Waraich & Victor studies.

### Tetradic format  

`(ref, A, ref, B)`

Example:
`(cat, dog, cat, wolf)`

corresponding to:
`D(cat,dog) > D(cat,wolf)`


This contains the same information, but represents the judgment as a comparison between two stimulus pairs.

### Which should I choose?

For most users, we recommend choosing `triadic.` Choose `tetradic` only if your downstream analysis expects comparisons between stimulus pairs or you need compatibility with another tetradic dataset.




## Next step

The output of Demo 1 becomes the input to **Demo 2**, which aggregates repeated occurrences of the same comparison across trials and sessions.

