function rupd=psg_geomodels_nestutil(results)
%  rupd=psg_geomodels_nestutil(results) is a utility to update versions of
%  a geometric modeling results structure to versions that separately
%  specify nesting by input and by output.
%
%   results: structure in which all nesting by dimension is assumed to be on the input dimension
%   rupd: updated version, in which field names specify that it is the input dimension
%
%   See also: PSG_GEOMODELS_FIT, PSG_GEOMODELS_PLOT.
%
oldfields={'nestdim_list','d_shuff_nestdim','surrogate_count_nestdim'};
newfields=strrep(oldfields,'nestdim','nestdim_in');
for ref_dim=1:size(results,1)
    for adj_dim=1:size(results,2)
        for ic=1:length(oldfields)
            if isfield(results{ref_dim,adj_dim},oldfields{ic})
                results{ref_dim,adj_dim}.(newfields{ic})=results{ref_dim,adj_dim}.(oldfields{ic});
                results{ref_dim,adj_dim}=rmfield(results{ref_dim,adj_dim},oldfields{ic});
            end
        end
    end
end
rupd=results;
return
end
