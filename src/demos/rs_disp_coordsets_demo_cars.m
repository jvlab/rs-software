%rs_disp_coordsets_demo_cars: display datasets in an unstrucured domain (no stimulus coordinates)
%
% Normally 'data_out' is already in the workspace, having been created by
% rs_read_coorddata_demo_cars. If it is not, that demo is run first, so that this script can
% also be run standalone.
%
% See also:  RS_DISP_COORDSETS, RS_READ_COORDDATA_DEMO_CARS.
%
if ~exist('data_out')
    disp('no data found; running rs_read_coorddata_demo_cars');
    rs_read_coorddata_demo_cars;
end
aux=struct;
aux.opts_disp.set_labels=data_out.sets{1}.subj_id;
for idim=2:4
aux.opts_disp.dim_select=idim;
    rs_disp_coordsets(data_out,aux); %standard plots, each dimension available
end
%

