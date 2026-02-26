CONFIG = {
    'common': {
        'epsilon': 1e-30,
        'verbose': False
    },
    'dataset': {
        'name': 'animals',                # required
        'subject': 'S4',                       # required
        'num_sessions': 10,
        'stimfile': '../samples/stimuli.txt'    # required
    },
    'inputs': {
        'detailed_choice': {
            'input_path': None,                  # required
            'output_dir': None,                 # required
            'comparison_type': 'triadic',
        },
        'combined_choice': {
            'input_path': None,                  # required
            'output_dir': None,                 # required

        },
        'model_fit': {
            'num_stimuli': 37,
            'num_stimuli_per_trial': 8,  # daikho
            'overlap': 2,  # daikho,
            'sigma': {
                'compare': 1,
                'dist': 0
            },
            'stimlist': [],  # to be populated
            'max_trials': 6000,  # daikho
            'model_dimensions': [1, 2, 3, 4, 5, 6, 7],
            'num_repeats': 5,  # daikho
            'minimization': 'gradient-descent',
            'tolerance': 1e-6,  # is this used?
            'fatol': 1e-5,  # used for NM,
            'max_iterations': 35000,
            'learning_rate': 0.05,
        },
        'curve_model_fit': {

        }
    }
}

