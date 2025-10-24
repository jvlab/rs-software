function aux_out=rs_write_coorddata(fullname,data_in,aux)
% aux_out=rs_write_coorddata(fullname,data_in,aux) writes a coordinate structure
%
%****will need to handle embedded setup
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
%     if_gui: 1 to use graphical interface to get files if file names are not supplied (default), 0 to use console
%     if_log: 1 (default) to log (0 still shows warnings)
%     data_fullname_def: default file name to write, used as a prompt if fullname is not provided
%
% aux_out:
%  opts_write: options used
%  warnings: warnings
%  warn_bad: count of warnings that prevent further processing
%  sout: structure written
%
% See also:  RS_AUX_CUSTOMIZE, RS_WRITE_COORDDATA.
%
if (nargin<=2)
    aux=struct;
end
%
aux=filldefault(aux,'opts_write',struct);
aux.opts_write=filldefault(aux.opts_write,'set_no',1);
aux=rs_aux_customize(aux,'rs_write_coorddata');
%
aux_out=aux;
aux_out.warnings=[];
aux_out.warn_bad=0;
%
s_written=struct;

%%%process

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



aux_out.fullname=fullname;
aux_out.s_written=s_written;

aux_out.opts_write=aux.opts_write;
return



% %    PSG_ALIGN_KNIT_DEMO, PSG_COORD_PIPE_PROC.
% %
% if nargin<=3
%     opts=struct;
% end
% opts_local=psg_localopts;
% opts=filldefault(opts,'data_fullname_def',opts_local.coord_data_fullname_write_def);
% opts=filldefault(opts,'if_log',1);
% %
% if isempty(data_fullname)
%     data_fullname=getinp('full path and file name of data file','s',[],opts.data_fullname_def);
% end
% opts.data_fullname=data_fullname;
% opts_used=opts;
% %
% if isfield(sout,'stim_labels')
%     nstims=size(sout.stim_labels,1);
% elseif isfield(sout,'nstims')
%     nstims=sout.nstims;
% elseif isfield(sout,'typenames')
%     nstims=sout.typenames;
% end
% dim_string=[];
% %
% for idimptr=1:length(ds)
%     idim=size(ds{idimptr},2);
%     if (idim>0) %added 14Oct24
%         dim_string=cat(2,dim_string,sprintf('%1.0f ',idim));
%         if size(ds{idimptr},1)~=nstims
%             warning(sprintf('for dim %2.0f (pointer=%2.0f), number of stimuli found is %2.0f, expected: %2.0f',idim,idimptr,size(ds{idimptr},1),nstims));
%         end   
%         dname=cat(2,'dim',sprintf('%1.0f',idim));
%         sout.(dname)=ds{idim};
%     else
%         warning(sprintf('entry for dimension pointer %2.0f has no data',idimptr));
%     end
% end
% dim_string=deblank(dim_string);
% save(data_fullname,'-struct','sout');
% if opts.if_log
%     disp(sprintf('%s written with %2.0f stimuli and dimensions %s.',data_fullname,nstims,dim_string));
% end
% return
% 
