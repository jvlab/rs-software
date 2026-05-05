%rs_disp_coordsets_demo_opposites 
% demonstration of display of a dataset (three subjects) for a structured domain 
% run after rs_disp_coordsets_demo
%
% See also:  RS_DISP_COORDSETS.
aux=struct;
for ifile=1:nfiles %label each dataset by subject ID
    aux.opts_disp.set_labels{ifile}=data_out.sets{ifile}.subj_id;
end
aux.opts_disp.set_colors={'b','r','g'}; %custom colors for the datasets
aux.opts_disp.connect_sets_method='all'; %connect datasets
for idim=2:3
aux.opts_disp.dim_select=idim;
    rs_disp_coordsets(data_out,aux); %standard plots, 2,3, and 4 d
end
%
