function out = series(E1,E2)
%SERIES Compose two RTD signals connected in series.
%   Both time vectors are in seconds and must use the same uniform step.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 9, 2026. Last update: October 9, 2026
% =========================================================================

    out = nirp.conv.convolve(E1,E2) ;
end
