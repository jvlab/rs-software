"""
Demo: create a detailed choices .mat file from raw ranking judgments.

This script:
  1. Parses raw subject CSV files from a ranking experiment.
  2. Generates triadic or tetradic comparisons.
  3. Replaces stimulus labels with numeric IDs.
  4. Canonicalizes comparison keys.
  5. Saves a detailed trial-level .mat file.

Enter 0 to use default values.
"""

import os
import numpy as np

from src.rs_py.choices import choice_file_detailed as dcf
from src.rs_py.utils.config import CONFIG
from src.rs_py.utils.helpers import stimulus_names


def demo_inputs():
    demo_defaults = CONFIG['inputs']['detailed_choice']
    demo_defaults['input_path'] = '../samples/unprocessed_ranking_judgments/S4'  # looks for csv files here
    demo_defaults['output_dir'] = '../samples/choice_files'  # returns detailed mat file here
    demo_defaults['comparison_type'] = 'triadic'  # can only handle triadic judgments
    demo_defaults['metadata'] = {
        'stimuli': stimulus_names(CONFIG['dataset']['stimfile']),
        'num_trials': 1110,  # sample had 222 unique trials x 5
        'num_sessions': 10,
        'subject': CONFIG['dataset']['subject'],    # used to name out file
        'exp_name': CONFIG['dataset']['name']       # used to name out file
    }
    return demo_defaults


if __name__ == '__main__':
    print(
        "Demo: aggregate trial-level detailed choices into a consolidated choices .mat\n"
        "Enter 0 to use default values.\n"
    )

    defaults = demo_inputs()

    input_dir = input("Path to subject data: ")
    output_dir = input("Output directory: ")
    exp_name = input("Experiment/paradigm name (for output filename): ")
    subject = input("Subject ID (for output filename): ")
    comparison_type = input('Judgment type: (triadic or tetradic) ')
    stimuli = input("For metadata,\n \tprovide a list of stimuli as a comma separated list (optional): ")
    num_trials = input("For metadata\n \tprovide total number of trials (optional): ")
    num_sessions = input("For metadata\n \tprovide total number of sessions (optional): ")

    # Though not included in the demo, a user can add any number of fields to metadata.
    # By default, the only ones that are autopopulated are subject and exp_name.
    # One may include other fields, such as paradigm, group, etc. as long as metadata is a dictionary.

    if input_dir == "0" or input_dir.strip() == "":
        input_dir = defaults['input_path']
    if output_dir == "0" or output_dir.strip() == "":
        output_dir = defaults['output_dir']
    if comparison_type == 0 or comparison_type.strip() == "":
        comparison_type = defaults['comparison_type']
    if exp_name == "0" or exp_name.strip() == "":
        exp_name = defaults['metadata']['exp_name']
    if subject == "0" or subject.strip() == "":
        subject = defaults['metadata']['subject']
    if stimuli == "0" or stimuli.strip() == "":
        stimuli = defaults['metadata']['stimuli']
    else:
        split_items = stimuli.split(',')
        stimuli = [y.strip() for y in split_items]
    if num_sessions == "0" or num_sessions.strip() == "":
        num_sessions = defaults['metadata']['num_sessions']
    if num_trials == "0" or num_trials.strip() == "":
        num_trials = defaults['metadata']['num_trials']

    # Basic validation to see if detailed file exists
    if not os.path.exists(input_dir):
        raise FileNotFoundError(f"Input directory not found: {input_dir}")

    os.makedirs(output_dir, exist_ok=True)

    metadata = {
        'exp_name': exp_name,
        'subject': subject,
        'stim_labels': None,
        'stim_ids': None,
        'num_sessions': int(num_sessions),
        'num_trials': int(num_trials),
        'total_judgments': None,
        'judgment_type': comparison_type
    }

    print("\nProcessing raw data...")
    print(f"  Input directory: {input_dir}")
    print(f"  Output directory: {output_dir}")
    print(f"  Subject: {subject}")
    print(f"  Experiment: {exp_name}")
    print(f"  Types of judgments: {comparison_type}\n")

    dcf.build_detailed_choice_mat(
        input_dir=input_dir,
        output_dir=output_dir,
        exp_name=exp_name,
        subject=subject,
        metadata=metadata
    )

    print("\nDone.")



