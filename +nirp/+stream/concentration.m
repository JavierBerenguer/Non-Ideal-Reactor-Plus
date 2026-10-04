function C = concentration(s)
%CONCENTRATION Return component concentrations F/Q in mol/m^3.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 1, 2026
% =========================================================================

    nirp.stream.validate(s) ;
    if s.Q == 0
        error('nirp:stream:zeroFlow', ...
            'Concentration is undefined for a stream with Q equal to zero.') ;
    end
    C = s.F/s.Q ;
end
