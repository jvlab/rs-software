# Repository Coverage

[Full report](https://htmlpreview.github.io/?https://github.com/jvlab/rs-software/blob/python-coverage-comment-action-data/htmlcov/index.html)

| Name                                                     |    Stmts |     Miss |   Cover |   Missing |
|--------------------------------------------------------- | -------: | -------: | ------: | --------: |
| src/rs\_py/\_\_init\_\_.py                               |        0 |        0 |    100% |           |
| src/rs\_py/choices/\_\_init\_\_.py                       |        0 |        0 |    100% |           |
| src/rs\_py/choices/choice\_file\_combined.py             |       89 |        0 |    100% |           |
| src/rs\_py/choices/choice\_file\_detailed.py             |      141 |        2 |     99% |  199, 283 |
| src/rs\_py/choices/choice\_likelihoods.py                |       49 |        0 |    100% |           |
| src/rs\_py/geometry/\_\_init\_\_.py                      |        0 |        0 |    100% |           |
| src/rs\_py/geometry/euclidean.py                         |       24 |        3 |     88% | 34, 44-45 |
| src/rs\_py/geometry/hyperbolic.py                        |       15 |        0 |    100% |           |
| src/rs\_py/geometry/spherical.py                         |       18 |        0 |    100% |           |
| src/rs\_py/model/\_\_init\_\_.py                         |        0 |        0 |    100% |           |
| src/rs\_py/model/compare\_curved\_space\_models.py       |       73 |       73 |      0% |    19-117 |
| src/rs\_py/model/fit\_geometric\_models.py               |      108 |      108 |      0% |     1-245 |
| src/rs\_py/scripts/\_\_init\_\_.py                       |        0 |        0 |    100% |           |
| src/rs\_py/scripts/model\_fitting.py                     |      136 |      136 |      0% |     3-337 |
| src/rs\_py/scripts/run\_curved\_space\_model\_fitting.py |       30 |       30 |      0% |      1-48 |
| src/rs\_py/scripts/write\_choice\_file.py                |       46 |       46 |      0% |      3-78 |
| src/rs\_py/scripts/write\_choice\_file\_detailed.py      |       46 |       46 |      0% |     4-107 |
| src/rs\_py/utils/\_\_init\_\_.py                         |        0 |        0 |    100% |           |
| src/rs\_py/utils/anchor\_coordinates.py                  |       58 |        2 |     97% |     46-47 |
| src/rs\_py/utils/config.py                               |        4 |        4 |      0% |       1-5 |
| src/rs\_py/utils/helpers.py                              |      134 |      114 |     15% |11-22, 29-40, 46-50, 55, 105-141, 158-204, 288-326 |
| src/rs\_py/utils/logging.py                              |       21 |       21 |      0% |      1-45 |
| src/rs\_py/utils/mds\_embedding.py                       |       36 |        4 |     89% |     86-89 |
| src/rs\_py/utils/minimize.py                             |       25 |       25 |      0% |      2-39 |
| src/rs\_py/utils/util.py                                 |       95 |       39 |     59% |72-76, 97-139, 164-165 |
| **TOTAL**                                                | **1148** |  **653** | **43%** |           |


## Setup coverage badge

Below are examples of the badges you can use in your main branch `README` file.

### Direct image

[![Coverage badge](https://raw.githubusercontent.com/jvlab/rs-software/python-coverage-comment-action-data/badge.svg)](https://htmlpreview.github.io/?https://github.com/jvlab/rs-software/blob/python-coverage-comment-action-data/htmlcov/index.html)

This is the one to use if your repository is private or if you don't want to customize anything.

### [Shields.io](https://shields.io) Json Endpoint

[![Coverage badge](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/jvlab/rs-software/python-coverage-comment-action-data/endpoint.json)](https://htmlpreview.github.io/?https://github.com/jvlab/rs-software/blob/python-coverage-comment-action-data/htmlcov/index.html)

Using this one will allow you to [customize](https://shields.io/endpoint) the look of your badge.
It won't work with private repositories. It won't be refreshed more than once per five minutes.

### [Shields.io](https://shields.io) Dynamic Badge

[![Coverage badge](https://img.shields.io/badge/dynamic/json?color=brightgreen&label=coverage&query=%24.message&url=https%3A%2F%2Fraw.githubusercontent.com%2Fjvlab%2Frs-software%2Fpython-coverage-comment-action-data%2Fendpoint.json)](https://htmlpreview.github.io/?https://github.com/jvlab/rs-software/blob/python-coverage-comment-action-data/htmlcov/index.html)

This one will always be the same color. It won't work for private repos. I'm not even sure why we included it.

## What is that?

This branch is part of the
[python-coverage-comment-action](https://github.com/marketplace/actions/python-coverage-comment)
GitHub Action. All the files in this branch are automatically generated and may be
overwritten at any moment.