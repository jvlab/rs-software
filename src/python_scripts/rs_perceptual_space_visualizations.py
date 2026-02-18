import glob
import numpy as np
import seaborn as sns
from scipy.io import loadmat
import matplotlib.pyplot as plt

from analysis.geometry.procrustes_distance import get_consensus_pts
from analysis.util import stimulus_names
from sklearn.decomposition import PCA
from matplotlib import cm
import matplotlib.ticker as ticker
from matplotlib.offsetbox import OffsetImage, AnnotationBbox
from matplotlib.cbook import get_sample_data
from matplotlib.colors import ListedColormap, LinearSegmentedColormap


def calculate_var_explained(subjects, domains, max_dim=7, by_dim=5):
    result = np.zeros((len(subjects), len(domains)))
    result[:] = np.nan
    file_string = '/Users/suniyya/Dropbox/Research/Thesis_Work/Psychophysics_Aim1/geometric-modeling/euclidean/' \
                  '{}/{}/{}_{}_anchored_points_sigma_*_dim_{}.npy'
    for i in range(len(subjects)):
        for j in range(len(domains)):
            npy_7d_file = file_string.format(domains[j], subjects[i], subjects[i], domains[j], max_dim)
            # if is file
            files = glob.glob(npy_7d_file)
            if len(files) == 1:
                print('file found')
                points = np.load(files[0])
                pca = PCA(n_components=max_dim)
                # obtain the 5 PC directions and project data onto that space
                temp = pca.fit_transform(points)
                sum_var_exp = sum(pca.explained_variance_ratio_[0:by_dim])
                result[i, j] = sum_var_exp
    return result


def do_pca(points, num_pcs=5):
    """
    Run PCA.
    Stretch axes so as to make the variance along each axis the same.
    Do so by dividing the values of the coordinate by the standard deviation of values along that axis.
    This way points along each axis will have unit variance. This does not affect the radial
    distribution of points, only their distance from the origin in different directions.
    """
    n_components = num_pcs
    pca = PCA(n_components=n_components)
    # obtain the 5 PC directions and project data onto that space
    temp = pca.fit_transform(points)
    points = temp
    return points


def scatterplots_2d_annotated(subject_name, subject_exp_data, pc1=1, pc2=2):
    sns.set_style('darkgrid')
    stimuli = stimulus_names()

    fig, ax = plt.subplots()
    plt.scatter(subject_exp_data[:, pc1 - 1], subject_exp_data[:, pc2 - 1], c="#31505A", marker='o')
    # add labels to points
    label_idx = 0
    for x, y in zip(subject_exp_data[:, pc1 - 1], subject_exp_data[:, pc2 - 1]):
        plt.annotate(stimuli[label_idx],  # this is the text
                     (x, y),  # this is the point to label
                     textcoords="offset points",  # how to position the text
                     xytext=(0, 1.5),  # distance from text to points (x,y)
                     size=10,
                     ha='center')  # horizontal alignment can be left, right or center
        label_idx += 1
    plt.xlabel('Principal Component {}'.format(pc1))
    plt.ylabel('Principal Component {}'.format(pc2))
    plt.title(subject_name)
    plt.axis('square')
    ax.set_xlim(-2, 3.5)
    ax.set_ylim(-2, 3.5)
    plt.show()


def scatterplots_2d_colored(subject_name, subject_exp_data, pc1=1, pc2=2, colorby='land'):
    sns.set_style('darkgrid')
    stimuli = stimulus_names()
    maps = {}
    # define color scheme here for now
    categories = [0, 0, 0, 0] + [1] * 28 + [0, 1, 1, 1, 0]
    # colormap by category - color water dwelling and land (non-water) dwelling
    colormap = np.array(['blue', 'brown'])
    maps['land'] = colormap[categories]
    categories2 = [0, 1, 1, 0, 3, 3, 3, 3, 3, 3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 5, 5,
                   5, 5, 4, 2, 4, 4, 4]
    # color mammals 0, fish 1, amphibians 2, birds 3, reptiles 4, insects + snail 5 separately
    colormap2 = np.array(['brown', 'blue', 'green', 'yellow', 'purple', 'black'])
    maps['kingdom'] = colormap2[categories2]
    sizes = np.log(np.array(
        [7.4, 0.17, 15, 100, 0.6, 2, 2.5, 2, 1.5, 0.5, 2.7, 0.3, 0.6, 0.25, 4.5, 1.5, 2, 1.5, 2, 3.5, 3, 5.5, 5,
         18, 10, 2, 9, 0.017, 0.2, 0.03, 0.03, 0.08, 3.5, 0.3, 0.5, 3.5, 10]))  # color coarsely by size (in ft) Google
    sizes = sizes / max(sizes)
    rainbow = cm.get_cmap('gnuplot')
    maps['size'] = [rainbow(val) for val in sizes]
    animal_colors = ['#778899', '#ffa500', '#6699cc', '#6699cc', '#6495ED', '#4a4300', '#341c02', '#7f7053', '#2f4f4f',
                     '#847D6F', '#5D4333', 'white', 'gray', '#5D4333', '#835C3B', 'gray', '#C4A484', '#C35817',
                     '#eae0c8',
                     '#efdfbb', '#202020', '#a13d2d', '#8A2D1C', '#956201', '#9e9b90', 'brown', '#D49C4A', 'black',
                     'orange',
                     'red', 'black', '#5D4333', '#BC815F', '#a69d86', '#c4be6c', '#254117',
                     '#73A16C']  # color by actual color of animal (by eye)
    maps['color'] = animal_colors

    colors = maps[colorby]
    fig, ax = plt.subplots()
    plt.scatter(subject_exp_data[:, pc1 - 1], subject_exp_data[:, pc2 - 1], c=colors, marker='o')
    # add labels to points
    label_idx = 0
    for x, y in zip(subject_exp_data[:, pc1 - 1], subject_exp_data[:, pc2 - 1]):
        plt.annotate(stimuli[label_idx],  # this is the text
                     (x, y),  # this is the point to label
                     textcoords="offset points",  # how to position the text
                     xytext=(0, 1.5),  # distance from text to points (x,y)
                     size=8,
                     ha='center')  # horizontal alignment can be left, right or center
        label_idx += 1
    plt.xlabel('Principal Component {}'.format(pc1))
    plt.ylabel('Principal Component {}'.format(pc2))
    plt.title(subject_name)
    plt.axis('square')
    ax.set_xlim(-2, 3.5)
    ax.set_ylim(-2, 3.5)
    plt.show()


def scatterplots_2d_image_annotated(subject_name, subject_exp_data, image_source, sigma, pc1=1, pc2=2,
                                    divide_by_sigma=True):
    SubjectId = {'MC': 'S1', 'BL': 'S2', 'EFV': 'S3', 'SJ': 'S4', 'SAW': 'S5', 'NK': 'S6', 'YCL': 'S7', 'SA': 'S8',
                 'JF': 'S9', 'AJ': 'S10', 'SN': 'S11', 'ZK': 'S12', 'CME': 'S13', 'consensus': 'consensus'}
    if subject_name != 'consensus':
        sns.set_style('darkgrid')
    stimuli = stimulus_names()

    if divide_by_sigma:
        subject_exp_data = subject_exp_data / sigma
    fig, ax = plt.subplots()
    plt.scatter(subject_exp_data[:, pc1 - 1], subject_exp_data[:, pc2 - 1], c="#31505A", marker='.', s=5)
    # add labels to points
    label_idx = 0
    for x, y in zip(subject_exp_data[:, pc1 - 1], subject_exp_data[:, pc2 - 1]):
        if image_source is None:
            plt.annotate(stimuli[label_idx],  # this is the text
                         (x, y),  # this is the point to label
                         textcoords="offset points",  # how to position the text
                         xytext=(np.random.normal(0.5, 3), np.random.normal(-0.5, 3)),
                         # distance from text to points (x,y)
                         size=8,
                         # alpha=1, # 0.55
                         ha='center')  # horizontal alignment can be left, right or center
            label_idx += 1
        else:
            filepath = "/Users/suniyya/Dropbox/Research/Thesis_Work/Psychophysics_Aim1/stimulus_domains/" \
                       "images/{}/{}.png".format(image_source, stimuli[label_idx])
            with get_sample_data(filepath) as file:
                arr_img = plt.imread(file)
            imagebox = OffsetImage(arr_img, zoom=0.005)
            imagebox.image.axes = ax
            ab = AnnotationBbox(imagebox, (x, y),
                                xycoords='data',
                                boxcoords="offset points",
                                pad=0.1)
            ax.add_artist(ab)
            label_idx += 1

    plt.xlabel('Principal Component {}'.format(pc1))
    plt.ylabel('Principal Component {}'.format(pc2))
    plt.title(SubjectId[subject_name])
    plt.axis('square')
    ax.yaxis.set_major_locator(ticker.MultipleLocator(1))
    ax.xaxis.set_major_locator(ticker.MultipleLocator(1))
    plt.savefig('/Users/suniyya/Dropbox/Research/Thesis_Work/Psychophysics_Aim1/geometric-modeling/euclidean/'
                'scatterplots/' + EXP + subject_name + '.svg', bbox_inches='tight', pad_inches=0.25)
    # plt.show()


if __name__ == '__main__':
    PATH_TO_NPY_FILE = input("Path to npy file containing 5D coordinates "
                             "(e.g., /Users/suniyya/Dropbox/Research/Thesis_Work/Psychophysics_Aim1/geometric-mode"
                             "ling/euclidean/intermediate_object/AJ/"
                             "AJ_intermediate_object_anchored_points_sigma_1.0_dim_5.npy: ")
    NAME = input("Subject name or ID (e.g., S7): ")
    EXP = input("Experiment name: ")
    SIGMA = float(input("Sigma used in modeling: "))

    image_source = {'word': None, 'image': 'animal_images',
                    'intermediate_object': 'animal_intermediates/image-like-opaque',
                    'intermediate_texture': 'animal_intermediates/texture-like-opaque',
                    'texture': 'animal_textures/textures_big_checks'}
    if NAME.lower() == 'consensus':
        data = get_consensus_pts(EXP)
    else:
        data = np.load(PATH_TO_NPY_FILE)
    data = do_pca(data)

    # x = do_pca(data, 7)
    scatterplots_2d_image_annotated(NAME, data, image_source[EXP], SIGMA)
