function stream = emptyStream(grid)
%EMPTYSTREAM Create an invalid tracer stream on a common grid.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================

    grid = nirp.tracer.validateGrid(grid) ;
    stream = struct('Q',0,'C',zeros(1,grid.length), ...
        'E',zeros(1,grid.length),'sourceId',uint32(0), ...
        'valid',false,'status',uint8(0)) ;
end
