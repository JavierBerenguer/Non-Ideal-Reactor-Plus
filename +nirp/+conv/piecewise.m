function s = piecewise(edges,exprs,tGrid)
%PIECEWISE Build a tracer signal from function-handle segments.
%   EDGES and TGRID are in seconds. EXPRS{k} applies from EDGES(k) through
%   EDGES(k+1); the signal is zero outside the complete interval.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 9, 2026. Last update: October 9, 2026
% =========================================================================

    if ~(isnumeric(edges) && isreal(edges) && isvector(edges) && ...
            numel(edges) >= 2 && all(isfinite(edges(:))) && all(diff(edges) > 0))
        error('nirp:conv:InvalidEdges', ...
            'Segment edges must be a finite, strictly increasing vector.') ;
    end
    if ~iscell(exprs) || numel(exprs) ~= numel(edges)-1 || ...
            ~all(cellfun(@(f) isa(f,'function_handle'),exprs))
        error('nirp:conv:InvalidExpressions', ...
            'Expressions must contain one function handle per interval.') ;
    end

    base = nirp.conv.signal(tGrid,zeros(size(tGrid))) ;
    C = zeros(size(base.t)) ;
    for k = 1:numel(exprs)
        if k < numel(exprs)
            selected = base.t >= edges(k) & base.t < edges(k+1) ;
        else
            selected = base.t >= edges(k) & base.t <= edges(k+1) ;
        end
        values = exprs{k}(base.t(selected)) ;
        if isscalar(values)
            values = repmat(values,1,nnz(selected)) ;
        end
        if ~(isnumeric(values) && isreal(values) && numel(values) == nnz(selected))
            error('nirp:conv:InvalidFunctionOutput', ...
                'Each segment function must return a scalar or one real value per time point.') ;
        end
        C(selected) = reshape(values,1,[]) ;
    end
    s = nirp.conv.signal(base.t,C) ;
end
