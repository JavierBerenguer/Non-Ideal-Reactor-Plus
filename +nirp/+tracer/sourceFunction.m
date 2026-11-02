function stream = sourceFunction(grid,Q,edges,functions,sourceId)
%SOURCEFUNCTION Create a tracer source from piecewise functions.
%   EDGES are in seconds. FUNCTIONS is a cell array of function handles,
%   one for each interval between consecutive edges. Q is in m^3/s and
%   returned concentration is interpreted as mol/m^3.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================

    grid = nirp.tracer.validateGrid(grid) ;
    signal = nirp.conv.piecewise(edges,functions,grid.t) ;
    stream = nirp.tracer.source(grid,Q,signal.C,sourceId) ;
end
