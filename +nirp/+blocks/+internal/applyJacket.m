function params = applyJacket(params,jacket,kind)
%APPLYJACKET Apply the Jacket signal to the thermal parameters of a reactor.
%   PARAMS = nirp.blocks.internal.applyJacket(PARAMS,JACKET,KIND) reads
%   [mode; v1; v2; v3; v4] in SI (T-146): mode 1 = utility [U; A; Tin; Tout],
%   mode 2 = specified reactor T [T; NaN; NaN; NaN], mode 3 = specified duty
%   [Q; NaN; NaN; NaN] (Q > 0 adds heat). The older 4-element signal
%   [U; A; Tin; Tout] is read as mode 1.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 10, 2026. Last update: October 10, 2026
% =========================================================================

    if isnumeric(jacket) && isequal(size(jacket),[4 1]), jacket = [1; jacket] ; end
    if ~isnumeric(jacket) || ~isequal(size(jacket),[5 1]) || ~any(jacket(1) == [1 2 3])
        error('nirp:blocks:invalidJacket', ...
            '%s Jacket input must be [mode; values] with mode 1, 2 or 3.',kind) ;
    end
    switch jacket(1)
        case 1
            value = jacket(2:5) ;
            if any(~isfinite(value(1:3))) || value(1) < 0 || any(value(2:3) <= 0) || ...
                    (~isnan(value(4)) && (~isfinite(value(4)) || value(4) <= 0))
                error('nirp:blocks:invalidJacket', ...
                    '%s Jacket input must be [U; A; Tin; Tout] in SI, with Tout optionally NaN.',kind) ;
            end
            params.heatMode = 'Other' ; params.U = value(1) ;
            params.A = value(2) ; params.utilityTin = value(3) ;
            if isnan(value(4)), params.utilityTout = [] ; else, params.utilityTout = value(4) ; end
        case 2
            if ~isfinite(jacket(2)) || jacket(2) <= 0
                error('nirp:blocks:invalidJacket','%s Jacket reactor temperature must be positive K.',kind) ;
            end
            params.heatMode = 'Specified T' ; params.specifiedT = jacket(2) ;
        case 3
            if ~isfinite(jacket(2))
                error('nirp:blocks:invalidJacket','%s Jacket heat duty must be finite W.',kind) ;
            end
            params.heatMode = 'Specified Q' ; params.specifiedQ = jacket(2) ;
    end
end
