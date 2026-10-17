function [out,info] = separator(params,in,rs)
%SEPARATOR Split a NIRP stream component by component (T-141).
%   [OUT,INFO] = nirp.units.separator(PARAMS,IN,RS) sends the fraction
%   PARAMS.recovery(i) of each component i (1 x nComponents, values in
%   [0,1]) to OUT{1} (Top) and the rest to OUT{2} (Bottom). The separator
%   is ideal, isothermal and isobaric: both outlets keep T (K), P (Pa),
%   phase and input status, and INFO.heatDuty is 0 W. Liquid Q (m^3/s) is
%   split in proportion to the total molar flow of each outlet (equal molar
%   volumes assumed); gas Q is left empty so that it is recalculated.
%   Degrees of freedom: nComponents recoveries; mass is conserved exactly
%   for every component.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 10, 2026. Last update: October 10, 2026
% =========================================================================

    if ~isstruct(params) || ~isscalar(params)
        error('nirp:units:invalidParameter','params must be a scalar struct.') ;
    end
    requireReactionSystem(rs) ;
    nirp.stream.validate(in,rs.nComponents) ;
    recovery = parameter(params,'recovery',[],true) ;
    if isnumeric(recovery) && isscalar(recovery)
        recovery = repmat(recovery,1,rs.nComponents) ;
    end
    if ~isnumeric(recovery) || ~isreal(recovery) || numel(recovery) ~= rs.nComponents || ...
            any(~isfinite(recovery(:))) || any(recovery(:) < 0) || any(recovery(:) > 1)
        error('nirp:units:invalidRecovery', ...
            'recovery must have one value in [0,1] for each of the %d components.',rs.nComponents) ;
    end
    recovery = reshape(recovery,size(in.F)) ;
    flows = {in.F.*recovery, in.F-in.F.*recovery} ;
    out = cell(1,2) ;
    total = sum(in.F) ;
    for i = 1:2
        if in.status == 0
            out{i} = emptyLike(in,rs.nComponents) ;
        elseif sum(flows{i}) <= 0
            out{i} = nirp.stream.empty(rs.nComponents,in.T,in.P,in.phase) ;
            out{i}.status = in.status ;
        else
            if in.phase == 0 && total > 0, Q = in.Q*sum(flows{i})/total ; else, Q = [] ; end
            out{i} = nirp.stream.create(flows{i},in.T,in.P,in.phase,Q) ;
            out{i}.status = in.status ;
        end
    end
    info = baseInfo(in.status) ;
    info.heatDuty = 0 ;
end
