function E = rtdData(grid,t,values)
%RTDDATA Resample RTD data onto the common grid while preserving area.
%   T is in seconds and VALUES in 1/s. The returned density uses the
%   rectangular quadrature associated with nirp.conv.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================

    grid = nirp.tracer.validateGrid(grid) ;
    signal = nirp.conv.signal(t,values) ;
    E = interp1(signal.t,signal.C,grid.t,'linear',0) ;
    E = max(0,E) ;
    area = grid.dt*sum(E) ;
    if ~(isfinite(area) && area > 0)
        error('nirp:tracer:ZeroRTDArea', ...
            'RTD data have zero area on the flowsheet grid.') ;
    end
    E = E/area ;
end
