function s = signal(t,C)
%SIGNAL Create a validated tracer signal.
%   S = nirp.conv.signal(T,C) stores time T in seconds and concentration C
%   (in any consistent concentration unit) as row vectors.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 9, 2026. Last update: October 9, 2026
% =========================================================================

    if ~(isnumeric(t) && isreal(t) && isvector(t) && numel(t) >= 2 && ...
            all(isfinite(t(:))))
        error('nirp:conv:InvalidTime', ...
            'Time must be a finite real vector with at least two points.') ;
    end
    if ~(isnumeric(C) && isreal(C) && isvector(C) && numel(C) == numel(t) && ...
            all(isfinite(C(:))))
        error('nirp:conv:InvalidConcentration', ...
            'Concentration must be a finite real vector with the same size as time.') ;
    end

    t = reshape(double(t),1,[]) ;
    C = reshape(double(C),1,[]) ;
    if any(diff(t) <= 0)
        error('nirp:conv:NonIncreasingTime', ...
            'Time values must be strictly increasing.') ;
    end
    if any(C < 0)
        error('nirp:conv:NegativeConcentration', ...
            'Concentration values must be nonnegative.') ;
    end

    s = struct('t',t,'C',C) ;
end
