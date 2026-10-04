function obj = toStream(s)
%TOSTREAM Convert a validated NIRP SI stream structure to Stream.
%   Unit labels are set to mol/s, mol/m^3, m^3/s, K, and Pa.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 1, 2026
% =========================================================================

    nirp.stream.validate(s) ;
    obj = Stream ;
    obj.molarFlow = s.F(:)' ;
    obj.molarFlow_Units = 'mol/s' ;
    obj.concentration = [] ;
    obj.concentration_Units = 'mol/m^3' ;
    obj.T = s.T ;
    obj.T_Units = 'K' ;
    obj.P = s.P ;
    obj.P_Units = 'Pa' ;
    obj.volumetricFlow_Units = 'm^3/s' ;
    if s.phase == 0
        obj.phase = 'L' ;
        obj.volumetricFlow = s.Q ;
    else
        obj.phase = 'G' ;
        obj.volumetricFlow = [] ;
    end
end
