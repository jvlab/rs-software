"""
Code to make Figure 6 or 7 of the F31 application where I show geometry likelihoods
relative to ground truth (Euclidean geometry-fitting pipeline).
"""
import glob

import pandas as pd
import seaborn as sns
from matplotlib import pyplot as plt


def read_model_likelihoods(subjects, path):
    model_fitting_data = []

    for subject in subjects:
        subjectfiles = glob.glob('{}/*/*/{}-*-likelihoods*0.csv'.format(path, subject))
        print(subjectfiles)
        for file in subjectfiles:
            results = pd.read_csv(file)
            best_index = results.index[results['Model'] == 'best']
            corrected_best_ll = results.iloc[best_index]['Log Likelihood'] - 0
            corrected_best_ll = corrected_best_ll.values[0]
            results.at[best_index, 'Log Likelihood'] = corrected_best_ll
            results['Subject'] = subject
            results['Log Likelihood Relative to "Best" Model'] = results['Log Likelihood'] - corrected_best_ll
            model_fitting_data.append(results)

    model_fitting_data = pd.concat(model_fitting_data, sort=True)
    print(model_fitting_data)
    return model_fitting_data


if __name__ == '__main__':
    SUBJECTS = input("Subjects separated by spaces: ").split(' ')
    PATH_TO_SUBJECT_LOG_LIKELIHOODS = input("Path to the directory containing geometry log-likelihood files "
                                            "(e.g., ./sample-materials/subject-data/geometry-fitting/S7/log-likelihoods): ")
    print(SUBJECTS)
    COL_ORDER = ['texture', 'intermediate_texture', 'intermediate_object', 'image', 'word']
    print(PATH_TO_SUBJECT_LOG_LIKELIHOODS)
    all_data = read_model_likelihoods(SUBJECTS, PATH_TO_SUBJECT_LOG_LIKELIHOODS)
    excluded_models = ['best']

    # plot geometry LLs for all experiments and subjects
    subjects = all_data.Subject.unique()
    g = sns.catplot(data=all_data.loc[~all_data['Model'].isin(excluded_models)],
                    x='Model', y='Log Likelihood Relative to "Best" Model',
                    hue='Subject',
                    col='Experiment',
                    col_order=COL_ORDER,
                    kind='point', linestyles="-",
                    alpha=0.5,
                    height=3,
                    # palette="viridis_r",
                    order=['random', '1D', '2D', '3D', '4D', '5D'],
                    label='big', legend_out=True)
    # g.set(ylim=(-1, 0.15))
    g.set_xticklabels(rotation='45')
    # add horizontal lines to mark log likelihood of ground truth
    for i in range(len(g.axes[0])):
        for j in range(len(g.axes)):
            g.axes[j, i].axhline(0, color='k')
    plt.show()

    # PLOT BEST CURVATURE VALUES BY SUBJECT AND DOMAIN
    curvature_df = all_data[all_data['Curvature'].notnull()]
    g = sns.catplot(data=curvature_df,
                    x='Experiment', y='Curvature',
                    hue='Subject',
                    kind='bar',
                    # height=3,
                    # palette="viridis_r",
                    order=['texture', 'intermediate_texture', 'intermediate_object', 'image', 'word'],
                    legend_out=True)

    g.set_xticklabels(['texture', 'texture*', 'image*', 'image', 'word'], rotation='45')
    # add horizontal lines to mark hyperbolic curvature
    for i in range(len(g.axes[0])):
        for j in range(len(g.axes)):
            g.axes[j, i].axhline(1, color='k')
    plt.show()

    # PLOT BEST CURVATURE VALUES GROUPED BY SUBJECT
    g = sns.catplot(data=curvature_df,
                    x='Subject', y='Curvature',
                    kind='bar',
                    ci=None,
                    legend_out=True)

    # add horizontal lines to mark hyp curvature
    for i in range(len(g.axes[0])):
        for j in range(len(g.axes)):
            g.axes[j, i].axhline(1, color='k')
    plt.show()

    g = sns.catplot(data=curvature_df,
                    x='Experiment', y='Curvature',
                    kind='bar',
                    order=COL_ORDER,
                    ci=None,
                    legend_out=True)
    g.set_xticklabels(['texture', 'texture*', 'image*', 'image', 'word'], rotation='45')
    for i in range(len(g.axes[0])):
        for j in range(len(g.axes)):
            g.axes[j, i].axhline(1, color='k')
    plt.show()
