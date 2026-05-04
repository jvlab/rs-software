%rs_disp_coordsets_demo_cars: 
% demonstration of display of a datast, for an unstructured domain (no stimulus coordinates)
% run after rs_disp_coordsets_demo
%
aux=struct;
aux.opts_disp.set_labels=data_out.sets{1}.subj_id;
for idim=2:3
aux.opts_disp.dim_select=idim;
    rs_disp_coordsets(data_out,aux); %standard plots, 2,3, and 4 d
end
%
