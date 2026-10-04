function s = create(F,T,P,phase,Q)
%CREATE Create a validated NIRP stream structure in SI units.
%   S = nirp.stream.create(F,T,P,PHASE,Q) uses component molar flows F
%   (mol/s), temperature T (K), pressure P (Pa), phase 0 (liquid) or 1
%   (gas), and liquid volumetric flow Q (m^3/s). For a gas, Q is optional
%   and any supplied value is ignored; ideal-gas Q is always recalculated.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 1, 2026
% =========================================================================

    if nargin < 5
        Q = [] ;
    end
    if ~isnumeric(F) || ~isreal(F) || ~isvector(F) || isempty(F) || ...
            any(~isfinite(F(:))) || any(F(:) < 0)
        error('nirp:stream:invalid', ...
            'F must be a nonempty, finite, nonnegative numeric vector.') ;
    end
    if ~isnumeric(T) || ~isreal(T) || ~isscalar(T) || ...
            ~isfinite(T) || T <= 0
        error('nirp:stream:invalid', ...
            'T must be a finite positive scalar in K.') ;
    end
    if ~isnumeric(P) || ~isreal(P) || ~isscalar(P) || ...
            ~isfinite(P) || P <= 0
        error('nirp:stream:invalid', ...
            'P must be a finite positive scalar in Pa.') ;
    end
    if ~isnumeric(phase) || ~isreal(phase) || ~isscalar(phase) || ...
            ~ismember(phase,[0 1])
        error('nirp:stream:invalid', ...
            'phase must be scalar 0 (liquid) or 1 (gas).') ;
    end

    F = F(:) ;
    if phase == 0
        if ~isnumeric(Q) || ~isreal(Q) || ~isscalar(Q) || ...
                ~isfinite(Q) || Q < 0 || (any(F > 0) && Q <= 0)
            error('nirp:stream:invalid', ...
                'Liquid Q must be finite and positive when F is nonzero.') ;
        end
    else
        Q = sum(F)*8.314*T/P ;
    end
    s = struct('F',F,'T',T,'P',P,'phase',phase,'Q',Q,'status',1) ;
end
