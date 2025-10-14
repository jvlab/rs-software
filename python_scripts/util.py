"""
Some utilities to help with processing psychophysical data files
"""
import yaml
import json
import pandas as pd
from scipy.io import savemat
import glob
import numpy as np
from itertools import combinations

from scipy.spatial.distance import pdist


def stimulus_names():
    # Read in parameters from config file
    with open('./analysis/config.yaml', "r") as stream:
        data = yaml.safe_load(stream)
        stimulus_list_file = data['path_to_stimulus_list']
    stimuli = open(stimulus_list_file).read().split('\n')
    return stimuli


def stimulus_name_to_id():
    stimuli = stimulus_names()
    names_to_id = dict(zip(stimuli, range(len(stimuli))))
    return names_to_id


def stimulus_id_to_name():
    stimuli = stimulus_names()
    id_to_name = dict(zip(range(len(stimuli)), stimuli))
    return id_to_name


def read_json_file(subject, preprocessed_data_dir):
    files = glob.glob('{}/{}_*.json'.format(preprocessed_data_dir, subject))
    if len(files) == 0:
        raise FileNotFoundError
    elif len(files) > 1:
        raise ValueError("Multiple files exist for this subject. There should be only one json file for a subject.")
    else:
        filepath = files[0]
    with open(filepath) as file:
        contents = json.load(file)
    return contents


def all_distance_pairs(trial_key):
    trial = trial_key.split(':')
    ref = trial[0]
    pairs = list(combinations(trial[1].split('.'), 2))

    def helper(x):
        return '{},{}<{},{}'.format(ref, x[0], ref, x[1])

    return list(map(helper, pairs))


def ranking_to_pairwise_comparisons(distance_pairs, ranked_stimuli):
    """ Convert ranking data to comparisons of pairs of pairs of stimuli

    @param distance_pairs:
    :type distance_pairs: list
    :param ranked_stimuli:
    :type ranked_stimuli: list
    """
    # ranked_stimuli is a list of lists. each list is a 'repeat'
    rank = {}
    comparisons = {}
    num_repeats = {}
    for stimulus_list in ranked_stimuli:
        for index in range(len(stimulus_list)):
            rank[stimulus_list[index]] = index
        for pair in distance_pairs:
            dists = pair.split('<')
            stim1 = dists[0].split(',')[1]
            stim2 = dists[1].split(',')[1]
            if pair not in comparisons:
                comparisons[pair] = 1 if rank[stim1] < rank[stim2] else 0
                num_repeats[pair] = 1
            else:
                num_repeats[pair] += 1
                if rank[stim1] < rank[stim2]:
                    comparisons[pair] += 1
    return comparisons, num_repeats


def judgments_to_arrays(judgments_dict, repeats):
    """Instead of having trials be a dictionary with keys made of tuples,
    convert judgment keys and values into numpy arrays for faster operations """
    # the indices of the stimuli for each trial's "first" pair of stimuli
    first_pair = np.array([np.array(trial[0]) for trial in judgments_dict.keys()])
    # the indices of the stimuli for each trial's "second" pair of stimuli
    second_pair = np.array([np.array(trial[-1]) for trial in judgments_dict.keys()])
    comparison_counts = np.array([v for k, v in judgments_dict.items()], dtype='float')
    comparison_repeats = np.array([repeats[k] for k, v in judgments_dict.items()], dtype='float')
    return first_pair, second_pair, comparison_counts, comparison_repeats


def bias_dict(use_all=False):
    path_to_bias_files = './analysis/bias-estimation/simulation_simple_ranking*.csv'
    if use_all:
        path_to_bias_files2 = './analysis/bias-estimation/*/simulation_simple_ranking*.csv'
    else:
        path_to_bias_files2 = ''
    # access simulation results and from these read out bias from RMS dist: sigma.
    sim_files = glob.glob(path_to_bias_files)
    sim_files2 = glob.glob(path_to_bias_files2)
    sim_files = sim_files + sim_files2
    df = pd.concat([pd.read_csv(f) for f in sim_files])
    return df


def read_out_median_bias(bias_df, dim, rms_ratio, tolerance=0.5, samples=40):
    # For a given value of RMS distance to sigma, read out the median bias between geometrically unconstrained
    # "best" model LL and the ground truth LL
    # for figure 5 variant, used tolerance of 0.5 for rms >= 0.5, tol =0.2 for rms <0.5 and samples =40
    biases_df = bias_df[bias_df['True Model'] == str(dim) + 'D']
    if rms_ratio < 0.5:
        tol_val = 0.4
    else:
        tol_val = tolerance
    df_temp = biases_df[biases_df['RMS:Sigma'].between(rms_ratio - tol_val, rms_ratio + tol_val)]
    if len(df_temp) < samples:
        print('WARNING: FEW SAMPLES TO ESTIMATE BIAS FOR RATIO ', np.round(rms_ratio, 2), dim)
        raise ValueError
    # print('Num samples ', len(df_temp), 'rms_ratio: ', rms_ratio)
    median_bias = np.quantile(df_temp['Best LL - Ground Truth LL'].sample(n=samples, random_state=942), 0.5)
    return median_bias


def write_npy(outfilename, array):
    np.save(outfilename, array)


def read_npy(filename):
    return np.load(filename)


def add_row(fields, table):
    for fieldname, value in fields.items():
        table[fieldname].append(value)
    return table


def read_in_params():
    # Read in parameters from config file
    with open('./analysis/config.yaml', "r") as stream:
        user_config = yaml.safe_load(stream)
        sigma_compare = float(user_config['sigmas'])
        total_noise = {'compare': sigma_compare, 'dist': 0}  # because downstream processing expects a key 'dist'
        user_config['sigmas'] = total_noise
    # Fix type of all inputs
    user_config['num_stimuli'] = int(user_config['num_stimuli'])
    user_config['overlap'] = int(user_config['overlap'])
    user_config['num_stimuli_per_trial'] = int(user_config['num_stimuli_per_trial'])
    user_config['path_to_stimulus_list'] = str(user_config['path_to_stimulus_list'])
    user_config['max_trials'] = int(user_config['max_trials'])
    user_config['model_dimensions'] = [int(number) for number in list(user_config['model_dimensions'])]
    user_config['num_repeats'] = int(user_config['num_repeats'])
    user_config['epsilon'] = float(user_config['epsilon'])
    user_config['curvature'] = float(user_config['curvature'])
    user_config['minimization'] = str(user_config['minimization'])
    user_config['tolerance'] = float(user_config['tolerance'])
    user_config['max_iterations'] = int(user_config['max_iterations'])
    user_config['learning_rate'] = float(user_config['learning_rate'])
    user_config['n_dim'] = None
    user_config['no_noise'] = False
    user_config['verbose'] = False
    return (user_config,
            stimulus_names(),
            stimulus_name_to_id(),
            stimulus_id_to_name())


def combine_model_npy_files_to_mat(directory, domain, subject, outdir='.', min_dim=1, max_dim=7):
    """
    Edited on Aug 3, 2023
    Add LL and biases too
    @param directory: input dir - dir in which is a domain dir then a subject dir
    @param subject:
    @param outdir:
    @param min_dim:
    @param max_dim:
    @return:
    """
    # domains = ['bgca3pt9', 'bdce3pt9', 'bc6pt9', 'tvpm3pt9', 'bcpm3pt9', 'faces_mpi_en2_fc', 'bcpp5qpt9',
    #            'bc55qpt9', 'bcpm24pt9', 'bcmm55qpt9', 'bcmp55qpt9', 'bcpm55qpt9']
    # domains = ['texture', 'intermediate_texture', 'intermediate_object', 'image', 'word']
    data = {'stim_labels': stimulus_names()}
    bias_df = bias_dict()  # for LL bias estimation
    rms_dists_by_dim = {}
    for d in range(min_dim, max_dim + 1):
        model_files = glob.glob("{}/{}/{}/{}_{}_anchored_points_sigma_*_dim_{}.npy".format(
            directory, domain, subject, subject, domain, d
        ))
        # enter coordinates for each model dimension
        if len(model_files) > 0:
            model_file = model_files[0]
            points = np.array(np.load(model_file))
            data["dim{}".format(d)] = points
            distances = pdist(points)
            rms_dists_by_dim[d] = np.sqrt(np.mean([d ** 2 for d in distances]))
    # open LL file
    ll_file = glob.glob("{}/{}/{}*{}*likelihoods*.csv".format(directory, domain, subject, domain))
    if len(ll_file) == 0:
        pass  # what does pass do?
    lls = pd.read_csv(ll_file[0])

    data['rawLLs'] = []  # enter raw log-likelihoods
    data['debiasedRelativeLL'] = []
    data['biasEstimate'] = []
    best_index = lls.index[lls['Model'] == 'best']
    best_LL = lls.iloc[best_index]['Log Likelihood'].values[0]
    data['bestModelLL'] = best_LL
    data['metadata'] = ("README\n\nrawLLs[i] is the raw model LL for model with i dimensions\n"
                        "biasEstimate[i] is the median bias estimated for the i-dimensional model, \n"
                        "  based on the RMS distance: sigma\n\n"
                        "debiasedRelativeLL = (rawLLs + biasEstimate) - bestModelLL\n"
                        "--------------------------------------------------------------------------")
    temp = {'bias': {}, 'debiasedLL': {}, 'rawLL': {}}
    for idx, row in lls.iterrows():
        model = 'dim' + str(row['Model'][:-1]) if row['Model'][-1] == 'D' else row['Model']
        if model[0:3] == 'dim':
            # get bias for each model LL
            dim = int(model[3:])
            temp['rawLL'][dim] = row['Log Likelihood']
            bias = read_out_median_bias(
                bias_df, dim, rms_dists_by_dim[dim], tolerance=0.5, samples=70)
            temp['bias'][dim] = bias
            # record debiased model LLs
            temp['debiasedLL'][dim] = row['Log Likelihood'] - (best_LL - bias)
    data['biasEstimate'] = [temp['bias'][key] for key in range(min_dim, max_dim + 1)]
    data['rawLLs'] = [temp['rawLL'][key] for key in range(min_dim, max_dim + 1)]
    data['debiasedRelativeLL'] = [temp['debiasedLL'][key] for key in range(min_dim, max_dim + 1)]
    savemat("{}/{}_coords_{}.mat".format(outdir, domain, subject), data)


def combine_curvature_model_npy_files_to_mat(directory, domain, subject, dim, sigma, outdir='.'):
    """
    Created on Sept 25,'23
    Add LL and biases too
    @param directory: input dir - dir in which is a domain dir then a subject dir
    @param subject:
    @param outdir:
    @param min_dim:
    @param max_dim:
    @return:
    """

    data = {'stim_labels': stimulus_names()}
    bias_df = bias_dict()  # for LL bias estimation
    rms_dists_by_dim = {}

    # read the csv file containing all likelihoods and details
    # open LL file
    ll_file = glob.glob("{}/{}/*.csv".format(directory, domain))
    if len(ll_file) == 0:
        pass  # what does pass do?
    lls = pd.read_csv(ll_file[0])
    # for each entry find and read the corresponding file of coordinates
    # read in row['Lambda-Mu'] = d - if d < 0 -> hyperbolic_model, else spherical_model, lambda_-d or mu_d,
    # also read in row['Sigma']
    # if row['Lambda-Mu'] = 0, look for ...lambda_0.npy or mu_0.npy
    for idx, row in lls.iterrows():
        curv_val = row['Lambda-Mu']
        curv_type = 'lambda' if curv_val[0] == '-' else 'mu'
        model_type = 'hyperbolic' if curv_type == 'lambda' else 'spherical'
        model_files = glob.glob("{}/{}_data/curvature/{}/{}_{}_{}_model_coords_sigma_{}_dim_{}_{}_{}.npy".format(
            directory, domain, subject, subject, domain, model_type, sigma, dim, curv_type, curv_val)
        )
        # enter coordinates for each model dimension
        if len(model_files) > 0:
            model_file = model_files[0]
            points = np.array(np.load(model_file))
            data[curv_val] = points
            # calculate distances correctly...
            distances = pdist(points)
            rms_dists_by_dim[d] = np.sqrt(np.mean([d ** 2 for d in distances]))

    data['rawLLs'] = []  # enter raw log-likelihoods
    data['debiasedRelativeLL'] = []
    data['biasEstimate'] = []
    best_index = lls.index[lls['Model'] == 'best']
    best_LL = lls.iloc[best_index]['Log Likelihood'].values[0]
    data['bestModelLL'] = best_LL
    data['metadata'] = ("README\n\nrawLLs[i] is the raw model LL for model with i dimensions\n"
                        "biasEstimate[i] is the median bias estimated for the i-dimensional model, \n"
                        "  based on the RMS distance: sigma\n\n"
                        "debiasedRelativeLL = (rawLLs + biasEstimate) - bestModelLL\n"
                        "--------------------------------------------------------------------------")
    temp = {'bias': {}, 'debiasedLL': {}, 'rawLL': {}}
    for idx, row in lls.iterrows():
        model = 'dim' + str(row['Model'][:-1]) if row['Model'][-1] == 'D' else row['Model']
        if model[0:3] == 'dim':
            # get bias for each model LL
            dim = int(model[3:])
            temp['rawLL'][dim] = row['Log Likelihood']
            bias = read_out_median_bias(
                bias_df, dim, rms_dists_by_dim[dim], tolerance=0.5, samples=70)
            temp['bias'][dim] = bias
            # record debiased model LLs
            temp['debiasedLL'][dim] = row['Log Likelihood'] - (best_LL - bias)
    data['biasEstimate'] = [temp['bias'][key] for key in range(min_dim, max_dim + 1)]
    data['rawLLs'] = [temp['rawLL'][key] for key in range(min_dim, max_dim + 1)]
    data['debiasedRelativeLL'] = [temp['debiasedLL'][key] for key in range(min_dim, max_dim + 1)]
    savemat("{}/{}_coords_{}.mat".format(outdir, domain, subject), data)


def json_to_pairwise_choice_probs(filepath):
    names_to_id = stimulus_name_to_id()
    with open(filepath) as file:
        ranking_responses_by_trial = json.load(file)

    # break up ranking responses into pairwise judgments
    pairwise_comparison_responses = {}
    pairwise_comparison_num_repeats = {}
    for config in ranking_responses_by_trial:
        comparisons, num_repeats = ranking_to_pairwise_comparisons(all_distance_pairs(config),
                                                                   ranking_responses_by_trial[config]
                                                                   )
        for key, count in comparisons.items():
            pairs = key.split('<')
            stim1, stim2 = pairs[1].split(',')
            stim3, stim4 = pairs[0].split(',')
            new_key = ((names_to_id[stim1], names_to_id[stim2]), (names_to_id[stim3], names_to_id[stim4]))
            if new_key not in pairwise_comparison_responses:
                pairwise_comparison_responses[new_key] = count
                pairwise_comparison_num_repeats[new_key] = num_repeats[key]
            else:
                # if the comparison is repeated in two trials (context design side-effect)
                pairwise_comparison_responses[new_key] += count
                pairwise_comparison_num_repeats[new_key] += num_repeats[key]
    return pairwise_comparison_responses, pairwise_comparison_num_repeats


def write_choice_probs_to_mat(filepath, outdir, outfilename, include_names=False):
    """
    In output mat file, in responses matrix, ref, s1 and s2 go from 1-37 or 1-25 in JV's experiments.
    Because Matlab has 1-indexing this is better - allows indexing stim_list more natural.
    @param include_names:
    @param filepath: path to exp.json file with rank judgments
    @param outdir: directory to write mat file in
    @param outfilename: name of output file. May include subject and/ or condition and/ or num_sessions information
    @return:
    """
    responses_dict, n_repeats = json_to_pairwise_choice_probs(filepath)
    first_pair, second_pair, comparison_counts, comparison_repeats = judgments_to_arrays(responses_dict, n_repeats)
    stim_list = stimulus_names()
    responses_col_names = ['ref', 's1', 's2', 'N(D(ref, s1) > D(ref, s2))', 'N_Repeats(D(ref, s1) > D(ref, s2))']
    num_comparisons = len(first_pair)
    # hold (ref, s1, s2) tuples with labels instead of numbers
    ref_name = []
    s1_name = []
    s2_name = []

    responses = np.zeros((num_comparisons, len(responses_col_names)))

    for i in range(num_comparisons):
        ref = [s for s in first_pair[i] if s in second_pair[i]]
        if len(ref) != 1:
            raise ValueError('Expected one element in common. Just one ref')
        responses[i, 0] = ref[0] + 1
        s1 = [s for s in first_pair[i] if s != ref[0]][0]
        responses[i, 1] = s1 + 1
        s2 = [s for s in second_pair[i] if s != ref[0]][0]
        responses[i, 2] = s2 + 1
        responses[i, 3] = comparison_counts[i]
        responses[i, 4] = comparison_repeats[i]
        # record names of ref, s1 and s2 for the curre
        # nt comparison trial
        ref_name.append(stim_list[ref[0]])
        s1_name.append(stim_list[s1])
        s2_name.append(stim_list[s2])

    data = {
        'stim_list': stim_list,
        'responses_colnames': responses_col_names,
        'responses': responses
    }
    if include_names:
        data['ref_name'] = ref_name
        data['s1_name'] = s1_name
        data['s2_name'] = s2_name
    savemat("{}/{}.mat".format(outdir, outfilename), data)


if __name__ == '__main__':
    subjects = ['JF']  # 'MC', 'SJ', 'SAW', 'YCL', 'AJ', 'SN', 'ZK', 'BL', 'EFV', 'SA', 'NK', 'CME']   # 'JF' , 'CME',
    for subject in subjects:
        combine_model_npy_files_to_mat(
            '/Users/suniyya/Dropbox/Research/Thesis_Work/Psychophysics_Aim1/geometric-modeling/euclidean',
            'texture',
            subject, outdir='.', min_dim=1, max_dim=7)
        # write_choice_probs_to_mat(
        #     '/Users/suniyya/Dropbox/Research/Thesis_Work/Psychophysics_Aim1/experiments/experiments'
        #     '/{}_exp/subject-data/preprocessed/{}_{}_exp.json'.format(domain, subject, domain),
        #     '/Users/suniyya/Desktop', '{}_{}_choices'.format(subject, domain), include_names=False)
