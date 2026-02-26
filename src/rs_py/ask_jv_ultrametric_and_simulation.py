"""
A module to help create and sample from ultrametric trees.
It also includes a distance function  that given two nodes calculates the distance between them.
The distance metric is given by the length to the most recent common ancestor.
"""

import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt


class Node:
    def __init__(self, val):
        self.val = val
        self.children = []
        self.parent = None


def make_tree(b_factor, height):
    n = sum([b_factor ** h for h in range(height+1)])
    print("total nodes: ", n)
    i = 1
    base = root = Node(0)
    queue = [root]
    while i < n:
        frontier = []
        for node in queue:
            for j in range(b_factor):
                child_node = Node(i)
                child_node.parent = node
                node.children.append(child_node)
                frontier.append(child_node)
                i += 1
                if i == n:
                    break
        queue = frontier
    return base


def get_leaves(root):
    queue = [root]
    result = []
    while len(queue) > 0:
        frontier = []
        for node in queue:
            if not node.children:
                result.append(node)
            for child in node.children:
                frontier.append(child)
        queue = frontier
    return result


def get_path(target, root):
    # returns path from leaf to root, bottom up
    path = []
    u = target
    while u.val != root.val:
        path.append(u)
        u = u.parent
    path.append(root)
    return path


def print_path(path):
    names = [p.val for p in path]
    print(names)


def cross(path1, path2):
    # assumes paths are bottom up, from leaf to root
    step = 0
    for step in range(len(path1)):
        if path1[step].val == path2[step].val:
            return step
    return step


def main():
    root = make_tree(2, 6)
    num_sample = 37
    print("root: ", root.val)
    print("root children: ", root.children)
    leaves = get_leaves(root)
    print([leaf.val for leaf in leaves])
    sample = np.random.choice(leaves, num_sample, False)
    distance_matrix = np.zeros((num_sample, num_sample))
    for i in range(len(sample)):
        for j in range(i):
            path_ri = get_path(sample[i], root)
            path_rj = get_path(sample[j], root)
            distance_matrix[i, j] = cross(path_ri, path_rj)
    sns.heatmap(distance_matrix)
    plt.show()


if __name__ == "__main__":
    main()
