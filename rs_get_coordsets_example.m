%demo of file non-interactive reading a file
filenames_example={'./samples/bwtextures/bgca3pt_coords_MC_sess01_10.mat','./samples/bwtextures/bdce3pt_coords_MC_sess01_10.mat','./samples/bwtextures/bgca3pt_coords_BL_sess01_10.mat'};
aux=struct;
aux.opts_read=setfields(struct(),{'if_gui','input_type','if_auto'},{1,[1 2 1],1});
aux.nsets=3;
[data_out,aux_out]=rs_get_coordsets(filenames_example,aux);
