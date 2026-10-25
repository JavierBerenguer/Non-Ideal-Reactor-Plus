function stream = emptyStream(grid,nComp)
%EMPTYSTREAM Create an invalid tracer stream on a common grid.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 25, 2026
% =========================================================================

    grid = nirp.tracer.validateGrid(grid) ;
    if nargin < 2, nComp = 1 ; end
    validateattributes(nComp,{'numeric'},{'real','scalar','integer','positive','finite'}) ;
    stream = struct('Q',0,'C',zeros(1,grid.length), ...
        'E',zeros(1,grid.length),'sourceId',uint32(0), ...
        'valid',false,'status',uint8(0), ...
        'C0',zeros(1,nComp),'Cseg',zeros(1,nComp), ...
        'Cmm',zeros(1,nComp),'reactiveMode',uint8(0), ...
        'rtdTruncated',false) ;
end
