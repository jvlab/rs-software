function aux_out=rs_write_coorddata(fullname,data_in,aux)
% aux_out=rs_write_coorddata(fullname,data_in,aux) writes a single record in a `dataset structure` to a file
% 
% Args:
%   fullname (char or singleton cell array): file name with path, if empty, it will be requested interactively.
%     The file name should contain the string '_coords'
%   
%   data_in (struct): `dataset structure` containing the record to be written
% 
%     - ds (cell array): `coordinate structure`, ds{k}{idim} is an array of [nstims idim] of coordinates for the kth record
%     - sas (cell array): `stimulus metadata structure`, sas{k} is the stimulus metadata for the kth record
%     - sets (cell array): `set metadata structure`, sets{k} is the response metadata for the kth record
%
%   aux (struct): auxiliary options,  with fields
%
%     - opts_write (struct): , with fields
%
%          - set_no (int): record number to write; default is 1
%          - if_embed (int): 1 to embed the `setup metadata` in the output file, 0 to omit; see note below re setup metadata.
%          - ui_prompt (char): User interface prompt, default ia ,'Select a coordinate file to write'
%          - if_gui (int): 1 to use graphical interface to get files if file names are not supplied; 0 to use text prompt; default is 0
%          - if_log (int): 1 to log progress, 0 to omit; default is 1
%          - data_fullname_def (char): default file name to write, used as a prompt if if_gui=0 if fullname is not provided; default is
%          './samples/bgca3pt_coords_QFM_sess01_01.mat'; default can be changed by  editing the line containing
%          generic.opts_write.coord_data_fullname_write_def in 'rs_aux_defaults_define' [??how to hyperlink], running it 
%          once, and saving the workspace as rs_aux_defaults.mat.
%          - if_uselocal (int): should be set to 0 (default); 1 (intended for maintenance only) overrides options set by `rs_aux_defaults_define` [?how to hyperlink?] by defaults in `psg_localopts.m` [?how to hyperlink?[
%
%   aux_out (struct): auxiliary outputs and parameter values used, with fields
%
%     - warnings (char): warnings
%     - warn_bad (int): number of warnings that prevent further processing
%     - opts_write (struct): aux, aux.opts_geof, with defaults filled in
%     - fullname (char): file name written
%     - s_written (struct): structure written
%
% Note re `setup metadata`:
%
%    - The `setup metadata` is required for `binary texture domain` datasets, or, if configured on installation.
%    - If `setup metadata` is required, it is read along with the coordinate data by `rs_read_coorddata` [how to hyperlink?]or
%    `rs_get_coordsets` [how to hyperlink?], and kept in data_in{k}.sas; it is also updated by `rs_align_coordsets`[how to hyperlink?] and `rs_knit_coordsets`[how to hyperlink?]
%    - if_embed=1 embeds the metadata in the written file, so that the setup file no longer needs to be read. 
% 
% See also:  RS_AUX_CUSTOMIZE, RS_WRITE_COORDDATA.
%
if (nargin<=2)
    aux=struct;
end
%
aux=filldefault(aux,'opts_write',struct);
aux.opts_write=filldefault(aux.opts_write,'set_no',1);
aux.opts_write=filldefault(aux.opts_write,'if_embed',1);
aux.opts_write=filldefault(aux.opts_write,'ui_prompt','Select a coordinate file to write');
%
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
            [filename_short,pathname]=uiputfile(ui_filter,aux.opts_write.ui_prompt);
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
