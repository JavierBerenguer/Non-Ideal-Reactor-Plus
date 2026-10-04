function s = empty(nComp,T,P,phase)
%EMPTY Create an empty NIRP stream with nComp components in SI units.
%   The returned stream has zero F (mol/s), zero Q (m^3/s), and status 0.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 1, 2026
% =========================================================================

    if ~isnumeric(nComp) || ~isscalar(nComp) || ~isfinite(nComp) || ...
            nComp < 1 || nComp ~= fix(nComp)
        error('nirp:stream:invalid', ...
            'nComp must be a positive integer scalar.') ;
    end
    s = nirp.stream.create(zeros(nComp,1),T,P,phase,0) ;
    s.Q = 0 ;
    s.status = 0 ;
end
