function parsed=psg_coorddata_parsename(data_fullname,opts)
% parsed=psg_coordata_parsename(data_fullname,opts)
% parses the name of a coordinate data file to determine type class, setup files, etc
%
% data_fullname: full name, including path, of a coordinate data file
% opts: option structure, typically opts_read, from psg_read_coorddata
%
% parsed.type_class: designation for the stimulus domain 'btc', 'faces_mpi', 'domain', etc
% parsed.setup_filename_def: suggested setup file to go with data_fullname
% parsed.need_setup_file: 1 if a setup file is needed, otherwise 0
% parsed.data_shortname: short name of data file
% parsed.domain_sigma: std dev in error for decision model in domain
% parsed.domain_match: index into matching domain name in 'domain' experiment
% parsed.warn_string: warning string, if any
%
% 02Oct25: strfind -> psg_strfind
% 27Apr26: do not look for domain_sigma subject match if domain_sigma is empty
%
%  See also:  PSG_READ_COORDDATA, PSG_STRFIND.
%
if isfield(opts,'domain_list_def')
    opts=filldefault(opts,'domain_list',opts.domain_list_def);
end
opts=filldefault(opts,'if_uselocal',1);
if opts.if_uselocal
    opts=filldefault(opts,'type_class_def','btc');
    opts=filldefault(opts,'need_setup_file',1);
    opts=filldefault(opts,'setup_fullname_def','/psg_data/bgca3pt9.mat');
    opts=filldefault(opts,'coord_string','_coords');
    opts=filldefault(opts,'domain_list',{'texture','intermediate_texture','intermediate_object','image','word'}); %domain names for animals experiment
    opts=filldefault(opts,'type_class_aux',[]);
    opts=filldefault(opts,'setup_suffix','9');
end
%
parsed=struct;
%assumed values
parsed.type_class=opts.type_class_def; %assumed type class
parsed.need_setup_file=opts.need_setup_file; %assume setup file is needed
parsed.domain_sigma=1; %defaut value
parsed.data_shortname=data_fullname;
parsed.setup_fullname_def=opts.setup_fullname_def;
parsed.domain_match=0;
parsed.warn_string=[];
%
underscore_sep=min(psg_strfind(data_fullname,opts.coord_string));
if ~isempty(underscore_sep)
    for id=1:length(opts.domain_list)
        if contains(data_fullname,cat(2,opts.domain_list{id},'_coords'))
            parsed.domain_match=id;
        end
    end
    %
    seps=max(union(psg_strfind(data_fullname,'/'),psg_strfind(data_fullname,'\')));
    if ~isempty(seps)
        parsed.data_shortname=parsed.data_shortname(seps+1:end);
    end
    if ismember(1,psg_strfind(parsed.data_shortname,'faces'))
        parsed.setup_fullname_def=cat(2,data_fullname(1:underscore_sep-1),'.mat');
        parsed.type_class='faces_mpi';
    elseif ismember(1,psg_strfind(parsed.data_shortname,'irgb'))
        parsed.setup_fullname_def=cat(2,data_fullname(1:underscore_sep-1),'.mat');
        parsed.type_class='irgb';
    elseif ismember(1,psg_strfind(parsed.data_shortname,'mater'))
        parsed.setup_fullname_def=cat(2,data_fullname(1:underscore_sep-1),'.mat');
        parsed.type_class='mater';
    elseif ismember(1,psg_strfind(parsed.data_shortname,opts.type_class_aux))
        parsed.setup_fullname_def=data_fullname;
        parsed.type_class=opts.type_class_aux;
        parsed.need_setup_file=0; %no setup file needed
    elseif parsed.domain_match>0
        parsed.setup_fullname_def='';
        parsed.type_class='domain';
        parsed.need_setup_file=0; %no setup file needed
        %find subject ID
        subjid_string=data_fullname(underscore_sep+length(opts.coord_string)+1:end); %should be something like EVF.mat
        subjid_string=strrep(subjid_string,'.mat',''); %remove extension if present
        parsed.domain_sigma=1;
        if ~isempty(fieldnames(opts.domain_sigma))
            if isfield(opts.domain_sigma,subjid_string)
                parsed.domain_sigma=opts.domain_sigma.(subjid_string);
            else
                parsed.warn_string=strvcat(parsed.warn_string,sprintf('subject ID %2.0s from file name %s not recognized',data_fullname,subjid_string));
            end
        end
    else
        parsed.setup_fullname_def=cat(2,data_fullname(1:underscore_sep-1),opts.setup_suffix,'.mat');
    end
end
return
end
