%rs_auto_test: run all tests in automatic mode
clear;
if_auto_skip=1;
rs_aux_customize_test;
rs_get_coordsets_test;
rs_read_coorddata_test;
rs_align_coordsets_test;
