For combined choice files, include either:

* `responses_colnames`
* `responses`
* `stim_list`

or:

* `responses_colnames`
* `responses`
* `metadata`, with `stim_list` inside `metadata`

`stim_list` must be stored so that each stimulus is one complete string. Use a string array or a cell array of character vectors. Do not save `stim_list` as a padded character matrix, because Python may read each entry as individual characters instead of a full string.
This also holds for `responses_colnames.`

If `stim_list` is empty, modeling will fail. It is a required field, and is needed to write a final output file. 


Choices files have stim_list, 
Coords files has stim_labels  -> explain what this means and what it corresponds to. Basically what the order is
so one knows why it's important.


