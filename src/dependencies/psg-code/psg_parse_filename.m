function [p,opts_used]=psg_parse_filename(filename,opts)
% [p,opts_used]=psg_parse_filename(filename) parses a file name to extract 
% paradigm type, paradigm name, and subject id
%
% filename: file name
% opts: options structure, typically opts_read
%
% p.paradigm_type: 'animals' or 'btc'
% p.paradigm_name: for animals: 'word','object','intermdiate_object','intermediate_texture','texture'
%                for btc: bgca3pt, bc6pt, ...
% p.subj_id: 2 or more uppercase chars
% p.file_type: 'coords' or 'choices'
% p.extra: expected extra characters
%
% opts_used: options used
%
% 24Jun23: add compatibility with btcsel paradigm type
% 23Aug23: add compatibility with bright paradigm type
% 30Sep25: allow for option input; determine animal pardigm by matching with domain_list. suport irgb and mater
% 27aPR26: add local paradigm_type_def
%
%  See also:  PSG_MAKE_SETSTRUCT.
%
underscore='_';
%
if nargin<=1
    opts=struct;
end
opts=filldefault(opts,'if_uselocal',1); %rs package will typically set this to zero
%
if opts.if_uselocal
    opts_local=psg_localopts;
    opts.domain_list_def=opts_local.domain_list_def;
    opts.type_class_def=opts_local.type_class_def; % default type class
    opts.paradigm_type_def='animals';
end
opts_used=opts;
%
%remove path if present
filename=strrep(filename,'/',filesep);
filename=strrep(filename,'\',filesep);
filename=cat(2,filesep,filename);
filename=filename(max(find(filename==filesep))+1:end);
%remove .mat if present
filename=cat(2,filename,'.mat');
filename=strrep(filename,'.mat.mat','.mat');
filename=strrep(filename,'.mat','');
%
underscores=find(filename==underscore);
paradigm_type='unrecognized';
paradigm_name=[];
subj_id=[];
file_type=[];
extra=[];
subj_id_short=[];
if ~isempty(strfind(filename,'pt_')) & length(underscores)>=3 %filename  bcpm3pt_coords_SAW_sess01_10 or 'bc6pt_choices_MC_sess01_10_sel_cp_rand' or 
    paradigm_type='btc';
    paradigm_name=filename(1:underscores(1)-1);
    idx=strfind(filename,'_sel');
    if ~isempty(idx)
        paradigm_type='btcsel';
        paradigm_name=cat(2,paradigm_name,filename(idx+4:end));
    end
    subj_id=filename(underscores(2)+1:underscores(3)-1);
    dash=find(subj_id=='-');
    if ~isempty(dash)
        subj_id_short=subj_id(1:dash-1);
    end
    extra=filename(underscores(3)+1:end);
elseif ~isempty(strfind(filename,'bright_')) %filename  bright_c02s08_choices_GA_oddoneout_sel_cXs
    paradigm_type='bright';
    paradigm_name=filename(underscores(1)+1:underscores(2)-1);
    idx=strfind(filename,'_sel');
    if ~isempty(idx)
        paradigm_name=cat(2,paradigm_name,filename(idx+4:end));
    end
    subj_id=filename(underscores(3)+1:underscores(4)-1);
    extra=filename(underscores(4)+1:underscores(5)-1);
elseif ~isempty(strfind(filename,'faces_')) %%file name like faces_mpi_en2_fc_choices_MC_sess01_10_sel__
    paradigm_type='faces';
    %paradigm name may have variable number of underscores, but ends with choices or coords
    filename_mod=strrep(strrep(filename,'choices','*'),'coords','*'); %now like faces_mpi_en2_fc_*_MC_sess01_10_sel__
    underscores_mod=find(filename_mod==underscore);
    paradigm_name=filename(underscores_mod(1)+1:(find(filename_mod=='*')-2));
    filename_end=filename_mod(find(filename_mod=='*')+2:end); %like MC_sess01_10_sel__
    underscores_end=find(filename_end==underscore);
    subj_id=filename_end(1:underscores_end(1)-1);
    extra=filename_end(underscores_end(1)+1:end);
    sel_start=min(strfind(filename_end,'sel_'));
    if ~isempty(sel_start)
        paradigm_name=cat(2,paradigm_name,'-',filename_end(sel_start+4:end));
    end
elseif ~isempty(strfind(filename,'mater')) % file name like mater-orig-bw_coords_ZK_sess01_06.mat
    paradigm_type='mater';
    paradigm_name=filename(1:underscores(1)-1);
    subj_id=filename(underscores(2)+1:underscores(3)-1);
    extra=filename(underscores(3)+1:end);
elseif ~isempty(strfind(filename,'irgb')) % file name like irgb_test24_coords_XX_sess01_10.mat'
    paradigm_type='irgb';
    paradigm_name=filename(1:underscores(2)-1);
    subj_id=filename(underscores(3)+1:underscores(4)-1);
    extra=filename(underscores(4)+1:end);
elseif length(underscores)>=1 %see if one of the domain names is present
%    paradigm_name=filename(underscores(1)+1:underscores(end)-1);
%    subj_id=filename(1:underscores(1)-1);
    idl_match=0;
    for idl=1:length(opts.domain_list_def)
        if min(strfind(filename,opts.domain_list_def{idl})==1);
            idl_match=idl;
        end
    end
    if idl_match>0
        paradigm_type=opts.paradigm_type_def; % was 'animals'; %filename like texture_coords_S7 (previously, ZK_intermediate_object_choices)
        paradigm_name=opts.domain_list_def{idl_match};
        paradigm_name=filename(1:underscores(end-1)-1);
        subj_id=filename(underscores(end)+1:end);
    end
end
if ~isempty(strfind(filename,'coords'))
    file_type='coords';
end
if ~isempty(strfind(filename,'choices'))
    file_type='choices';
end
if isempty(subj_id_short)
    subj_id_short=subj_id;
end
p=struct;
p.paradigm_type=paradigm_type;
p.paradigm_name=paradigm_name;
p.subj_id=subj_id;
p.subj_id_short=subj_id_short;
p.file_type=file_type;
p.extra=extra;
return
