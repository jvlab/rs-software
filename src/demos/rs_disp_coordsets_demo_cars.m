%rs_disp_coordsets_demo_cars: display datasets in an unstrucured domain (no stimulus coordinates)
%
% run after rs_disp_coordsets_demo
%
% See also:  RS_DISP_COORDSETS.
%
aux=struct;
aux.opts_disp.set_labels=data_out.sets{1}.subj_id;
for idim=2:4
aux.opts_disp.dim_select=idim;
    rs_disp_coordsets(data_out,aux); %standard plots, each dimension available
end
%

