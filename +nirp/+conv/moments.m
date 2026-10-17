function values = moments(s)
%MOMENTS Compute trapezoidal area, mean time, and variance of a signal.
%   Time is in seconds; variance is in seconds squared.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 9, 2026. Last update: October 9, 2026
% =========================================================================

    s = nirp.conv.signal(s.t,s.C) ;
    area = trapz(s.t,s.C) ;
    if area <= 0
        meanTime = NaN ;
        variance = NaN ;
    else
        meanTime = trapz(s.t,s.t.*s.C)/area ;
        variance = trapz(s.t,(s.t-meanTime).^2.*s.C)/area ;
    end
    values = struct('area',area,'mean',meanTime,'variance',variance) ;
end
