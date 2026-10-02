function [out,info] = splitter(params,in,rs)
%SPLITTER Divide a NIRP stream according to dimensionless fractions.
%   PARAMS.fractions must contain values in [0,1] summing to one within
%   1e-12. Each output preserves T (K), P (Pa), phase, and input status;
%   F (mol/s) and liquid Q (m^3/s) are split proportionally. RS is used
%   only to validate the component count.
%   Degrees of freedom: N fractions have one sum equation, so N-1 are
%   independent specifications. Outlet states and flows then follow from
%   the inlet and the current mode has zero remaining DOF.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 1, 2026
% =========================================================================

    if ~isstruct(params) || ~isscalar(params)
        error('nirp:units:invalidParameter','params must be a scalar struct.') ;
    end
    requireReactionSystem(rs) ;
    nirp.stream.validate(in,rs.nComponents) ;
    fractions = parameter(params,'fractions',[],true) ;
    if ~isnumeric(fractions) || ~isreal(fractions) || ...
            ~isvector(fractions) || isempty(fractions) || ...
            any(~isfinite(fractions)) || any(fractions < 0) || ...
            any(fractions > 1) || abs(sum(fractions)-1) > 1e-12
        error('nirp:units:invalidFractions', ...
            'fractions must be finite values in [0,1] that sum to one.') ;
    end

    fractions = fractions(:)' ;
    out = cell(size(fractions)) ;
    for i = 1:numel(fractions)
        if in.status == 0
            out{i} = emptyLike(in,rs.nComponents) ;
        else
            if in.phase == 0
                Q = in.Q*fractions(i) ;
            else
                Q = [] ;
            end
            if fractions(i) == 0
                out{i} = nirp.stream.empty( ...
                    rs.nComponents,in.T,in.P,in.phase) ;
                out{i}.status = in.status ;
            else
                out{i} = nirp.stream.create(in.F*fractions(i), ...
                    in.T,in.P,in.phase,Q) ;
                out{i}.status = in.status ;
            end
        end
    end
    info = baseInfo(in.status) ;
end
