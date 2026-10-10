function requireThermodynamics(pkg,what)
%REQUIRETHERMODYNAMICS Stop a block that needs Cp and DH when the package has none.
%   nirp.blocks.internal.requireThermodynamics(PKG,WHAT) raises
%   nirp:blocks:noThermodynamics if the Reactive System was defined
%   "Without thermodynamics" (PKG.meta.thermodynamics = false).
% =========================================================================
% Javier Berenguer Sabater
% Created: October 10, 2026. Last update: October 10, 2026
% =========================================================================

    if isfield(pkg.meta,'thermodynamics') && isequal(pkg.meta.thermodynamics,false)
        error('nirp:blocks:noThermodynamics', ...
            ['%s needs heat capacities and reaction enthalpies, but the Reactive System ' ...
            'was defined without thermodynamics. Use an isothermal reactor or enter the ' ...
            'data in Reactive System > Thermodynamics.'],what) ;
    end
end
