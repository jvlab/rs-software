from pathlib import Path
import numpy as np
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
            'output_dir': None,                  # required
            'metadata': {
                'exp_name': '',
                'subject': '',
                'stim_list': [],
                'num_sessions': '',
                'num_trials': '',
                'total_judgments': '',
                'judgment_type': ''
            }
        },
        'combined_choice': {
            'input_path': None,                  # required
            'output_dir': None,                  # required
            'metadata': {
                'exp_name': '',
                'subject': '',
                'stim_list': [],
                'num_sessions': '',
                'num_trials': '',
                'total_judgments': '',
                'judgment_type': ''
            }
        },
        'model_fit': {
            'filepath': None,                   # required
            'output_dir': None,                 # required
            'exp_name': "",
            'learning_rate': 0.05,
            'max_iterations': 50000,
            'max_trials': np.inf,
            'minimization': 'gradient-descent',
            'model_dimensions': [1, 2, 3, 4, 5],
            'num_stimuli': 37,  
            'sigma': 1,
            'subject': "",
            'tolerance': 1e-6
        },
        'curve_model_fit': {

        }
    }
}

