%rs_aux_customize_test: test rs_aux_customize
%
%  See also:  RS_AUX_CUSTOMIZE, RS_AUX_DEFAULTS_DEFINE, RS_BENCHMARK_COMPARE.
%
aux_out=rs_aux_customize(setfield(struct,'opts_test',setfield(struct(),'param1',7)),'rs_dummy');
save tests/rs_aux_customize_test.mat aux_out
ifdif=rs_benchmark_compare('rs_aux_customize_test');
