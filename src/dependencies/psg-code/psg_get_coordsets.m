function [sets,ds,sas,rayss,opts_read_used,opts_rays_used,opts_qpred_used,syms_list]=psg_get_coordsets(opts_read,opts_rays,opts_qpred,nsets)
% [sets,ds,sas,rayss,opts_read_used,opts_rays_used,opts_qpred_used,syms_list]=psg_get_coordsets(opts_read,opts_rays,opts_qpred,nsets)
% reads in one or more coordinate sets, either from a data file or via quadratic form prediction
% and checks for consistency of number of stimuli and stimulus typenames
%
% opts_read: options for psg_read_coorddata, can be empty or omitted
%   opts_read.if_log: 1 (default) to log (0 still shows warnings)
%   opts_read.if_warn: 1 to show warnings (defaults to 0)
%   opts_read.nfiles_max: maximum number of files to read (defaults to 100)
%   opts_read.input_type: 0 for either, 1 forces expemental data, 2 forces quadratic form, can be a scalar, or an array that is cycled through for each dataset
%   opts_read.data_fullnames: cell array of data file full names; if empty, will be requested
%   opts_read.setup_fullnames: cell array of setup file full names; if empty, will be requested
%   opts_read.if_auto: 1 not to ask if ok, and to use all defaults for qform model
%   opts_read.if_symaug: defaults to 0.  1 to augment by symmetry, -1 to ask (only applies to data, not to models)
%   opts_read.if_symaug_log: defaults to 0. 1 to log symmetry augmentation
%   opts_read.sym_apply: type of symmetry to apply (defaults to 'full', see psg_btcsyms for alternatives)
%   
% opts_rays: options for psg_findrays, can be empty or omitted
% opts_qpred: options for psg_qformpred, can be empty or omitted. as well
%            as default options for qform_datafile and qform_modeltype
%      qform_datafile_def is the default name of the file with quadratic form models, used for all sets read here
%      This file has a field r, and each r{imodel} has at least setup.label and results.qfit
%      qform_modeltype is a list of indexes into qform_datafile_def, to be used as imodel.  Used cyclically across isets if needed.  0 -> ask at console
%      A data file is still needed, as this specifies the stimulus names.
% nsets: if present, number of datasets. otherwise requested from console
%   if negative, or entered as negative, then a dialog box is used to load files
%
% sets: cell array, sets{iset} is a structure of that describes the dataset
% ds: cell array, ds{iset}{nd} is a structure of coordinates (nstims x nd), other fields have available dimensions and a label
% sas: cell array, sas{iset} is the setup structure returned by psg_read_coorddata
% rayss: cell array, rays{iset} is the ray structure returned by psg_findrays
% opts_read_used, opts_rays_used, opts_qpred_used: cell arrays of options used for each set
% syms_list: describes the symmetries applied, empty if no symmetry augmentation
%   syms_list.sym_apply: the symmetry name (see psg_btcmeta_symapply)
%   syms_list.primary(iset): the primary set that was augmented
%   syms_list.aug(iset):   which symmetry augmentation
%   syms_list.syms_applied{iset}: btc coords resulting from the symmetry
%
% 05Jan23: shortened sets{iset}.label; preserved original label as sets{iset}.label_long
% 27Jun23: override mode with single-point for rays, and suppressing ray angle calculation and plotting (for bcpm24pt and similar)
% 28Jun23: invoke psg_findray_setopts for ray defaults
% 25Sep23: add opts_read.input_type, option to force either experimental data (1) or model data (2)
% 27Sep23: add pipeline field to sets (always empty for qform model)
% 22Feb24: localization params now from psg_localopts
% 23Feb24: add data_fullnames, setup_fullnames, if_auto
% 28Apr24: add if_data_only (set to allow only experimental data to be read)
% 04May24: nsets can be negative, allowing for a dialog box to load multiple datasets
% 29May24: fixed bug if nsets=-1
% 21Sep24: easier abort from uigetfile file selection
% 01Oct24: add if_warn. nfiles_max
% 14Oct24: add ui_filter to allow for custom filtering of file names
% 17Oct24: allow for variable number of files with ui dialog box
% 16May25: allow for augmentation of input files by symmetry (opts_read.if_symaug) for data files
% 07Jun25: allow for augmentation of input files by symmetry for qform files
% 08Jun25: add syms_list
% 11Sep25: add if_uselocal for compatibility with rs package
% 22Sep25: modularize creation of sets
% 11Nov25: if_log=0 also suppresses confirmation on loading a qform model
% 06May26: changes related to qform model for compatibility with rs package
%
%  See also: PSG_PROCRUSTES_DEMO, PSG_FINDRAYS, PSG_QFORMPRED, PSG_READ_COORDDATA, PSG_VISUALIZE_DEMO,
%  PSG_CONSENSUS_DEMO, PSG_FINDRAY_SETOPTS, PSG_LOCALOPTS, PSG_COORD_PIPE_PROC, PSG_COORDS_FILLIN,
%  PSG_BTCSYMS, PSG_BTCMETA_SYMAPPLY, PSG_MAKE_SETSTRUCT, PSG_COORDDATA_PARSENAME.
%
if nargin<1
    opts_read=struct();
end
if nargin<2
    opts_rays=struct();
end
if nargin<3
    opts_qpred=struct();
end
if nargin<4
    nsets=[];
end
opts_read=filldefault(opts_read,'if_uselocal',1); %rs package will typically set this to zero
opts_read=filldefault(opts_read,'input_types',{'experimental data','qform model'});
opts_read=filldefault(opts_read,'if_log',1);
opts_read=filldefault(opts_read,'if_warn',1);
opts_read=filldefault(opts_read,'nfiles_max',100);
opts_read=filldefault(opts_read,'input_type',0);
opts_read=filldefault(opts_read,'data_fullnames',cell(0));
opts_read=filldefault(opts_read,'setup_fullnames',cell(0));
opts_read=filldefault(opts_read,'if_auto',0);
opts_read=filldefault(opts_read,'if_data_only',0);
opts_read=filldefault(opts_read,'ui_filter','*_coords*');
opts_read=filldefault(opts_read,'if_symaug',0);
opts_read=filldefault(opts_read,'sym_apply','full');
opts_read=filldefault(opts_read,'if_symaug_log',0);
%
input_types=opts_read.input_types;
%
if opts_read.if_uselocal %if not, then parameters in opts_qpred should be supplied by rs_get_coordsets
    opts_local=psg_localopts;
    opts_qpred=filldefault(opts_qpred,'qform_datafile_def',opts_local.model_filename_def); %model file name
    opts_qpred=filldefault(opts_qpred,'qform_modeltype',opts_local.modeltype_def);  %model type
end
syms_list=struct;
%
if opts_read.if_data_only==1 | length(opts_read.input_types)==1 %if only data can be read, override requests for any other input type
    opts_read.input_type=1;
end
if_ok=0;
if_symaug=opts_read.if_symaug;
sym_apply=opts_read.sym_apply;
if (if_symaug==-1)
    if_symaug=getinp('1 to augment primary input files by symmetry','d',[0 1]);
    if (if_symaug==1)
        sym_apply_choices=psg_btcsyms;
        disp('available symmetries');
        disp(sym_apply_choices);
        sym_apply=getinp('symmetry type','s',[],'full');
        syms_list.sym_apply=sym_apply;
    end
end
while (if_ok==0)
    nsets_primary=nsets;
    if isempty(nsets) | nsets==0
        if if_symaug==0
            nsets_primary=getinp('number of datasets (negative or zero: use a dialog box for multiple datasets)','d',opts_read.nfiles_max*[-1 1]);
            nsets=nsets_primary;
        else
            nsets_primary=getinp('number of primary datasets (negative or zero: use a dialog box for multiple datasets)','d',opts_read.nfiles_max*[-1 1]);
            nsets=0;
        end
    end
    nsets_primary_pos=abs(nsets_primary);
    if_dialog=double(nsets_primary<=0);
    if (if_dialog)
        if_dialog_ok=0;
        while (if_dialog_ok==0)
            if (nsets==0)
                ui_prompt='Select one or more coordinate files';
            else
                ui_prompt=sprintf('Select %1.0f coordinate files',nsets_primary_pos);
            end
            [filenames_short,pathname,filter_index]=uigetfile(opts_read.ui_filter,ui_prompt,'Multiselect','on');
            if filter_index==0
                if_manual=getinp('1 to return to selection from console','d',[0 1]);
            else
                if_manual=0;
            end
            if if_manual
                if_dialog_ok=1;
                if_dialog=0;
            else
                if ~iscell(filenames_short) filenames_short={filenames_short}; end
                nfiles_sel=length(filenames_short); %works unless filenames_short is empty
                if (filter_index==0)
                    nfiles_sel=0;
                end
                if (nsets_primary_pos>0) %if a specific number of files requested, then this must match number of files chosen
                    if_dialog_ok=double(nfiles_sel==nsets_primary_pos);
                else %if nsets_primary_pos=0, then the number of files is determined by the number selected, but must be >0
                    if_dialog_ok=double(nfiles_sel>0);
                    if (if_dialog_ok)
                        nsets_primary_pos=nfiles_sel;
                    end
                end
            end
        end %if_dialog_ok
    end %if_dialog
    %
    sets=cell(1,0);
    ds=cell(1,0);
    sas=cell(1,0);
    rayss=cell(1,0);
    opts_read_used=cell(1,0);
    opts_rays_used=cell(1,0);
    opts_qform_used=cell(1,0);
    d_qform=cell(1,0);
    d_mds=cell(1,0);
    data_fullname=[];
    setup_fullname=[];
    %
    %read the datasets and/or the qform models
    %
    iset=0;
    for iset_primary=1:nsets_primary_pos
        if opts_read.if_log==1 | opts_read.if_auto==0
            disp(' ');
            if (if_symaug==0)
                disp(sprintf(' entering set %2.0f of %2.0f:',iset_primary,nsets_primary_pos));
            else
                disp(sprintf(' entering primary set %2.0f of %2.0f:',iset_primary,nsets_primary_pos));
            end
        end
        input_type_use=opts_read.input_type(mod(iset,length(opts_read.input_type))+1); %-1 removed from iset 15Sep25
        if input_type_use==0
            input_type_use=getinp('1 for experimental data, 2 for qform model','d',[1 2]);
        else
            if opts_read.if_log
                disp(sprintf('primary dataset %1.0f is %s',iset_primary,input_types{input_type_use}));
            end
        end
        if (if_dialog)
            data_fullname=cat(2,pathname,filenames_short{iset_primary});
        else
            if nsets_primary_pos<=length(opts_read.data_fullnames)
                data_fullname=opts_read.data_fullnames{iset_primary};
            end
        end
        if nsets_primary_pos<=length(opts_read.setup_fullnames)
            setup_fullname=opts_read.setup_fullnames{iset_primary};
        end
        switch input_type_use
            case 1 %data, will set sets{iset}='data'
                [dsp,sasp,orup,pipeline]=psg_read_coorddata(data_fullname,setup_fullname,opts_read);
                if if_symaug==0
                    naug=1; 
                else
                     [sa_sym,syms_applied]=psg_btcmeta_symapply(sasp,sym_apply,setfield(struct(),'if_log',opts_read.if_symaug_log));
                     naug=length(sa_sym);
                end
                for is=1:naug
                    iset=iset+1;
                    ds{iset}=dsp;
                    if if_symaug==0
                        sas{iset}=sasp;
                        sym_string='';
                    else
                        syms_list.primary(iset)=iset_primary;
                        syms_list.aug(iset)=is;
                        syms_list.syms_applied{iset}=syms_applied{is};
                        %
                        sas{iset}=sa_sym{is};
                        if opts_read.if_log
                            disp(sprintf('primary dataset %2.0f: symmetrization %2.0f becomes dataset %2.0f',iset_primary,is,iset));
                        end
                        sym_string=sprintf(' sym %1.0f of %1.0f (%s)',is,naug,sym_apply);
                    end
                    opts_read_used{iset}=orup;
                    %
                    %determine whether one of the strings in ray_minpts_default
                    %is present in setup file name, and if so, use this to
                    %determine the default for opts_rays
                    opts_rays_use=psg_findray_setopts(opts_read_used{iset}.setup_fullname,opts_rays);
                    %
                    [rayss{iset},opts_rays_used{iset}]=psg_findrays(sas{iset}.btc_specoords,setfield(opts_rays_use,'permute_raynums',opts_read_used{iset}.permute_raynums));
                    opts_read.setup_fullname_def=opts_read_used{iset}.setup_fullname;
                    %
                    sets{iset}=psg_make_setstruct('data',opts_read_used{iset}.dim_list,opts_read_used{iset}.data_fullname,sas{iset}.nstims,struct(),opts_read_used{iset});
                    %add symmetry tag
                    sets{iset}.label=cat(2,sets{iset}.label,sym_string);
                    sets{iset}.label_long=cat(2,sets{iset}.label_long,sym_string);
                    %
                    opts_qpred_used{iset}=struct();
                end
            case 2 %quadratic form model, will set sets{1}='qform'
                parsed=psg_coorddata_parsename(data_fullname,opts_read);
                need_setup_file=parsed.need_setup_file;%this will get stimulus coordinates from setup file
                if ~need_setup_file
                    coord_name='type_coords';
                    coord_name_rays='type_coords';
                    if_symaug=0; %no augmentation
                    naug=1;
                    [dsp,sasp,orup,pipeline]=psg_read_coorddata(data_fullname,setup_fullname,opts_read);
                    if_aug_spe=1; %use augmented coords, which will point to type_coords
                    if opts_read.if_auto==0
                        qform_source_type=getinp(' quadratic form choice: 1->use threshold data file, 2->use identity','d',[1 2],1);
                        if_qform=getinp('1 to use qform, 2 for mds model (should be equivalent)','d',[1 2],1);
                        if qform_source_type==1
                            qform_datafile=getinp('data file with path','s',[0 1],opts_qpred.qform_datafile_def);
                        end
                    else
                        qform_source_type=1;
                        if_qform=1;
                        qform_datafile=opts_qpred.qform_datafile_def;
                    end
                else
                    coord_name='btc_augcoords';
                    coord_name_rays='btc_specoords';
                    [dsp,sasp,orup]=psg_read_coorddata(data_fullname,setup_fullname,setfield(opts_read,'if_justsetup',1));
                    if if_symaug==0
                        naug=1;
                    else
                        [sa_sym,syms_applied]=psg_btcmeta_symapply(sasp,sym_apply,setfield(struct(),'if_log',opts_read.if_symaug_log));
                        naug=length(sa_sym);
                    end
                    if opts_read.if_auto==0
                        if_aug_spe=getinp('1 to use augmented coords, 2 to use spec coords','d',[1 2],1);
                        qform_source_type=getinp(' quadratic form choice: 1->use threshold data file, 2->use identity','d',[1 2],1);
                        if_qform=getinp('1 to use qform, 2 for mds model (should be equivalent)','d',[1 2],1);
                        if qform_source_type==1
                            qform_datafile=getinp('data file with path','s',[0 1],opts_qpred.qform_datafile_def);
                        end
                    else
                        if_aug_spe=1;
                        qform_source_type=1;
                        if_qform=1;
                        qform_datafile=opts_qpred.qform_datafile_def;
                    end
                end
                for is=1:naug
                    iset=iset+1; %iset will always = iset_primary
%                    sets{iset}.type='qform';
                    if if_symaug==0
                        sas{iset}=sasp;
                        sym_string='';
                    else
                        syms_list.primary(iset)=iset_primary;
                        syms_list.aug(iset)=is;
                        syms_list.syms_applied{iset}=syms_applied{is};
                        %
                        sas{iset}=sa_sym{is};
                        if opts_read.if_log
                            disp(sprintf('primary dataset %2.0f: symmetrization %2.0f becomes dataset %2.0f',iset_primary,is,iset));
                        end
                        sym_string=sprintf(' sym %1.0f of %1.0f (%s)',is,naug,sym_apply);
                    end
                    nstim_dimensions=size(sas{iset}.(coord_name),2); %number of dimensions in stimulus coordinates
                    opts_read_used{iset}=orup;
                    opts_rays_use=psg_findray_setopts(opts_read_used{iset}.setup_fullname,opts_rays);
                    [rayss{iset},opts_rays_used{iset}]=psg_findrays(sas{iset}.(coord_name_rays),setfield(opts_rays_use,'permute_raynums',opts_read_used{iset}.permute_raynums));
                    %
                    switch if_aug_spe
                        case 1
                            btc_coords=sas{iset}.(coord_name); % btc_augcoords for btc
                            aug_spe_string='aug';
                        case 2
                            btc_coords=sas{iset}.(coord_name_rays); % btc_specoords for btc
                            btc_coords(isnan(btc_coords))=0;
                            aug_spe_string='spec';
                    end
                    %get quadratic form
                    switch qform_source_type
                        case 1
                            opts_qpred.qform_datafile_def=qform_datafile;
                            r_qpred=getfield(load(qform_datafile),'r');
                            % determine which model to use
                            qform_index_list=opts_qpred.qform_modeltype;
                            qform_index=qform_index_list(mod(iset-1,length(qform_index_list))+1);
                            if qform_index==0
                                qform_index=getinp(sprintf('index into quadratic form file for set %2.0f',iset),'d',[1 length(r_qpred)]);
                            end
                            %
                            q=r_qpred{qform_index}.results.qfit;
                            q_label=r_qpred{qform_index}.setup.label;
                            if opts_read.if_log
                                disp(sprintf(' model %2.0f (%s) loaded from %s',...
                                    qform_index,q_label,qform_datafile));
                            end
                            qform_source=qform_datafile;
                        case 2
                            q=eye(nstim_dimensions);
                            qform_source='[identity]';
                            q_label='identity';
                            qform_index=0;
                    end
                    %compute the model
                    [d_qform{iset},d_mds{iset},opts_qpred_used{iset}]=psg_qformpred(q,btc_coords,rayss{iset},opts_qpred);
                    switch if_qform
                        case  1
                            ds{iset}=d_qform{iset}; %use quadratic form model
                            qform_mds_string='qform';
                        case 2
                            ds{iset}=d_mds{iset};
                            qform_mds_string='mds';
                    end
                    if need_setup_file
                        label_long=cat(2,opts_read_used{iset}.setup_fullname,' c:',aug_spe_string,' q:',qform_source,' m:',qform_mds_string);
                    else
                        label_long=cat(2,'q:',qform_source,' m:',qform_mds_string);
                    end
                    sets{iset}=psg_make_setstruct('qform',1:length(d_qform{iset}),label_long,sas{iset}.nstims,struct(),opts_read);
                    sets{iset}.label=strrep(sets{iset}.label,'../','');
                    sets{iset}.label=strrep(sets{iset}.label,'stim/','');
                    sets{iset}.label=strrep(sets{iset}.label,'btc_allraysfixedb_','');
                    sets{iset}.label=strrep(sets{iset}.label,'100surrs_','');
                    %override subject ID fields with index
                    sets{iset}.subj_id=cat(2,q_label,sprintf(', ind: %1.0f',qform_index));
                    sets{iset}.subj_id_short=q_label;
                    %add symmetry tag
                    sets{iset}.label=cat(2,sets{iset}.label,sym_string);
                    sets{iset}.label_long=cat(2,sets{iset}.label_long,sym_string);
                end
        end  %data or model
        if (iset_primary==1)
            nstims=sas{1}.nstims;
            typenames=sas{1}.typenames;
        end
        for jset=(iset-naug+1):iset
            opts_read_used{jset}.input_type=input_type_use;
            opts_read_used{jset}.input_type_desc=input_types{input_type_use};
            %check consistency of number of stimuli and typenames
            if sets{jset}.nstims~=nstims
                disp(sprintf('warning: expecting %3.0f stimuli, dataset %1.0f (primary: %1.0f) has %3.0f stimuli',nstims,jset,iset_primary,sets{jset}.nstims));
            else
                typenames_mismatch=[];
                ordstring=cell(nstims,1);
                for istim=1:nstims
                    if ~strcmp(sas{jset}.typenames{istim},typenames{istim})
                        typenames_mismatch=[typenames_mismatch,istim];
                        foundslot=strmatch(sas{jset}.typenames{istim},typenames,'exact');
                        if ~isempty(foundslot)
                            ordstring{istim}=sprintf(', stim present in slot %3.0f',foundslot);
                        else
                            ordstring{istim}=', stim not present at all';
                        end
                    end
                end
                if ~isempty(typenames_mismatch) & (opts_read.if_warn==1)
                    disp(sprintf('warning: the following stimulus type names do not match in dataset %1.0f (primary: %1.0f):',jset,iset_primary))
                    for istimptr=1:length(typenames_mismatch)
                        istim=typenames_mismatch(istimptr);
                        disp(sprintf('   for stim %3.0f, expecting %20s found %20s %s',istim,typenames{istim},sas{jset}.typenames{istim},ordstring{istim}));
                    end
                end
            end %number of stimuli match?
        end
    end % isets_primary
    %summarize and check
    if opts_read.if_log==1 | opts_read.if_auto==0
        disp(' ');
        disp('datasets selected:');
        for iset=1:length(sets)
            disp(sprintf(' set %2.0f: dim range [%3.0f %3.0f] label: %s',iset,min(sets{iset}.dim_list),max(sets{iset}.dim_list),sets{iset}.label));
        end
    end
    if opts_read.if_auto==0
        if_ok=getinp('1 if ok','d',[0 1]);
    else
        if_ok=1;
    end
end % if_ok
return
