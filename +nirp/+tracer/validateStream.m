function stream = validateStream(stream,grid)
%VALIDATESTREAM Validate and canonicalize a tracer stream.
%   Q is in m^3/s, C in mol/m^3, and E in 1/s.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================

    grid = nirp.tracer.validateGrid(grid) ;
    names = {'Q','C','E','sourceId','valid','status'} ;
    if ~isstruct(stream) || ~all(isfield(stream,names))
        error('nirp:tracer:InvalidStream', ...
            'Tracer stream does not satisfy the required contract.') ;
    end
    if ~(isnumeric(stream.Q) && isreal(stream.Q) && isscalar(stream.Q) && ...
            isfinite(stream.Q) && stream.Q >= 0)
        error('nirp:tracer:InvalidFlow', ...
            'Volumetric flow Q must be a nonnegative finite scalar in m^3/s.') ;
    end
    stream.C = vector(stream.C,grid.length,'concentration') ;
    stream.E = vector(stream.E,grid.length,'RTD') ;
    if ~(isscalar(stream.sourceId) && isnumeric(stream.sourceId) && ...
            isreal(stream.sourceId) && isfinite(stream.sourceId) && ...
            stream.sourceId >= 0 && stream.sourceId <= intmax('uint32') && ...
            stream.sourceId == fix(stream.sourceId))
        error('nirp:tracer:InvalidSourceId', ...
            'Source identifier must be a nonnegative uint32-compatible integer.') ;
    end
    if ~(isscalar(stream.valid) && (islogical(stream.valid) || isnumeric(stream.valid)))
        error('nirp:tracer:InvalidState','Stream valid flag must be scalar.') ;
    end
    if ~(isscalar(stream.status) && isnumeric(stream.status) && ...
            ismember(double(stream.status),0:2))
        error('nirp:tracer:InvalidState','Stream status must be 0, 1, or 2.') ;
    end
    stream.Q = double(stream.Q) ;
    stream.sourceId = uint32(stream.sourceId) ;
    stream.valid = logical(stream.valid) ;
    stream.status = uint8(stream.status) ;
end

function value = vector(value,n,label)
    if ~(isnumeric(value) && isreal(value) && isvector(value) && ...
            numel(value) == n && all(isfinite(value(:))) && all(value(:) >= 0))
        error('nirp:tracer:InvalidStream', ...
            'Stream %s must be a nonnegative finite vector of grid length.',label) ;
    end
    value = reshape(double(value),1,[]) ;
end
