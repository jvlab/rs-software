"""
This file is to put preprocessing methods in. My raw data looks like a csv file with headers including
ref, stim1, stim2, ..., stim8, session, participant and clicks.
"""

import ast
import csv
import json
import os


def get_response_files(subject_name, directory):
    # directory is path to exp/subject-data
    # noinspection SpellCheckingInspection
    paths = []
    for root, dirs, file_paths in os.walk('{}/{}'.format(directory, subject_name)):
        for f in file_paths:
            if f.endswith("responses.csv"):
                paths.append(os.path.join(root, f))
    return paths


fieldnames = ['reference', 'stim1', 'stim2', 'stim3', 'stim4', 'stim5', 'stim6', 'stim7', 'stim8', 'clicks',
              'participant', 'session']

if __name__ == '__main__':
    directory = input("Path to subject-data dir of experiment: ")
    experiment_name = input("Experiment name: ")
    output_directory = '{}/preprocessed'.format(directory)
    data_directory = '{}/raw'.format(directory)
    subject_names = (input("Enter Subject IDs separated by spaces: ")).split(' ')
    print('Preprocessing data from {} experiment for subjects {}'.format(experiment_name, subject_names))

    for subject in subject_names:
        subject_files = get_response_files(subject, data_directory)
        trials = {}
        for file in subject_files:
            with open(file, newline='') as csv_file:
                reader = csv.DictReader(csv_file, fieldnames=fieldnames)
                reader.__next__()  # to skip header line
                for row in reader:
                    # eval is usually not secure but here I created the files parsing
                    sequence = ast.literal_eval(row['clicks'])
                    clicks = [row[stim] for stim in sequence]
                    circle = '.'.join(sorted(
                        [
                            row['stim1'], row['stim2'],
                            row['stim3'], row['stim4'],
                            row['stim5'], row['stim6'],
                            row['stim7'], row['stim8']
                        ])
                    )
                    trial_str = '{}:{}'.format(row['reference'], circle)
                    if trial_str in trials:
                        trials[trial_str].append(clicks)
                    else:
                        trials[trial_str] = [clicks]

        with open('{}/{}_{}_exp.json'.format(output_directory, subject, experiment_name), 'w') as fp:
            json.dump(trials, fp, indent=2)
