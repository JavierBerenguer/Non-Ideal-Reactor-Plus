function names = componentNames(pkg)
%COMPONENTNAMES Return package component names in definition order.
%   NAMES = nirp.pkg.componentNames(PKG) validates PKG and returns a
%   string row vector. Example: names = nirp.pkg.componentNames(pkg).
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 1, 2026
% =========================================================================

    nirp.pkg.validate(pkg) ;
    names = string({pkg.components.name}) ;
end
