"""
To demo the script that aggregates detailed trial-level choice judgments
into a combined (unique-comparison) choice file.

This demos:
    combine_choice_mat(input_mat_path, output_dir, exp_name, subject)

Enter 0 to use default values.
"""

import os
from src.rs_py.utils.config import CONFIG
from src.rs_py.choices.choice_file_combined import build_combine_choice_mat


def demo_inputs():
    demo_defaults = CONFIG['inputs']['combined_choice']
    demo_defaults['input_path'] = "../samples/choice_files/animals_detailed_choices_S4.mat"
    demo_defaults['output_dir'] = "../samples/choice_files"
    demo_defaults['exp_name'] = "animals"
    demo_defaults['subject'] = "S4"
    return demo_defaults


if __name__ == "__main__":
    print(
        "Demo: aggregate trial-level detailed choices into a consolidated choices .mat\n"
        "Enter 0 to use default values.\n"
    )

    defaults = demo_inputs()

    input_mat_path = input("Path to detailed choices .mat file: ")
    output_dir = input("Output directory: ")
    exp_name = input("Experiment/paradigm name (for output filename): ")
    subject = input("Subject ID (for output filename): ")

    if input_mat_path == "0" or input_mat_path.strip() == "":
        input_mat_path = defaults['input_path']
    if output_dir == "0" or output_dir.strip() == "":
        output_dir = defaults['output_dir']
    if exp_name == "0" or exp_name.strip() == "":
        exp_name = defaults['exp_name']
    if subject == "0" or subject.strip() == "":
        subject = defaults['subject']

    # Basic validation to see if detailed file exists
    if not os.path.isfile(input_mat_path):
        raise FileNotFoundError(f"Detailed choices .mat not found: {input_mat_path}")

    os.makedirs(output_dir, exist_ok=True)

    print("\nCombining trial wise judgments...")
    print(f"  Input detailed .mat: {input_mat_path}")
    print(f"  Output dir:         {output_dir}")
    print(f"  Exp name:           {exp_name}")
    print(f"  Subject:            {subject}\n")

    build_combine_choice_mat(
        input_mat_path=input_mat_path,
        output_dir=output_dir,
        exp_name=exp_name,
        subject=subject,
    )

    print("\nDone.")
