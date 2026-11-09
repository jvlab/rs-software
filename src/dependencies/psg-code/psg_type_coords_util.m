function [type_coords,coord_field,coord_fields_used]=psg_type_coords_util(sa,coord_fields)
% [type_coords,type_coord_field,coord_fields_used]=psg_type_coords_util(sa,coord_fields)
% extracts the stimulus coordinates from the metadata setructure sas,
% searching several candidate field names
%
% sa: metadata structure with 'type_coords','btc_specoords',etc.
% coord_fields: a list of field names to be searched in priority order.  If empty or unspecified, 
%   taken from getfield(psg_defopts(),'coord_fields')
%
% type_coords: values found (dim 1: number of stimuli; coords for each stimulus in rows
% coord_field: the name of the field that has the coordinates
%    coord_field will be empty if no field found
%    type_coords will be empty if no field found, or, if sa.(coord_field) is empty
% coord_fields_used: coord_fields used for searching
%
%    See also: PSG_DEFOPTS, PSG_ALIGN_COORDSETS, RS_FINDRAYS.
%
if (nargin<=1)
    coord_fields=[];
end
if isempty(coord_fields)
    coord_fields=getfield(psg_defopts(),'coord_fields');
end
coord_fields_used=coord_fields;
type_coords=[];
coord_field=[];
ifn=0;
while (ifn<length(coord_fields) & isempty(coord_field))
    ifn=ifn+1;
    if isfield(sa,coord_fields{ifn})
        coord_field=coord_fields{ifn};
        type_coords=sa.(coord_field);
    end
end
return
