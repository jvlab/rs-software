function opts_use=psg_defopts(opts)
%opts_use=psg_defopts(opts) sets up default options for perceptual space geometry experiments
%
% opts: optional overrides, may be omitted
%   also may be an array created by psg_sessconfig_make, in which case
%   opts.cond_nstims, opts.cond_ncompares, and opts.cond_nsess are taken from sess
%
% opts_use: full options structure
%
%  17Nov22: add setseq: options for stimulus sets across sessions
%  20Nov22: add typeno_zpad
%  31Dec22: add option of using a session array as input
%  20Feb23: add if_eachsess
%  31May23: add cond_nstims_toreplace
%  17Jun23: add ray_minpts, ray_tol, ray_res_ring, ray_min_ring, ray_permute_raynums, ray_mindist_tol
%  18Jun23: add ray_onlycardinal:  1 to only consider cardinal rays
%  28Jun23: replace ray_onlycardinal by ray_dirkeep
%  29Jun23: add faces_mpi_inventory_filename
%  11Sep23: add example_numoffset, sess_numoffset
%  01Oct23: add example_maxnum
%  12Nov23: add fields_align, fields_pool
%  23Nov24: add fields_remake
%  21Sep25: add ray_reorder_ring
%  21Sep25: add ray_plane_jit
%  15Jan26: add 'type_coords' to fields that need to be aligned, and 'coord_fields'
% 
%  See also  FILLDEFAULT, PSG_SESSONFIG_MAKE, PSG_COND_WRITE, PSG_SETUP_DEMO, PSG_COND_CREATE,
%   PSG_COND_WRITE, PSG_COND_CREATE.
%
if (nargin<1)
    opts=struct;
elseif ~isstruct(opts)
    sess=opts;
    opts=struct;
    opts.cond_nstims=length(unique(sess(:)));
    opts.cond_ncompares=size(sess,2)-1;
    opts.cond_nsess=size(sess,3);
end
%
%logging and calculation
opts=filldefault(opts,'if_log',0); %1 to log
opts=filldefault(opts,'if_cumulative',0); %whether to compute statistics for each session cumulatively
opts=filldefault(opts,'if_eachsess',1); %whether to compute statistics separately for each session
%
%session parameters
opts=filldefault(opts,'cond_nstims',25);
opts=filldefault(opts,'cond_nstims_toreplace',0); %number of stimuli to replace by lower-numbered stims
opts=filldefault(opts,'cond_ncompares',8);
opts=filldefault(opts,'cond_novlp',2);
opts=filldefault(opts,'cond_nsess',10);
opts=filldefault(opts,'refseq',1); %randomization method for reference stimuli shared across contexts
opts=filldefault(opts,'refseq_labels',{'random','ordered','frozen randomization'});
opts=filldefault(opts,'setseq',1); %how stimulus sets are changed across sessions
opts=filldefault(opts,'setseq_labels',{'unique','same_sets','same_sets_same_positions','same_positions'});
%
%options related to stimulus example reuse, mostly for psg_cond_create
opts=filldefault(opts,'example_infix_mode',1); %whether to use different examples of each stimulus across sessions, or within sessions, or not at all
opts=filldefault(opts,'example_infix_labels',{'different examples across all sessions','different examples within session','single example','single example, no infix'});
opts=filldefault(opts,'example_infix_string','_'); %separator between stimulus name and example number
opts=filldefault(opts,'example_infix_zpad',3); %number of digits to zero-pad 
opts=filldefault(opts,'example_numoffset',0); %offset to first example number (for creating additional batches of sessions)
opts=filldefault(opts,'example_maxnum',Inf); %maximum number of examples.  example numbers begin at 0, and will be numbered example_numoffset+[0:example_maxnum-1].  
%
%ray options
opts=filldefault(opts,'ray_res_ring',10^(-2)); %tolerance for equal radii for a ring
opts=filldefault(opts,'ray_min_ring',4); %minimum points in a ring
opts=filldefault(opts,'ray_permute_raynums',[]); %ray number permutation
opts=filldefault(opts,'ray_tol',10^(-5)); %tolerance for rays
opts=filldefault(opts,'ray_minpts',3); %minimum number of nonzero points on a ray
opts=filldefault(opts,'ray_mindist_tol',10^(-2)); %tolerance for nearest-neighbor distances
%opts=filldefault(opts,'ray_onlycardinal',0); %set to 1 to only find rays along cardinal axes
opts=filldefault(opts,'ray_dirkeep','all');
opts=filldefault(opts,'ray_dirkeep_labels',{'all','card_diag','card','diag'});
opts=filldefault(opts,'ray_reorder_ring',0); %1 to reorder the indices in a ring to start with lowest and then next-lowest (to avoid dependence on sign of pcs in psg_planecycle)
opts=filldefault(opts,'ray_plane_jit',0); %small and nonzero (e.g,. 10^-3) to disambiguate flattening of rays into a ring
%
%file name creation options
opts=filldefault(opts,'sess_zpad',2); %zero-padding in session name
opts=filldefault(opts,'stim_filetype','png'); %file type
opts=filldefault(opts,'typeno_zpad',2); %padding for type number (unique ID for stimulus, 1 to cond_nstims)
opts=filldefault(opts,'sess_numoffset',0); %offset to first session number (for creating additional batches of sessions)
%
%link to mpi faces
opts=filldefault(opts,'faces_mpi_inventory_filename','faces_mpi_inventory.mat');
%
%options for aligning datasets
opts=filldefault(opts,'coord_fields',{'type_coords','btc_specoords','btc_augcoords'}); %field names, in order of priority, with notional stimulus coordinates
opts=filldefault(opts,'fields_align',{'specs','spec_labels','btc_augcoords','btc_specoords','type_coords'}); %fields that need to be aligned
opts=filldefault(opts,'fields_pool',{'nstims','typenames'}); %fields to be pooled
opts=filldefault(opts,'fields_remake',cell(0)); %fields that need to be remade
%
opts_use=opts;
return
