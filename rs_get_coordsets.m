function [data_out,aux_out]=rs_get_coordsets(fullnames,aux)
% [data_out,aux_out]=rs_get_coordsets(fullnames,aux): get one or more sets of coordinates and metadata
%    handles experimental data and (for binary texture experiments) quadratic form models
% 
% Input:
% fullnames: a single file name (with path), or a cell array of file names; if empty, it will be reque3sted interactively
% aux: structure of auxiliary inputs
%   aux.opts_read:
%     if_gui: 1 to use graphical interface to get files if file names are not supplied (default), 0 to use console
%     if_uselocal: 0 to use options in rs_aux_defaults (default), 1 to use psg_localopts
%                 other fields: see see psg_get_coordsets
%   aux.opts_rays: options for parsing stimulus descriptors into rays, see psg_findrays
%   aux.opts_qpred: options for creating model coordinate sets from quadratic form, see psg_qformpred
%   aux.nsets: number of datasets to read, if zero (default), then requested at console
%
% Output:
%  data_out: coordinates and metadata
%    data_out.sets: cell array {1,nsets} of the dataset descriptors, Subfields of data_out.sets{iset}:
%      type: 'data' (psychophysical data) or 'qform' (quadratic form model)
%      dim_list: list of available dimensions in data_out.ds, e.g,. [1 2 3 4 5 6 7]
%      nstims: number of stimuli
%      label_long: long file name 
%      label: shortened file name
%      pipeline: structure describing geometric processing leading to this file
%         (e.g., Procrustes, other geometric transformations).  Empty if no processing done
% 
%    data_out.ds: cell array {1,nsets} of coordinates.
%      data_out.ds{iset}{nd} is a structure of coordinates (nstims x nd),
%    data_out.sas: cell array {1,nsets} of metadata. Subfields of data_out.sas{iset}:
%      nstims: number of stimuli
%      typenames: stimulus labels
%      *LL*(1,ndims): log likelihoods
%      btc_specoords(istim,:): stimulus coordinates to be used for finding rays
%      sigma_*: information about MDS settings for internal error (sigma)
% 
%  aux_out: auxiliary parameter values used
%
%  See also: PSG_GET_COORDSETS, RS_AUX_CUSTOMIZE.
%
if (nargin<=1)
    aux=struct;
end
aux=filldefault(aux,'opts_read',struct);
aux=filldefault(aux,'opts_qpred',struct);
aux=filldefault(aux,'opts_rays',struct);
aux=filldefault(aux,'nsets',0);
aux=rs_aux_customize(aux,'rs_get_coordsets');
%
if ~iscell(fullnames)
    fullnames_list{1}=fullnames;
else
    fullnames_list=fullnames;
end
[sets,ds,sas,rayss,opts_read_used,opts_rays_used,opts_qpred_used,syms_list]=...
    psg_get_coordsets(aux.opts_read,aux.opts_rays,aux.opts_qpred,aux.nsets);
data_out.sets=sets;
data_out.ds=ds;
data_out.sas=sas;
%
aux_out.opts_read=opts_read_used;
aux_out.opts_rays=opts_rays_used;
aux_out.opts_qpred=opts_qpred_used;
aux_out.rayss=rayss;
aux_out.syms_list=syms_list;
return
end
