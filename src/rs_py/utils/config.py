from pathlib import Path
base_dir = Path(__file__).resolve().parent.parent

CONFIG = {
    'verbose': False,
    'dataset': {
        'name': 'animals',                # required
        'subject': 'S4',                       # required
        'num_sessions': 10,
        'stimfile': (base_dir / 'samples/stimuli.txt').resolve()    # required
    },
    'inputs': {
        'detailed_choice': {
            'input_path': None,                  # required
            'output_dir': None                   # required
        },
        'combined_choice': {
            'input_path': None,                  # required
            'output_dir': None,                 # required
            'comparison_type': 'triadic'
        },
        'model_fit': {
            'num_stimuli': 37,
            # 'num_stimuli_per_trial': 8,  # daikho
            # 'overlap': 2,  # daikho,
            'sigma': 1,
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

