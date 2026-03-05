CONFIG = {
    'verbose': False,
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
            # 'num_stimuli_per_trial': 8,  # daikho
            # 'overlap': 2,  # daikho,
            'sigma': {
                'compare': 1,
                'dist': 0
            },
            'stimlist': [],  # to be populated
            'max_trials': 10000,
            'model_dimensions': [3],
            'minimization': 'gradient-descent',
            'tolerance': 1e-6,  # is this used?
            'max_iterations': 50,
            'learning_rate': 0.05,
        },
        'curve_model_fit': {

        }
    }
}

