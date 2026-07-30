"""
    Demo to fit models of Euclidean spaces of different dimensions, from tallied similarity judgments.
    Enter '0' to use default values.
"""
import logging
from pathlib import Path
from src.rs_py.utils.config import CONFIG
from src.rs_py.scripts.model_fitting import fit


def demo_inputs():
    """
    Populate demo defaults.
    Adjust the default filepath/outdir to wherever your sample materials live.
    """
    base_dir = Path(__file__).resolve().parent.parent
    model_defaults = CONFIG["inputs"]["model_fit"]

    defaults = {
        "filepath": (base_dir / "samples/choice_files/image_choices_S4.mat").resolve(),
        "exp_name": "image",
        "subject": "S4",
        "output_dir": (base_dir / "samples/outputs").resolve(),
        "sigma": model_defaults['sigma'],
        "model_dimensions": model_defaults['model_dimensions'],
        "learning_rate": model_defaults['learning_rate'],
        "tolerance": model_defaults['tolerance'],
        "max_trials": model_defaults['max_trials'],
        "max_iterations": model_defaults['max_iterations'],
        "minimization": model_defaults['minimization']
    }
    # Creates the folder if missing; does nothing if it already exists
    defaults["output_dir"].mkdir(parents=True, exist_ok=True)

    return defaults


def _use_default(val):
    if val.strip() == "" or val.strip() == "0":
        return True
    else:
        return False


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    LOG = logging.getLogger(__name__)

    # enter path to subject data (json file)
    FILEPATH = input("Path to the combined choices file for a participant:\n>> ")
    EXP = input("Experiment name:\n>> ")
    SUBJECT = input("Subject name or ID:\n>> ")
    OUTDIR = input("Output directory :\n>> ")
    print("The following arguments are optional. ")
    MODEL_DIMENSIONS = input("\tEnter the dimensionality of models to fit in a comma separated list.\n"
                             "\tDefault: [1, 2, 3, 4, 5]\n>>")
    SIGMA = input("\tEnter a noise level to model error in comparing distances:\n"
                  "\tDefault: 1\n>>")
    FILTER_TRIALS = input("\tEnter the maximum number of triadic judgments to use. Enter 0 to use all data:\n"
                          "\tDefault: 'uses all\n>>'")
    MAX_ITER = input("\tEnter the maximum number of iterations before returning the final model:\n"
                     "\tDefault: 50000\n>>")
    LEARN_RATE = input("\tEnter learning rate to use for minimization:\n"
                       "\tDefault: 0.05\n>>")
    TOLERANCE = input("\tEnter acceptable tolerance for difference between iterations (stopping criterion):\n"
                      "\tDefault: 1e-6\n>>")
    MINIM = input("\tEnter minimization algorithm (opts: nelder-mead, gradient-descent)\n"
                  "\tDefault: gradient-descent\n>>")

    CONFIG = demo_inputs()
    # fill in defaults if missing arguments - for demo provide defaults for required args.
    # in the accompanying script, missing required args will cause an error to be thrown.
    args = {
        "exp_name": CONFIG["exp_name"] if _use_default(EXP) else EXP,
        "filepath": CONFIG["filepath"] if _use_default(FILEPATH) else FILEPATH,
        "filter_trials": CONFIG["max_trials"] if _use_default(FILTER_TRIALS) else int(FILTER_TRIALS),
        "learning_rate": CONFIG["learning_rate"] if _use_default(LEARN_RATE) else float(LEARN_RATE),
        "max_iterations": CONFIG["max_iterations"] if _use_default(MAX_ITER) else int(MAX_ITER),
        "minimization": CONFIG["minimization"] if _use_default(MINIM) else MINIM,
        "model_dimensions": (
            CONFIG["model_dimensions"]
            if _use_default(MODEL_DIMENSIONS)
            else [int(x) for x in MODEL_DIMENSIONS.split(",")]
        ),
        "outdir": CONFIG["output_dir"] if _use_default(OUTDIR) else OUTDIR,
        "sigma": CONFIG["sigma"] if _use_default(SIGMA) else float(SIGMA),
        "subject": CONFIG["subject"] if _use_default(SUBJECT) else SUBJECT,
        "tolerance": CONFIG["tolerance"] if _use_default(TOLERANCE) else float(TOLERANCE),
    }
    args['noise_st_dev'] = args['sigma']

    fit(args)

