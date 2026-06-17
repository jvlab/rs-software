# Demo 3: Combined Choice File → Geometric model

...







## Note on optimization settings

The fitting procedure stops when either:

1. the maximum number of iterations is reached, or
2. the change between iterations falls below the tolerance threshold.

If you want a faster, rougher fit, you can try:

* increasing `learning_rate`
* increasing `tolerance`

If the fit stops too early or has not settled, you can:

* increase `max_iterations`
* decrease `tolerance`

The best settings will depend on your data. For the JNeurosci 2024 analysis, we used roughly 30,000 to 50,000 iterations for the main fits.


