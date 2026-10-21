function grid = validateGrid(grid)
%VALIDATEGRID Validate and canonicalize a tracer flowsheet grid.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================

    if ~isstruct(grid) || ~all(isfield(grid,{'dt','tFinal','t','length'}))
        error('nirp:tracer:InvalidGrid', ...
            'Grid must be created with nirp.tracer.grid.') ;
    end
    expected = nirp.tracer.grid(grid.dt,grid.tFinal) ;
    tolerance = 100*eps(max([1 abs(expected.t)])) ;
    if ~(isnumeric(grid.t) && isvector(grid.t) && ...
            numel(grid.t) == expected.length && ...
            all(abs(double(grid.t(:).')-expected.t) <= tolerance) && ...
            isequal(double(grid.length),double(expected.length)))
        error('nirp:tracer:InvalidGrid', ...
            'Grid fields are inconsistent with dt and final time.') ;
    end
    grid = expected ;
end
