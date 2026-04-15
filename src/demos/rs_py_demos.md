## Guide to `rs_py`

### Overview:
This module contains some of the scripts to run early stages of the `rs-software` pipeline. 
Specifically, scripts here do the following:
* Convert raw rank ordering judgments acquired using the Waraich and Victor (2022) paradigm into a tabular format in which every row contains the occurrence of a triadic comparison, (i.e., a comparison between the similarities of a reference stimulus to two other stimuli). 
* Tally the choices for repeated occurrences of the same traidic comparisons across all sessions of the experiment.
* From the above similarity judgments, estimate geometric models of the representational spaces in which distances between points best explain them.

There are three entry points that a user may find useful corresponding to the three steps above. They are in the scripts module. 
Below we describe their inputs and outputs and after that how to use them in Python or MATLAB.

```python
rs_py.scripts.write_choice_file_detailed
rs_py.scripts.write_choice_file_combined
rs_py.scripts.run_model_fitting
```

what these scripts can do and what they expect. What they take as input, what they return as output.
The key steps of this process are explained in the following demos.
A user may supply their files in the initial input form (needed by demo 1), or as intermediate form
as expected by demo 2 or demo 3 etc.

The first demo does X.

The second demo shows Y.

The demos build on each other.

```MATLAB
params = py.dict(pyargs( ...
    "input_path", "/path/to/input", ...
    "output_dir", "/path/to/output", ...
    "comparison_type", "triadic" ...
));

meta = py.dict(pyargs( ...
    "subject", "S4", ...
    "exp_name", "demo_experiment", ...
    "num_trials", double(1110), ...
    "num_sessions", double(10) ...
));

params{"metadata"} = meta;

mod = py.importlib.import_module("src.rs_py.scripts.write_choice_file_detailed");
mod.run(params);

```


```MATLAB
json_str = '{"input_path":"/path/to/input","output_dir":"/path/to/output","comparison_type":"triadic","metadata":{"subject":"S4","exp_name":"demo_experiment","num_trials":1110,"num_sessions":10}}';

mod = py.importlib.import_module("src.rs_py.scripts.write_choice_file_detailed");
mod.run(json_str);
```
