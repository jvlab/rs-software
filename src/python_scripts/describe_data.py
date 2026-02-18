"""
Take in files in json format and look through it
"""

import numpy as np
import pandas as pd
import seaborn as sns
from analysis.util import all_distance_pairs, read_json_file, ranking_to_pairwise_comparisons, \
    json_to_pairwise_choice_probs
from matplotlib import pyplot as plt
from itertools import combinations


def read_all_files(subjects, data_dir):
    # Keys are "subject,experiment", e.g. "MC"
    rank_judgments_by_subject = {}
    for subject in subjects:
        rank_judgments_by_subject[subject] = read_json_file(subject, data_dir)
    return rank_judgments_by_subject


def group_trials_by_ref(trials):
    grouped = {}
    for trial in trials:
        reference = trial.split(':')[0]
        if reference not in grouped:
            grouped[reference] = {}
        grouped[reference][trial] = trials[trial]
    return grouped


def group_by_overlap(reference, trials):
    circles = []
    for trial in trials:
        circles.append(set(trials[trial][0]))
    result = []
    for i in range(6):  # could change if it was a different paradigm, > 37 stimuli
        for j in range(i + 1, 6):
            if j < len(circles):
                stimuli = sorted(list(circles[i].intersection(circles[j])))
                if len(stimuli) == 2:
                    result.append({'1': '{}:{}'.format(reference, '.'.join(sorted(list(circles[i])))),
                                   '2': '{}:{}'.format(reference, '.'.join(sorted(list(circles[j])))),
                                   'stimuli': stimuli})
    return result


def choice_probability_distribution_plot(filepath, sub, exp, ax=None):
    df = {'choice probability': [], 'frequency': []}
    comparisons, repeats = json_to_pairwise_choice_probs(filepath)
    counts = np.array(list(comparisons.values()))
    repeats = np.array(list(repeats.values()))
    probs = np.divide(counts, repeats)
    unique, freq = np.unique(probs, return_counts=True)
    freq = freq / float(sum(freq))
    df['choice probability'] += list(unique)
    df['frequency'] += list(freq)
    df = pd.DataFrame(df)
    sns.catplot(x="choice probability", y="frequency",
                kind="bar", palette=['b', 'b', 'b', 'b', 'b', 'b'],
                data=df, legend_out=False, ax=ax)
    plt.yticks([0, 0.1, 0.2, 0.3, 0.4])
    plt.title('{}: {}'.format(sub, exp))
    # plt.show()


def choice_prob_ratio_heatmap(trialwise_choice_probabilities, subject_names):
    ncol = len(subject_names)
    nrow = ncol
    keep_colorbar = False
    cbar_kws = None
    fig, axes = plt.subplots(nrows=nrow, ncols=ncol, sharey='row', sharex='row')
    for n in range(ncol):
        for m in range(nrow):
            if m >= n:
                axes[n, m].set_axis_off()
            else:
                subject1 = subject_names[n]
                subject2 = subject_names[m]
                # generate heatmap (count in sub 1 vs count in sub2 - occurrence)
                heatmap = np.zeros((6, 6))
                for i in range(len(trialwise_choice_probabilities[subject1])):
                    heatmap[
                        trialwise_choice_probabilities[subject1][i], trialwise_choice_probabilities[subject2][i]] += 1
                heatmap = np.round(heatmap / float(sum(sum(heatmap))), 3)

                ratio_map = np.zeros((6, 6))
                # divide by independent prob at each cell
                for r in range(len(ratio_map)):
                    for c in range(len(ratio_map[0])):
                        independent_prob = sum(heatmap[r, :]) * sum(heatmap[:, c])
                        ratio_map[r, c] = heatmap[r, c] / float(independent_prob)
                if m == ncol - 2 and n == ncol - 1:
                    # cbar_kws = {'label': '', 'orientation': 'vertical'}
                    keep_colorbar = True
                g = sns.heatmap(ratio_map, square=True,
                                xticklabels=[0, None, None, None, None, 1], annot=False,
                                yticklabels=[0, None, None, None, None, 1], cmap="bwr",
                                ax=axes[n, m], cbar=keep_colorbar, vmin=0, vmax=2.5, center=1)
                bottom, top = axes[n, m].get_ylim()
                axes[n, m].set_ylim(bottom + 0.5, top - 0.5)
                axes[n, m].set_aspect('equal')
                axes[n, m].invert_yaxis()
    for _ in range(ncol):
        axes[-1, _].set_xlabel(SUBJECTIDS[subject_names[_]])
        axes[_, 0].set_ylabel(SUBJECTIDS[subject_names[_]])
    cbar = axes[ncol - 1, ncol - 2].collections[0].colorbar
    cbar.ax.tick_params(labelsize=7)
    fig.tight_layout()
    fig.subplots_adjust(wspace=0, hspace=0)
    plt.savefig('/Users/suniyya/Desktop/{}_pairwise_consistency_heatmaps.eps'.format(EXP), bbox_inches="tight")
    plt.show()


def context_effects_heatmap(subs, data, annotate=True):
    # need to make an empty heatmap at the end because the colorbar shrinks the heatmap next to it
    # and I don't know how else to fix that
    f, ax = plt.subplots(1, len(subs) + 1)  # 1 because of empty heatmap with colorbar
    f.tight_layout(pad=1)
    # cbar_kws = None
    keep_colorbar = False
    cbar_kws = {'label': 'ratio of probability to independent joint probability',
                'orientation': 'vertical'}
    ncol = len(subs)
    for i in range(ncol):
        if ncol == 1:
            ax = [ax]
        # reformat dict into dict of 37 dicts (grouping trials by reference)
        subject_trials = group_trials_by_ref(data[subs[i]])
        # iterate over all reference stimuli to check context dependence
        consistent = {}  # to carry counts
        prob_in_context_ab = np.zeros((6, 6))
        context_trials_count = 0
        for animal in subject_trials:
            # group together pairs of trials that have 2 stimuli in common
            overlapping_trials = group_by_overlap(animal, subject_trials[animal])
            context_trials_count += len(overlapping_trials)
            # iterate over all pairs of overlapping trials
            # for each, check if distance comparison is the same in changing context
            for overlapping_pair in overlapping_trials:
                stimuli = sorted(list(overlapping_pair['stimuli']))
                binary_decision = '{},{}<{},{}'.format(animal, stimuli[0], animal, stimuli[1])
                dist_pair = [binary_decision]
                judgment1 = ranking_to_pairwise_comparisons(
                    dist_pair,
                    subject_trials[animal][overlapping_pair['1']]
                )[0][binary_decision]
                judgment2 = ranking_to_pairwise_comparisons(
                    dist_pair,
                    subject_trials[animal][overlapping_pair['2']]
                )[0][binary_decision]

                prob_in_context_ab[judgment1, judgment2] += 1
        prob_in_context_ab = prob_in_context_ab / float(context_trials_count)
        print('NUMBER OF CONTEXT TRIADS: ' + str(context_trials_count))
        print(prob_in_context_ab)

        ratio_map = np.zeros((6, 6))
        for k in range(6):
            for j in range(6):
                independent_prob = sum(prob_in_context_ab[k, :]) * sum(prob_in_context_ab[:, j])
                ratio_map[k, j] = prob_in_context_ab[k, j] / independent_prob

        sns.heatmap(ratio_map, square=True,
                    xticklabels=[0, None, None, None, None, 1], annot=annotate,
                    yticklabels=[0, None, None, None, None, 1],center=1,cmap='seismic', #"coolwarm", center=1,
                    ax=ax[i], cbar=keep_colorbar, vmin=0, vmax=8)
        bottom, top = ax[i].get_ylim()
        ax[i].set_title(SUBJECTIDS[subs[i]])
        ax[i].set_ylim(bottom + 0.5, top - 0.5)
        # ax[i].set_xlabel('response in context a')
        # ax[i].set_ylabel('response in context b')
        ax[i].invert_yaxis()
    i += 1  # make 1 extra empty heatmap with a color bar. SO that the actual heatmaps are not made smaller by colorbar.
    sns.heatmap(np.zeros((6, 6)), square=True,
                xticklabels=[0, None, None, None, None, 1], annot=annotate,
                yticklabels=[0, None, None, None, None, 1], center=1,cmap='seismic', #"coolwarm", center=1,
                ax=ax[i], cbar=True, cbar_kws={"shrink": 0.5}, vmin=0, vmax=8, annot_kws={"fontsize": 8})
    cbar = ax[i].collections[0].colorbar
    cbar.ax.tick_params(labelsize=9)
    f.tight_layout()
    f.supxlabel('Response in Context A')
    f.supylabel('Response in Context B')
    plt.show()


def get_choice_probs_by_subject(subject_names, data):
    choice_probs = {}
    num_repeats = {}
    for subject_name in subject_names:
        choice_probs[subject_name] = {}
        num_repeats[subject_name] = {}
        ranking_trials = data[subject_name]
        for trial in ranking_trials:
            choice_probs[subject_name][trial], num_repeats[subject_name][trial] = ranking_to_pairwise_comparisons(
                all_distance_pairs(trial),
                ranking_trials[trial])
    return choice_probs, num_repeats


def arrange_choice_probs_by_comparison(subject_names, choice_probs):
    trialwise_choice_probabilities = {}
    for subject in subject_names:
        if subject not in trialwise_choice_probabilities:
            trialwise_choice_probabilities[subject] = []
        for trial, comparisons in choice_probs[subject_names[0]].items():
            for comparison, count in comparisons.items():
                trialwise_choice_probabilities[subject].append(choice_probs[subject][trial][comparison])
    return trialwise_choice_probabilities


def subject_comparison_heatmap(subject_names, data):
    if len(subject_names) < 2:
        print(
            "WARNING: At least two subjects needed to make comparison heatmaps (function subject_comparison_heatmap).")
        return
    choice_probs = get_choice_probs_by_subject(subject_names, data)
    trialwise_choice_probabilities = arrange_choice_probs_by_comparison(subject_names, choice_probs)
    choice_prob_ratio_heatmap(trialwise_choice_probabilities, subject_names)


if __name__ == '__main__':
    subs = input("Subjects separated by spaces:")
    SUBJECTS = subs.split(' ')
    EXP = input('Name of domain: ')
    DATA_DIR = '/Users/suniyya/Dropbox/Research/Thesis_Work/Psychophysics_Aim1/experiments/' \
               'experiments/{}_exp/subject-data/preprocessed'.format(EXP)
    SUBJECTIDS = {"MC": "S1", "BL": "S2", "EFV": "S3", "SJ": "S4", "SAW": "S5", "NK": "S6", "YCL": "S7",
                  "SA": "S8", "JF": "S9", "AJ": "S10", "SN": "S11", "ZK": "S12", "CME": "S13"}
    ALL_DATA = read_all_files(SUBJECTS, DATA_DIR)
    # Display choice probability distributions
    # num_subs = len(SUBJECTS)
    # f, axs = plt.subplots(1, num_subs, sharex='all', sharey='col')
    # for i in range(num_subs):
    #     filepath = DATA_DIR + '/{}_{}_exp.json'.format(SUBJECTS[i], EXP)
    #     choice_probability_distribution_plot(filepath, SUBJECTS[i], EXP, axs[i])
    #     axs[i].set_title(SUBJECTS[i])
    #     axs[i].set_ylim([0, 0.3])
    #     axs[i].set_xticklabels([0] + [None]*4 + [0.5] + [None]*4 + [1])
    #     if i > 0:
    #         axs[i].set_ylabel(None)
    #         axs[i].set_yticklabels([])
    # plt.show()

    # Create subject-comparison heatmaps
    # subject_comparison_heatmap(SUBJECTS, ALL_DATA)

    # Create context effects heatmaps
    context_effects_heatmap(SUBJECTS, ALL_DATA, annotate=True)
    context_effects_heatmap(SUBJECTS, ALL_DATA, annotate=False)
    # context_effects_heatmap(['MC'], ALL_DATA, annotate=False)
