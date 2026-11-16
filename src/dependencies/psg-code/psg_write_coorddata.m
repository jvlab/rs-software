function [opts_used,s_written]=psg_write_coorddata(data_fullname,ds,sout,opts)
% [opts_used,s_written]=psg_write_coorddata(data_fullname,ds,sout,opts) writes a coordinate structure
%
% data_fullname: data file name including path; if empty, requested interactively
% ds: cell array, ds{k} is the scaling solution for the kth dimension
%   (typically, ds{k} has size [nstims k])
% sout: structure with metadata
%   sout.stim_labels: strvcat of the stimulus labels, size(sout.stim_labels)=nstims
%   sout.pipeline: optional
%   sout.setup: optional, if present, this is the setup metadata which replaces
%     a separate setup metadata file for the btc datasets (e.g., bgca3pt9.mat)
% opts:
%   opts.data_fullname_def: default file name to write
%   opts.if_log: 1 to log
%
% opts_used: options used
%   opts_used.warnings: list of warnings
% s_written: structure written
%
% 28Nov23: multiple ways to determine number of stimuli
% 22Feb24: localization params now from psg_localopts
% 14Oct24: handle a coordinate set with no data
% 25Oct25: added s_written, opts_used.warnings
% 03Nov25: if_uselocal, for compatibility with rs
% 04Nov25: stim_labels is a character array
%
% See also:  PSG_READ_COORDDATA, PSG_QFORM2COORD_PROC, PSG_LOCALOPTS, PSG_CONSENSUS_WRITE_UTIL,
%    PSG_ALIGN_KNIT_DEMO, PSG_COORD_PIPE_PROC.
%
if nargin<=3
    opts=struct;
end
opts=filldefault(opts,'if_uselocal',1); %rs package will typically set this to zero
if opts.if_uselocal %if not, then parameters in opts_qpred should be supplied by rs_get_coordsets
    opts_local=psg_localopts;
end
if opts.if_uselocal
    opts=filldefault(opts,'data_fullname_def',opts_local.coord_data_fullname_write_def);
else
    opts=filldefault(opts,'data_fullname_def',opts.coord_data_fullname_write_def);
end
opts=filldefault(opts,'if_log',1);
%
if isempty(data_fullname)
    data_fullname=getinp('full path and file name of data file','s',[],opts.data_fullname_def);
end
opts.data_fullname=data_fullname;
opts_used=opts;
opts_used.warnings=[];
s_written=struct;
%
if isfield(sout,'stim_labels')
    if iscell(sout.stim_labels)
        sout.stim_labels=strvcat(sout.stim_labels);
    end
    nstims=size(sout.stim_labels,1);
elseif isfield(sout,'nstims')
    nstims=sout.nstims;
elseif isfield(sout,'typenames')
    nstims=sout.typenames;
end
dim_string=[];
%
for idimptr=1:length(ds)
    idim=size(ds{idimptr},2);
    if (idim>0) %added 14Oct24
        dim_string=cat(2,dim_string,sprintf('%1.0f ',idim));
        if size(ds{idimptr},1)~=nstims
            wmsg=sprintf('for dim %2.0f (pointer=%2.0f), number of stimuli found is %2.0f, expected: %2.0f',idim,idimptr,size(ds{idimptr},1),nstims);
            warning(wmsg);
            opts_used.warnings=strvcat(opts_used.warnings,wmsg);
        end   
        dname=cat(2,'dim',sprintf('%1.0f',idim));
        sout.(dname)=ds{idim};
    else
        wmsg=sprintf('entry for dimension pointer %2.0f has no data',idimptr);
        warning(wmsg);
        opts_used.warnings=strvcat(opts_used.warnings,wmsg);
    end
end
dim_string=deblank(dim_string);
save(data_fullname,'-struct','sout');
s_written=sout;
if opts.if_log
    disp(sprintf('%s written with %2.0f stimuli and dimensions %s.',data_fullname,nstims,dim_string));
end
return

