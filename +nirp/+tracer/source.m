function stream = source(grid,Q,C,sourceId)
%SOURCE Create a valid tracer source from gridded concentration values.
%   Q is in m^3/s and C is in mol/m^3. E is a unit discrete impulse at
%   t = 0 whose rectangular area is one and which is an exact identity for
%   nirp.conv convolution.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================

    grid = nirp.tracer.validateGrid(grid) ;
    stream = nirp.tracer.emptyStream(grid) ;
    stream.Q = Q ;
    stream.C = C ;
    stream.E(1) = 1/grid.dt ;
    stream.sourceId = sourceId ;
    stream.valid = true ;
    stream.status = uint8(1) ;
    stream = nirp.tracer.validateStream(stream,grid) ;
    if stream.Q <= 0
        error('nirp:tracer:InvalidFlow', ...
            'A valid tracer source requires positive volumetric flow.') ;
    end
    if stream.sourceId == 0
        error('nirp:tracer:InvalidSourceId', ...
            'A valid tracer source requires a nonzero source identifier.') ;
    end
end
