function [data_out,aux_out]=rs_read_coorddata(fullname,aux)
% [data_out,aux_out]=rs_read_coorddata(fullname,aux) get a single set of coordinates and metadata
% and, if stimulus coordinate data are available, creates a ray structure
%
% Input:
% fullname: a single file name (with path); if empty, it will be requested interactively.  String or singleton cell array
%      File names must contain the string '_coords'. The associated setup file, if needed, is automatically generated.
% aux: structure of auxiliary inputs
%   aux.opts_read:
%     if_gui: 1 to use graphical interface to get files if file names are not supplied (default), 0 to use console
%     if_uselocal: 0 to use options in rs_aux_defaults (default), 1 to use psg_localopts
%     if_log: 1 (default) to log (0 still shows warnings)
%     if_auto: 1 not to ask confirmations, defaults to 0
%    The need for a setup file is determined as follows:
%     A 'type class' is determined from the data file name in psg_read_coorddata, by psg_coorddata_parsename.
%     If it contains 'faces', type class is faces_mpi (faces pilot data), setup IS needed
%     If it contains 'faces_mpi', type class is faces_mpi (faces pilot data), setup IS needed
%     If it contains 'irgb', type class is 'irgb' (color texture pilot data), setup IS needed
%     If it contains 'mater', type class is 'mater' (material pilot data), setup IS needed
%     If it contains opts_read.type_class_aux, type class is set to type_class_aux, NO setup
%     If it contains one of the strings in opts_read.domain_list_def, type class is 'domain', NO setup (these are in samples/animals)
%     Otherwise, type_class is set to opts_read.type_class_def, and a setup IS needed (these are the in samples/bwtextures, type class is 'btc')
%    For other fields, see see psg_read_coorddata.
%    The setup file, if needed, is constructed from fullnames{ifile} in psg_get_coordsets,
%      by taking the segment up to the opts_read.coord_string, and appending opts_read.setup_suffix, which may be empty
%    If the coords file is not a raw data file (i.e,. is the result of processing, and has been written out
%      by this package), it may contain an embedded setup file, in which case, an external setup file is read.
%
% For non-interactive reading, provide fullname, set aux_opts_read.if_auto=1 (see rs_get_coordsets_example.m)
% For interactive reading, leave fullnames empty, specify aux.opts_read.if_gui [0 1]
%
% Comparison with rs_get_coordsets:
%   * Only reads one file
%      input is a full file name not a cell array of file names
%      output is a singleton cell array of data structures
%   * Does not support augmentation by symmetry (thisoption is only available for binary texture data]
%   * Does not read quadratic form models [only applicable to binary texture data]
%
% Output:
%  data_out: coordinates and metadata
%    data_out.sets{1}: cell array {1,1} of the dataset descriptors, Subfields of data_out.sets{1}:
%      type: 'data' (psychophysical data) or 'qform' (quadratic form model)
%      dim_list: list of available dimensions in data_out.ds, e.g,. [1 2 3 4 5 6 7]
%      nstims: number of stimuli
%      label_long: long file name 
%      label: shortened file name
%      pipeline: structure describing geometric processing leading to this file
%         (e.g., Procrustes, other geometric transformations).  Empty if no processing done
%    data_out.ds: cell array {1,1} of coordinates.
%      data_out.ds{iset}{nd} is a structure of coordinates (nstims x nd),
%    data_out.sa: cell array {1,1} of metadata. Subfields of data_out.sa:
%      nstims: number of stimuli
%      typenames: stimulus labels
%      *LL*(1,ndims): log likelihoods
%      btc_specoords(istim,:): stimulus coordinates to be used for finding rays
%      sigma_*: information about MDS settings for internal error (sigma)
%  aux_out: auxiliary outputs and parameter values used
%      opts*: values used for opts_read, opts_rays
%      warnings: warnings generated in creating arguments for psg_get_coordsets
%      aux_out.rayss{1}: ray structure
%      
%
%  See also: RS_AUX_CUSTOMIZE, RS_FINDRAYS, PSG_READ_COORDDATA, PSG_MAKE_SETSTRUCT, PSG_FINDRAYS_SETOPTS, PSG_FINDRAYS.
%
if (nargin<=1)
    aux=struct;
end
aux=filldefault(aux,'opts_read',struct);
%
aux=filldefault(aux,'opts_rays',struct);
%
aux=rs_aux_customize(aux,'rs_read_coorddata');
%
data_out=struct;
aux_out=struct;
aux_out.warnings=[];
aux_out.warn_bad=0;
%
if iscell(fullname)
    fullname=fullname{1};
end
%
if isempty(fullname)
    if aux.opts_read.if_gui
        if_manual=0;
        if aux.opts_read.if_justsetup
            ui_prompt='Select a setup file';
            ui_filter={cat(2,'*',aux.opts_read.setup_suffix,'.mat'),'setup file'};
        else
            ui_prompt='Select a coordinate file';
            ui_filter={aux.opts_read.ui_filter,'coordinate file'};
        end
        while (if_manual==0 & isempty(fullname))
            [filename_short,pathname]=uigetfile(ui_filter,ui_prompt,'Multiselect','off');
            if  (isequal(filename_short,0) | isequal(pathname,0)) %use Matlab's suggested way to detect cancel
                if_manual=getinp('1 to return to selection from console','d',[0 1]);
            else
                fullname=cat(2,pathname,filename_short);
            end
        end
    end
end
if aux.opts_read.if_justsetup==0
    [d,sa,opts_read_used,pipeline]=psg_read_coorddata(fullname,[],aux.opts_read);
    opts_read_used.data_fullnames={opts_read_used.data_fullname}; %for compatibility with rs_get_coordsets
    opts_read_used.setup_fullnames={opts_read_used.setup_fullname}; %for compatibility with rs_get_coordsets
    opts_read_used.input_type_desc=aux.opts_read.input_types{1}; %rs_read_coorddata only reads experimental data, which is type 1
    sets=psg_make_setstruct('data',opts_read_used.dim_list,opts_read_used.data_fullname,sa.nstims,pipeline,struct());
    %
    [rays,wmsg,opts_rays_used]=rs_findrays(sa,opts_read_used.setup_fullname,aux.opts_rays);
    if ~isempty(wmsg)
        warning(wmsg);
        aux_out.warnings=strvcat(aux_out.warnings,wmsg);
    end
else
    setup_fullname=fullname;
    [d,sa,opts_read_used,pipeline]=psg_read_coorddata(fullname,setup_fullname,aux.opts_read);
    d=struct;
    sets=struct;
end
%
data_out.ds{1}=d;
data_out.sas{1}=sa;
data_out.sets{1}=sets;
aux_out.opts_read{1}=opts_read_used;
aux_out.opts_rays{1}=opts_rays_used;
aux_out.rayss{1}=rays;
%for compatibility with rs_get_coordsets;
aux_out.opts_qpred{1}=struct;
aux_out.syms_list=struct();
return
