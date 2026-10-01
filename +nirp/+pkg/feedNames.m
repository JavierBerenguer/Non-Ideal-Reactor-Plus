function names = feedNames(pkg)
%FEEDNAMES Return package feed names in definition order.
%   NAMES = nirp.pkg.feedNames(PKG) returns a string row vector.
%   Example: names = nirp.pkg.feedNames(pkg).
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 1, 2026
% =========================================================================

    nirp.pkg.validate(pkg) ;
    names = string({pkg.feeds.name}) ;
end
