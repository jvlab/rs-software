import numpy as np
import matplotlib.pyplot as plt
from sklearn.decomposition import PCA


def plot_first_two_pcs(coords, stim_labels, title=None,
                       annotate=True, figsize=(7, 6),
                       point_size=60, alpha=0.9,
                       savepath=None):
    """
    Visualize first two principal components of any coordinate matrix.

    Parameters
    ----------
    coords : array-like (n_stim, d)
        Coordinate matrix.
    stim_labels : list[str]
        Labels for each stimulus.
    title : str
        Plot title.
    annotate : bool
        Whether to draw text labels.
    savepath : str | None
        If provided, saves figure.
    """

    coords = np.asarray(coords)
    n, d = coords.shape

    if len(stim_labels) != n:
        raise ValueError("Length of stim_labels must match number of rows in coords.")

    # If only 1D, pad with zeros
    if d == 1:
        coords = np.hstack([coords, np.zeros((n, 1))])

    pca = PCA(n_components=2)
    pcs = pca.fit_transform(coords)

    explained = pca.explained_variance_ratio_

    fig, ax = plt.subplots(figsize=figsize)
    ax.scatter(pcs[:, 0], pcs[:, 1], s=point_size, alpha=alpha)

    if annotate:
        for i, label in enumerate(stim_labels):
            ax.text(pcs[i, 0], pcs[i, 1], label, fontsize=9)

    ax.set_xlabel(f"PC1 ({explained[0]*100:.1f}% var)")
    ax.set_ylabel(f"PC2 ({explained[1]*100:.1f}% var)")
    if title:
        ax.set_title(title)

    ax.axhline(0, linewidth=0.8)
    ax.axvline(0, linewidth=0.8)

    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    plt.tight_layout()

    if savepath:
        plt.savefig(savepath, bbox_inches="tight", dpi=200)

    plt.show()

    return pcs, explained


if __name__ == '__main__':
    coords = np.load("../samples/models/S4_animals_anchored_points_sigma_1.0_dim_4.npy")
    from src.rs_py.utils.config import CONFIG
    from src.rs_py.utils.helpers import stimulus_names

    labels = stimulus_names(CONFIG['dataset']['stimfile'])  # or your stim list

    plot_first_two_pcs(
        coords,
        labels,
        title="Animals embedding (PC1 vs PC2)"
    )