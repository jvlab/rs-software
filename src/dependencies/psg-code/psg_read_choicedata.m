function [d,sa,opts_used]=psg_read_choicedata(data_fullname,setup_fullname,opts)
% [d,sa,opts_used]=psg_read_choicedata(data_fullname,setup_fullname,opts) reads
% choice data (typically from a multidimensional-scaling experiment), from mat-files transferred from Python.
%
% If the metadata file is read, then sa.typenames contains the stimulus names and the stimulus tokens are renumbered to match.
%
% If the metadata file is not read (opts.nometa=1), then sa.typenames is taken from stim_list 
% in the data file, stimulus tokens are not renumbered.
%
% By default, the sign of the comparison is converted to count the number of times that the first pairing is judged more similar than the second pairing (see opts.sign_check_mode)
%
% data_fullname: full path and file name of data file, contains fields such as
%  dim1, dim2, ...; requested if not supplied or empty
% setup_fullname: full path and file name of a setup file, typically written by
%  psg_spokes_setup, with field s, and subfields s.nstims, s.specs, s.spec_labels, etc;  requested if not supplied
% opts.if_log: 1 to log, defaults to 0, can be omitted
% opts.if_justsetup: 1 to only read setup, defaults to 0
% opts.data_fullname_def: default data file
% opts.setup_fullname_def: default setup file
% opts.permutes: suggested ray permutations, e.g., permutes.bgca=[2 1 3 4]
% opts.permutes_ok: defaults to 1, to accept suggested ray permutations
% opts.sign_check_mode: (see psg_read_choicedata_notes.docx)
%    0: checks the sign and uses it (default), if not present, asks
%    -1: checks the sign but overrides, assumes col 4 counts d(ref,s1)<d(ref,s2)
%    +1: checks the sign but overrides, assumes col 4 counts d(ref,s1)>d(ref,s2)
% opts.nometa: defaults to 0, 1->does not try to read metadata, sa returned as [];
%
% d: if 5 cols: has size [ntriads 5],  columns are [ref s1 s2 choices(d(ref,s1)<d(ref,s2)) total trials]
% d: if 6 cols: has size [ntetrads 6], columns are [s1  s2 s3  s4 choices(d(s1,s2)<d(s3, s4)) total trials]        '
% sa: selected fields of s, and also
%    btc_augcoords, augmented coords, of size [s.nstims nbtc] 
%    btc_specoords, specificed coords, of size [s.nstims nbtc]
% opts_used: options used
%    opts_used.dim_list: list of dimensions available
%    opts_used.data_fullname: data file full name used
%    opts_used.setup_fullname: setup file full name used
%    opts_used.sign_check_used: value of sign check used
% stim_list: stimulus list, if present in choice file
%
% 04Apr23: add opts.permutes_ok
% 03Jul23: modifications for compatibility with faces_mpi; add type_class
% 31Jul23: bug fix: check the sign (opts.sign_check_mode) of the comparison in responses_colnames
% 31Jul23: add opts.nometa
% 10Aug23: read sa.typenames from stim_list in data file if opts.nometa=1
% 22Feb24: localization params now from psg_localopts
% 18Jun25: add capability for tetradic comparisons
% 02Oct25: strfind -> psg_strfind
% 17Aug26: changes for compatibility with rs: logging, add choice_type to opts_used
%
% See also: PSG_DEFOPTS, PSG_READ_COORDDATA, PSG_UMI_TRIPLIKE_DEMO, PSG_TENTLIKE_DEMO, PSG_CHOICEDATA_MAKEEEVEN,
%    PSG_SELECT_CHOICEDATA, PSG_LOCALOPTS, PSG_STRFIND.
%
opts_local=psg_localopts;
xfr_fields={'nstims','nchecks','nsubsamp','specs','spec_labels','opts_psg','typenames','btc_dict','if_frozen_psg'};
face_prefix_list={'fc_','gy_'}; %prefixes on stimulus labels to be removed to match typenames (fc=full color, gy=gray)
if (nargin<3)
    opts=struct;
end
if (nargin<1)
    data_fullname=[];
end
if (nargin<2)
    setup_fullname=[];
end
opts=filldefault(opts,'if_log',0);
opts=filldefault(opts,'if_justsetup',0);
opts=filldefault(opts,'data_fullname_def',opts_local.choice_data_fullname_def);
opts=filldefault(opts,'setup_fullname_def',opts_local.setup_fullname_def);
opts=filldefault(opts,'permutes_ok',1);
opts=filldefault(opts,'sign_check_mode',0);
opts=filldefault(opts,'nometa',0);
%
%defaults to change plotting order
permutes=struct();
permutes.bgca=[2 1 3 4]; % permute ray numbers to the order gbca
% permutes.bdce=[1 3 2 4]; % permute ray numbers to the order bcde
opts=filldefault(opts,'permutes',permutes);
opts=filldefault(opts,'setup_suffix',opts_local.setup_setup_suffix);
opts_used=opts;
type_class=opts_local.type_class_def; %assumed type class
%
if ~opts.if_justsetup
    if isempty(data_fullname)
        data_fullname=getinp('full path and file name of data file','s',[],opts.data_fullname_def);
    end
    underscore_sep=min(psg_strfind(data_fullname,'_choices'));
    if ~isempty(underscore_sep)
        %
        if ~isempty(psg_strfind(data_fullname,'faces_mpi'))
            opts.setup_fullname_def=cat(2,data_fullname(1:underscore_sep-1),'.mat');
            type_class='faces_mpi';
        else
            opts.setup_fullname_def=cat(2,data_fullname(1:underscore_sep-1),opts.setup_suffix,'.mat');
        end
    end
else
    data_fullname=[];
end
if isempty(setup_fullname) & opts.nometa==0
    setup_fullname=getinp('full path and file name of psg setup file','s',[],opts.setup_fullname_def);
end
stim_list=[];
if ~opts.if_justsetup
    d_read=load(data_fullname);
    ncols=size(d_read.responses,2);
    switch ncols
        case 5
            choice_type='triadic';
        case 6
            choice_type='tetradic';
        otherwise
            if opts.if_log
                warning('number of columns should be 5 or 6');
            end
            choice_type='unrecognized';
    end
    opts.choice_type=choice_type;
    d_fields=fieldnames(d_read);
    if (opts.if_log)
        disp(sprintf('%3.0f different stimulus types found in  data file %s; choice type is %s',length(d_read.stim_list),data_fullname,choice_type));
    end
else
    d=struct;
end
% check sign?
sign_check=0; %0 if not present, 1 if >, -1 if <
if ~opts.if_justsetup
    if isfield(d_read,'responses_colnames')
        if_greater=sum(double(d_read.responses_colnames(:)=='>'));
        if_less=sum(double(d_read.responses_colnames(:)=='<'));
        if (if_greater>0) & (if_less==0) 
            sign_check=1;
        end
        if (if_greater==0) & (if_less>0) 
            sign_check=-1;
        end
    end
    opts.sign_check_found=sign_check;
    if opts.if_log
        switch sign_check
            case 0
                disp('responses_colnames sign found is ambiguous');
            case 1
                disp('responses_colnames sign found is >');
            case -1
                disp('responses_colnames sign found is <');
        end
    end
    if opts.sign_check_mode~=0
        sign_check=opts.sign_check_mode;
    end
    while (sign_check==0)
        sign_check=getinp(sprintf('sign for comparison in column %1.0f: -1 for <, +1 for >',ncols-1),'d',[-1 1]);
    end
    switch sign_check
        case 1
            if opts.if_log
                disp(sprintf('responses_colnames sign  used is >, col %1.0f converted to nearest',ncols-1));
            end
            d_read.responses(:,ncols-1)=d_read.responses(:,ncols)-d_read.responses(:,ncols-1); %convert number judged more dis-similar to number judged more similar
        case -1
            if opts.if_log
                disp('responses_colnames sign  used is <, no conversion');
            end
    end
end
opts.sign_check_used=sign_check;        
% permute the ray order?
opts.permute_raynums=[];
if isstruct(opts.permutes)
    perm_list=fieldnames(opts.permutes);
    for iperm=1:length(perm_list)
        if psg_strfind(setup_fullname,perm_list{iperm})
            if opts.if_log
                disp(sprintf('suggested ray permutation for %s:',perm_list{iperm}))
                disp(opts.permutes.(perm_list{iperm}));
            end
            if ~opts.permutes_ok
                if getinp('1 if ok','d',[0 1],1)
                    opts.permute_raynums=permutes.(perm_list{iperm});
                end
            else
                opts.permute_raynums=permutes.(perm_list{iperm});
            end
        end
    end
end
%
opts.data_fullname=data_fullname;
opts.setup_fullname=setup_fullname;
opts_used=opts;
opts_used.type_class=type_class;
%
sa=struct;
if opts.nometa==0
    %
    %read the setup; retrieve specified and augmented coordinates
    %
    s=getfield(load(setup_fullname),'s');
    if (opts.if_log)
        disp(sprintf('%3.0f different stimulus types found in setup file %s',s.nstims,setup_fullname));
    end
    for ifield=1:length(xfr_fields)
        if isfield(s,xfr_fields{ifield})
            sa.(xfr_fields{ifield})=s.(xfr_fields{ifield});
        end
    end
    switch type_class
        case 'btc'
            nbtc=length(s.btc_dict.codel);
            sa.btc_augcoords=zeros(s.nstims,nbtc);
            sa.btc_specoords=zeros(s.nstims,nbtc);
            for istim=1:s.nstims
                sa.btc_augcoords(istim,:)=s.btc_methods{istim}.vec;
                sa.btc_specoords(istim,:)=btc_letcode2vec(s.specs{istim},s.btc_dict);
            end
        case 'faces_mpi' %since this is a choice file, coordinates not determined
            %
            %truncate suffixes on stim_labels if necessary
            %
            for ifp=1:length(face_prefix_list)
                d_read.stim_list=char(strrep(cellstr(d_read.stim_list),face_prefix_list{ifp},''));
            end
    end
    %parse and reorder the data in d_read to match the order in sa.typenames
    if ~opts.if_justsetup
        d_fields=fieldnames(d_read);
        stim_labels=d_read.stim_list;
        stim_sorted=zeros(s.nstims,1);
        stim_sorted_inv=zeros(s.nstims,1);
        for istim=1:s.nstims
            stim_match=strmatch(s.typenames{istim},stim_labels,'exact');
            if length(stim_match)~=1
                stim_match=0;
            else
                stim_sorted_inv(stim_match)=istim;
            end
            stim_sorted(istim)=stim_match;
        end
        stim_found=find(stim_sorted>0);
        if (opts.if_log) | any(stim_sorted==0)
            disp(sprintf('%3.0f of %3.0f labels found',sum(stim_sorted>0),s.nstims));
        end
        if any(stim_sorted==0)
           warning(sprintf('%3.0f stimulus labels not found',sum(stim_sorted==0)));
        end
        d=d_read.responses;
        d(:,[1:ncols-2])=stim_sorted_inv(d(:,[1:ncols-2])); %first three or four columns are stimulus tags (last two cols are not)
        if (opts.if_log)
            disp(sprintf('choice probabilities read, %3.0f stimulus types, %5.0f %ss, %5.0f trials (%3.0f to %3.0f per %s)',...
                s.nstims,size(d,1),choice_type,sum(d(:,ncols)),min(d(:,ncols)),max(d(:,ncols)),choice_type));
        end
    end
else
    d=d_read.responses;
    nstims=size(d_read.stim_list,1); %convert stim_list text strings to sa.typenames as cell array
    for k=1:nstims
        sa.typenames{k,1}=d_read.stim_list(k,:);
    end
end
return
end
