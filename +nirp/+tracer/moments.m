function value = moments(grid,signal)
%MOMENTS Compute tracer signal moments using common-grid quadrature.
%   SIGNAL may be a numeric vector or tracer stream (its C is used).
%   Returned area has signal*time units; tau is in s, sigma2 in s^2,
%   sigma2Theta is dimensionless, and N is its reciprocal.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================

    grid = nirp.tracer.validateGrid(grid) ;
    if isstruct(signal)
        signal = nirp.tracer.validateStream(signal,grid) ;
        signal = signal.C ;
    end
    if ~(isnumeric(signal) && isreal(signal) && isvector(signal) && ...
            numel(signal) == grid.length && all(isfinite(signal(:))) && ...
            all(signal(:) >= 0))
        error('nirp:tracer:InvalidSignal', ...
            'Signal must be a nonnegative finite vector of grid length.') ;
    end
    signal = reshape(double(signal),1,[]) ;
    area = grid.dt*sum(signal) ;
    if area > 0
        tau = grid.dt*sum(grid.t.*signal)/area ;
        sigma2 = grid.dt*sum((grid.t-tau).^2.*signal)/area ;
        if tau > 0
            sigma2Theta = sigma2/tau^2 ;
        else
            sigma2Theta = NaN ;
        end
        if sigma2Theta > 0, n = 1/sigma2Theta; else, n = Inf; end
    else
        tau = NaN ;
        sigma2 = NaN ;
        sigma2Theta = NaN ;
        n = NaN ;
    end
    value = struct('area',area,'tau',tau,'sigma2',sigma2, ...
        'sigma2Theta',sigma2Theta,'N',n) ;
end
