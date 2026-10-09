function s = fromFunction(f,tGrid)
%FROMFUNCTION Evaluate a tracer concentration function on a time grid.
%   TGRID is in seconds. F must return a scalar or one value per grid point.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 9, 2026. Last update: October 9, 2026
% =========================================================================

    if ~isa(f,'function_handle')
        error('nirp:conv:InvalidFunction', ...
            'The signal function must be a function handle.') ;
    end
    try
        C = f(tGrid) ;
    catch exception
        error('nirp:conv:FunctionEvaluationFailed', ...
            'The signal function could not be evaluated: %s',exception.message) ;
    end
    if isscalar(C)
        C = repmat(C,size(tGrid)) ;
    end
    s = nirp.conv.signal(tGrid,C) ;
end
