import logging
import pandas as pd
from ..model.compare_curved_space_models import run

LOG = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

if __name__ == '__main__':
    # NOTE: ########################################
    # Values of lambda and mu are hard-coded inside run function
    # scripts was lambda^2 and mu^2 = 1/R^2 according to definition of Gaussian scripts...
    # now corrected to lambda for hyp and 2mu for sph


    CONFIG, STIMULI, NAMES_TO_ID, ID_TO_NAME = read_in_params()
    # disable unneeded params
    CONFIG['scripts'] = None
    CONFIG['spherical'] = None
    CONFIG['hyperbolic'] = None


    print(CONFIG)

    domain = input('Domain: ')
    SUBJECTS = input('Subjects (separated by spaces): ').split(' ')
    print(SUBJECTS)
    proceed = input('If subjects correct, press "y" to proceed')
    if proceed != 'y':
        raise IOError

    DIM = int(input('Number of Dimensions: '))
    OUTDIR = input('Output directory for LLs and coordinates: ')


    for subject in SUBJECTS:
        print(subject)
        INPUT_DATA = '/Users/suniyya/Dropbox/Research/Thesis_Work/Psychophysics_Aim1/experiments/' \
                     'experiments/{}_exp/subject-data/preprocessed/{}_{}_exp.json'.format(domain, subject, domain)
        judgments, repeats = json_to_pairwise_choice_probs(INPUT_DATA)

        dfs = []
        ARGS = (judgments, repeats, CONFIG, subject, domain, DIM, OUTDIR)
        result = run(ARGS)
        dfs.append(result)

        total_df = pd.concat(dfs)
        print(total_df)
        total_df.to_csv('{}/curvature_and_LL_{}-{}-{}_combined_likelihoods.csv'.format(OUTDIR, subject, domain, DIM))
