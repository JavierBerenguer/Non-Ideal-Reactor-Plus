function stream = sourceData(grid,Q,t,C,sourceId)
%SOURCEDATA Create a tracer source from tabular concentration data.
%   Q is in m^3/s, T in s, and C in mol/m^3. Linear interpolation is used;
%   concentration is zero outside the supplied time support.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================

    grid = nirp.tracer.validateGrid(grid) ;
    signal = nirp.conv.signal(t,C) ;
    values = interp1(signal.t,signal.C,grid.t,'linear',0) ;
    stream = nirp.tracer.source(grid,Q,values,sourceId) ;
end
