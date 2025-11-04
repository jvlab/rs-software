function aux_out=rs_write_coorddata(fullname,data_in,aux)
% aux_out=rs_write_coorddata(fullname,data_in,aux) writes a coordinate structure
%
% fullname: a single file name (with path); if empty, it will be requested interactively.  String or singleton cell array
%      File names should contain the string '_coords'.
% data_in.ds{iset}: coordinates.   data_in.ds{iset} has size [nstims k]
% data_in.sas{iset}: structure containing stimulus names in sa.typenames, as strvcat,
%   data_in.sas{iset}.typenames must be present
% data_in.sets{iset}: structure containing setup, typically set=sets{iset}; 
%   used for sets{iset}.pipeline, which may be omitted
%
% aux.opts_write:
%     set_no: which dataset to write, defaults to 1
%     if_embed: 1 to embed the setup metadata in the output file (so that future reads will not require a separate setup)
%         This is the default option, the metadata is taken to be
%         data_in.sas{set_no}, which is created by rs_[get|align|knit]_coordsets, rs_read_coorddata
%     if_gui: 1 to use graphical interface to get files if file names are not supplied (default), 0 to use console
%     if_uselocal: 0 to use options in rs_aux_defaults (default), 1 to use psg_localopts
%     if_log: 1 (default) to log (0 still shows warnings)
%     data_fullname_def: default file name to write, used as a prompt if fullname is not provided
%
% aux_out:
%  fullname: file name written
%  opts_write: options used
%  warnings: warnings
%  warn_bad: count of warnings that prevent further processing
%  s_written: structure written
%
% See also:  RS_AUX_CUSTOMIZE, RS_WRITE_COORDDATA.
%
if (nargin<=2)
    aux=struct;
end
%
aux=filldefault(aux,'opts_write',struct);
aux.opts_write=filldefault(aux.opts_write,'set_no',1);
aux.opts_write=filldefault(aux.opts_write,'if_embed',0);
aux=rs_aux_customize(aux,'rs_write_coorddata'); %sets if_log, if_gui, data_fullname_def, data_ui_filter
%
aux_out=aux;
aux_out.warnings=[];
aux_out.warn_bad=0;
%
s_written=struct;
%
if iscell(fullname)
    fullname=fullname{1};
end
%
if isempty(fullname)
    if aux.opts_write.if_gui
        if_manual=0;
        ui_prompt='Select a coordinate file to write';
        ui_filter={aux.opts_write.ui_filter,'coordinate file'};
        while (if_manual==0 & isempty(fullname))
            [filename_short,pathname]=uiputfile(ui_filter,ui_prompt);
            if  (isequal(filename_short,0) | isequal(pathname,0)) %use Matlab's suggested way to detect cancel
                if_manual=getinp('1 to return to selection from console','d',[0 1]);
            else
                fullname=cat(2,pathname,filename_short);
            end
        end
    end
end
iset=aux.opts_write.set_no;
sout=struct;
sout.stim_labels=data_in.sas{iset}.typenames;
if aux.opts_write.if_embed
    sout.setup=data_in.sas{iset}; %embedded setup
end
data_in.sets{iset}=filldefault(data_in.sets{iset},'pipeline',struct());
sout.pipeline=data_in.sets{iset}.pipeline;
[opts_write_used,s_written]=psg_write_coorddata(fullname,data_in.ds{iset},sout,aux.opts_write);
%
aux_out.fullname=opts_write_used.data_fullname;
aux_out.s_written=s_written;
aux_out.opts_write=opts_write_used;
aux_out.warnings=opts_write_used.warnings;
return
