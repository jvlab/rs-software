function [data_out,aux_out]=rs_get_coordsets(fullnames,aux)
% [data_out,aux_out]=rs_get_coordsets(fullnames,aux): get one or more sets of coordinates and metadata
%    handles experimental data and (for binary texture experiments) quadratic form models
% 
% Input:
% fullnames: a single file name (with path), or a cell array of file names; if empty, it will be requested interactively
%      File names must contain the string '_coords'.  Setup file names are automatically generated.
% aux: structure of auxiliary inputs
%   aux.opts_read:
%     if_gui: 1 to use graphical interface to get files if file names are not supplied (default), 0 to use console
%     if_uselocal: 0 to use options in rs_aux_defaults (default), 1 to use psg_localopts
%     if_log: 1 to log (log=0 still shows warnings)
%     if_warn: 1 to show warnings (defaults to 0)
%     if_auto: 1 not to ask for confirmations, and to use all defaults for model specifications
%     nfiles_max: maximum number of files to read (defaults to 100)
%     input_type: 0 data or model, 1 forces experimental data, 2 forces quadratic form model, can be a scalar, or an array that is cycled through for each dataset
%     data_fullnames: cell array of data file full names; if empty, will be requested
%     setup_fullnames: cell array of setup file full names; if empty, will be requested
%    The need for a setup file is determined as follows:
%    A 'type class' is determined from the data file name in psg_read_coorddata.
%     If it contains 'faces_mpi', type class is faces_mpi (faces pilot data), setup IS needed
%     If it contains 'irgb', type class is 'irgb' (color texture pilot data), setup IS needed
%     If it contains 'mater', type class is 'mater' (material pilot data), setup IS needed
%     If it contains opts_read.type_class_aux, type class is set to type_class_aux, NO setup
%     If it contains one of the strings in opts_read.domain_list_def, type class is 'domain', NO setup
%     Otherwise, type_class is set to opts_read.type_class_def, and a setup IS needed
%    for other fields, see see psg_get_coordsets.
%    The setup file, if needed, is constructed from fullnames{ifile} in psg_get_coordsets,
%      by taking the segment up to the opts_read.coord_string, and appending opts_read.setup_suffix, which may be empty
%    If the coords file is not a raw data file (i.e,. is the result of processing, and has been written out
%      by this package), it may contain an embedded setup file, in which case, an external setup file is read.
%   aux.nsets: number of datasets to read, if zero (default), then requested at console
%   aux.opts_rays: options for parsing stimulus descriptors into rays, see psg_findrays
%   aux.opts_qpred: options for creating model coordinate sets from quadratic form, see psg_qformpred
%
% For non-interactive reading, provide fullnames, aux.opts_read.input_type, and set aux_opts_read.if_auto=1 (see rs_get_coordsets_example.m)
% For interactive reading, leave fullnames empty, specify aux.opts_read.if_gui [0 1], and optionally specify aux.nsets
%
% If fullnames and aux.nsets are incompatible, a warning is issued; data_out is empty, and warnings are in aux_out.warnings
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
aux_out=struct;
data_out=struct;
aux_out.warnings=[];
%
if ~iscell(fullnames)
    fullnames_list{1}=fullnames;
else
    fullnames_list=fullnames;
end
nsets=abs(aux.nsets);
nsets_named=length(fullnames_list);
if isempty(fullnames) || isempty(fullnames_list)
    nsets_named=0;
end
if nsets_named==0
    %If fullnames is empty, then set nsets to psg_get_coordsets as positive or negative
    if nsets>0
        if aux.opts_read.if_gui>0
            aux.nsets=-nsets; %flag for psg_get_coordsets to use gui
        else
            aux.nsets=nsets;
        end
    end
else %If fullnames is not empty, check that its length agrees with nsets and that each contains _coords
    if isempty(nsets)
        nsets=nsets_named;
        aux.nsets=nsets;
    end       
    if nsets_named~=nsets
        wmsg=sprintf('number of files listed (%3.0f) disagrees with number of files specified (%3.0f)',nsets_named,nsets);
        warning(wmsg);
        aux_out.warnings=strvcat(aux_out.warnings,wmsg);
    end
    for iset=1:nsets_named
        if ~contains(fullnames{iset},aux.opts_read.coord_string)
            wmsg=sprintf('file name %2.0f (%s) does not contain the required tag ''%s''',iset,fullnames{iset},aux.opts_read.coord_string);
            warning(wmsg);
            aux_out.warnings=strvcat(aux_out.warnings,wmsg);
        end
    end
    %attempt to read automatically
    aux.opts_read.data_fullnames=fullnames_list;
    %create setup files
    aux.opts_read.setup_fullnames=cell(1,nsets_named);
    for iset=1:nsets_named
        setup_file=fullnames{iset};
        cpos=min(strfind(setup_file,aux.opts_read.coord_string));
        if ~isempty(cpos)
            setup_file=setup_file(1:cpos-1);
        end
        setup_file=strrep(setup_file,'.mat','');
        setup_file=cat(2,setup_file,aux.opts_read.setup_suffix,'.mat');
        aux.opts_read.setup_fullnames{iset}=setup_file;
    end
end
if isempty(aux_out.warnings)
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
    end
return
end
