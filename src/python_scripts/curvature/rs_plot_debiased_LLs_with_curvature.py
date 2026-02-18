import glob
import numpy as np
import seaborn as sns
import pandas as pd
import matplotlib.pyplot as plt
from scipy.spatial.distance import pdist, squareform

from analysis.geometry.hyperbolic import hyperbolic_distances, loid_map, spherical_distances, sphere_map
from analysis.util import read_out_median_bias, bias_dict

sns.color_palette("Set2", 20)

normal_xaxis = False
SUBJECTS = ['MC', 'BL']
DIMENSIONS = [2, 3]
FIG_WIDTH = 2
FIG_HEIGHT = 6
MARKERS = {"MC": "^", "BL": "D", "CME": "8"}
DATA_DIR = '/Users/suniyya/Dropbox/Research/Thesis_Work/Side_Projects/psg/psg-texture-data'
CONDITION = 'bc6pt9'

dim = DIMENSIONS[0]


def rms_dist_curvature(path_to_data_dir, condition, num_dists=666):
    # Copied from bias_estimate.py and edited on July 3, 2023
    # !calculate distances based on curvature param value!
    path_to_npy_files = '{}/{}_data/curvature/*/*/*sigma_1.0*dim_{}*.npy'
    rms_sigma = {}
    for dimension in DIMENSIONS:
        npy_files = glob.glob(path_to_npy_files.format(path_to_data_dir, condition, dimension))
        for npy_file in npy_files:
            # get filename and use metdata to populate subject, domain, curvature vals
            segments = npy_file.split('/')[-1].split('_')
            subname = segments[0]
            domain = segments[1]
            curvature_param = float(segments[-1].split('.npy')[0])
            points = np.load(npy_file)
            # intialize dicts to ensure no key error
            if subname not in rms_sigma:
                rms_sigma[subname] = {}
            if domain not in rms_sigma[subname]:
                rms_sigma[subname][domain] = {}
            if dimension not in rms_sigma[subname][domain]:
                rms_sigma[subname][domain][dimension] = {}
            # read in each dataset, from points of different dimensions calculate the RMS of distances
            # save the ratio of RMS distance to sigma. We know this value rises with model dimension
            # and varies across subjects
            # and experiments
            if curvature_param == 0:
                distances = squareform(pdist(points))
            elif curvature_param < 0:
                distances = hyperbolic_distances(loid_map(points.T, abs(curvature_param)), abs(curvature_param))
            else:
                distances = spherical_distances(sphere_map(points.T, 1 / curvature_param), 1 / curvature_param)
            num_stim = distances.shape[0]
            unique_pairs_dists = []
            for i in range(num_stim):
                for j in range(i):
                    unique_pairs_dists.append(distances[i, j])
            if len(unique_pairs_dists) != num_dists:
                print("ERROR wrong num dists")
            rms = np.sqrt(np.mean([d ** 2 for d in distances]))
            # record rms if not previously computed. Average if two values exist (for curv val -1 and +1).
            if curvature_param not in rms_sigma[subname][domain][dimension]:
                rms_sigma[subname][domain][dimension][curvature_param] = rms
            else:
                prev = rms_sigma[subname][domain][dimension][curvature_param]
                rms_sigma[subname][domain][dimension][curvature_param] = (prev + rms) / 2.0
        # pprint.pprint(rms_sigma)
    return rms_sigma


def get_best_model_lls(path_to_ll_csv_dir, condition):
    # geometric-modeling
    path_to_ll_csv_files = '{}/{}_data/likelihoods/*/*likelihood*.csv'.format(path_to_ll_csv_dir, condition)
    best_ll_dict = {}
    files = glob.glob(path_to_ll_csv_files)
    for file in files:
        filename = file.split('/')[-1]
        segments = filename.split('-')
        subname = segments[0]
        domain = segments[1]
        results = pd.read_csv(file)
        best_index = results.index[results['Model'] == 'best']
        best_ll = results.iloc[best_index]['Log Likelihood']
        if subname not in best_ll_dict:
            best_ll_dict[subname] = {}
        best_ll_dict[subname][domain] = best_ll
    return best_ll_dict


num_stim_pairs = int(25 * 24 / 2)
rms_dict = rms_dist_curvature(DATA_DIR, CONDITION, num_dists=num_stim_pairs)
bias_df = bias_dict(use_all=True)

# Expanded range from 0 to 1
p = sns.color_palette("colorblind", 12)
p.append((0.3, 0.3, 0.3))
files = glob.glob('{}/{}_data/curvature/*/*/*.csv'.format(DATA_DIR, CONDITION))
df2 = pd.concat([pd.read_csv(f) for f in files], ignore_index=True, sort=True)

best_dict = get_best_model_lls(DATA_DIR, CONDITION)
################################
# add an expected bias column
df2['Bias Estimate'] = None
df2['Rel LL'] = None
# df2['Gaussian Curvature'] = df2['Curvature']
df2['Curvature'] = None
for index, row in df2.iterrows():
    dim = row['Dimension']
    domain = row['Domain']
    subject = row['Subject']
    curv_param = row['Lambda-Mu']
    if curv_param <= 0:
        df2.loc[[index], ['Curvature']] = curv_param
    else:
        df2.loc[[index], ['Curvature']] = 2 * curv_param
    # print(subject, domain, dim, curv_param)
    rms_dist = rms_dict[subject][domain][dim][curv_param]
    bias = read_out_median_bias(bias_df, dim, rms_dist)
    df2.loc[[index], ['Bias Estimate']] = bias
    df2.loc[[index], ['Rel LL']] = - best_dict[subject][domain].values[0] + (bias + row['Log Likelihood'])

print(df2.head())
df2['Corrected LLs'] = df2['Log Likelihood'] + df2['Bias Estimate']
# df2.to_csv('/Users/suniyya/Desktop/modeling_results_LL_with_median_bias.csv')

sns.set_style("whitegrid")
domain = CONDITION
# df = df2.loc[df2['Dimension'] == dim]
g = sns.scatterplot(data=df2, x='Curvature of Space', y='Corrected LLs',
                    hue='Dimension',  style='Subject', markers=MARKERS, palette='jet')

# g.set_yticks([-1, -0.9, -0.8, -0.7, -0.6, -0.5, -0.4, -0.3, -0.2, -0.1, 0])
# g.set_yticklabels([-1, None, -0.8,  None, -0.6,  None, -0.4,  None, -0.2,  None, 0])
sns.set(font="Arial")
sns.set(font_scale=1.5)
# plt.ylim([-.99, 0.1])
plt.xlim([-5.2, 2.1])
plt.xlabel('Curvature (hyperbolic to spherical)')
plt.ylabel('Debiased Log-Likelihood')
# g.set_xticks([-5, -4, -3, -2, -1, -0.5, 0, 0.5, 1, 2, 3, 4, 5, 6],
#              [-5] + [None] * 3 + [-1] + [None] + [0] + [None] + [1] + [None] * 4 + [6])

plt.tick_params(axis='y', which='both', direction='out', length=4, left=True)
plt.tick_params(axis='x', which='both', direction='out', bottom=True)
sns.despine(bottom=False, left=False, top=True, right=True)
plt.axvline(0, color='k', linewidth=0.8)
plt.axhline(0, color='gray', linewidth=0.8)
plt.savefig('/Users/suniyya/Desktop/{}_{}D_curvature_model_LL_final.png'.format(domain, dim), bbox_inches="tight")
plt.savefig('/Users/suniyya/Desktop/{}_{}D_curvature_model_LL_zoomed_final.eps'.format(domain, dim), bbox_inches="tight")
plt.show()
