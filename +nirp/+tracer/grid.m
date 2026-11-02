function value = grid(dt,tFinal)
%GRID Create the common tracer flowsheet time grid.
%   DT and TFINAL are in seconds.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================

    if ~(isnumeric(dt) && isreal(dt) && isscalar(dt) && isfinite(dt) && dt > 0)
        error('nirp:tracer:InvalidStep', ...
            'Time step dt must be a positive finite scalar in seconds.') ;
    end
    if ~(isnumeric(tFinal) && isreal(tFinal) && isscalar(tFinal) && ...
            isfinite(tFinal) && tFinal >= dt)
        error('nirp:tracer:InvalidFinalTime', ...
            'Final time must be finite and at least one time step.') ;
    end
    count = round(tFinal/dt) ;
    tolerance = 100*eps(max(1,abs(tFinal))) ;
    if abs(count*dt-tFinal) > tolerance
        error('nirp:tracer:IncommensurateGrid', ...
            'Final time must be an integer multiple of dt.') ;
    end
    value = struct('dt',double(dt),'tFinal',double(tFinal), ...
        't',(0:count)*double(dt),'length',count+1) ;
end
