from pathlib import Path
base_dir = Path(__file__).resolve().parent.parent

CONFIG = {
    'verbose': False,
    'dataset': {
        'name': None,                           # required
        'subject': None,                        # required
        'num_sessions': None
    },
    'inputs': {
        'detailed_choice': {
            'input_path': None,                  # required
            'output_dir': None                   # required
        },
        'combined_choice': {
            'input_path': None,                  # required
            'output_dir': None,                  # required
            'metadata': {
                'exp_name': 'unknown',
                'subject': 'unknown',
                'stim_list': [],
                'num_sessions': 'unknown',
                'num_trials': None,
                'total_judgments': None,
                'judgment_type': 'triadic'
            }
        },
        'model_fit': {
            'num_stimuli': 37,  
            'sigma': 1,               # required   # should normally be kept at 1. # what is it? 1 sd in the error in the noise in the distance comparisons. JoVE paper for similar language. It is required and everything scales by it.
            'max_trials': 10000,      # make default np.inf - keep - what happens when you have less data (RANDOM)
            'model_dimensions': [1, 2, 3, 4, 5],    # required - but document what combinations can be given, 1-5 default. Tested up to 10. choice may depend on num stim
            'minimization': 'gradient-descent',     # 'nelder-mead' is opt but grad desc is faster.
            'tolerance': 1e-6,  # is this used?     # stopping criterion log2 (CHECK)
            'max_iterations': 50,                   # 50K - 80K. curvature 30K. -> include num its done in coords file. And printed in console.
            'learning_rate': 0.05,                  # only relevant for gradient descent. recommended value.
        },
        'curve_model_fit': {

        }
    }
}

