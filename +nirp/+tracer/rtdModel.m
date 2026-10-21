function E = rtdModel(grid,model,parameters,Q)
%RTDMODEL Create a vessel RTD on the common grid.
%   PARAMETERS has tau [s] or V [m^3]. V requires Q [m^3/s]. Tanks in
%   series additionally requires N; dispersion requires Pe and boundary
%   ('open' or 'closed'). MODEL is 'cstr', 'pfr', 'tanks', or 'dispersion'.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================

    grid = nirp.tracer.validateGrid(grid) ;
    if nargin < 4, Q = [] ; end
    tau = residenceTime(parameters,Q) ;
    model = lower(strtrim(char(model))) ;
    switch model
        case 'cstr'
            values = exp(-grid.t/tau)/tau ;
            E = normalize(values,grid.dt) ;
        case 'pfr'
            E = delayedPulse(grid,tau) ;
        case {'tanks','tanks-in-series','tanks_in_series'}
            requireField(parameters,'N') ;
            n = parameters.N ;
            if ~(isnumeric(n) && isreal(n) && isscalar(n) && isfinite(n) && ...
                    n >= 1 && n == fix(n))
                error('nirp:tracer:InvalidModelParameter', ...
                    'N must be a positive integer.') ;
            end
            tauTank = tau/n ;
            values = grid.t.^(n-1).*exp(-grid.t/tauTank)/(gamma(n)*tauTank^n) ;
            E = normalize(values,grid.dt) ;
        case 'dispersion'
            requireField(parameters,'Pe') ;
            pe = parameters.Pe ;
            if ~(isnumeric(pe) && isreal(pe) && isscalar(pe) && isfinite(pe) && pe > 0)
                error('nirp:tracer:InvalidModelParameter','Pe must be positive.') ;
            end
            boundary = 'open' ;
            if isfield(parameters,'boundary'), boundary = lower(char(parameters.boundary)); end
            switch boundary
                case {'open','open-open'}
                    rtd = RTD.dispersion_open(1/pe,tau,grid.t) ;
                case {'closed','closed-closed'}
                    rtd = RTD.dispersion_closed(1/pe,tau,grid.t) ;
                otherwise
                    error('nirp:tracer:InvalidBoundary', ...
                        'Dispersion boundary must be open or closed.') ;
            end
            E = nirp.tracer.rtdData(grid,rtd.t,max(0,rtd.Et)) ;
        otherwise
            error('nirp:tracer:UnknownModel','Unknown vessel RTD model: %s.',model) ;
    end
end

function tau = residenceTime(parameters,Q)
    if ~isstruct(parameters)
        error('nirp:tracer:InvalidModelParameter','Parameters must be a structure.') ;
    end
    if isfield(parameters,'tau')
        tau = parameters.tau ;
    elseif isfield(parameters,'V')
        if ~(isnumeric(Q) && isreal(Q) && isscalar(Q) && isfinite(Q) && Q > 0)
            error('nirp:tracer:InvalidFlow','Positive Q is required when V is specified.') ;
        end
        tau = parameters.V/Q ;
    else
        error('nirp:tracer:MissingResidenceTime','Specify tau or V.') ;
    end
    if ~(isnumeric(tau) && isreal(tau) && isscalar(tau) && isfinite(tau) && tau > 0)
        error('nirp:tracer:InvalidModelParameter','Residence time must be positive.') ;
    end
end

function requireField(value,name)
    if ~isfield(value,name)
        error('nirp:tracer:InvalidModelParameter','Missing parameter %s.',name) ;
    end
end

function E = normalize(E,dt)
    E = max(0,E) ;
    area = dt*sum(E) ;
    if ~(isfinite(area) && area > 0)
        error('nirp:tracer:ZeroRTDArea','Model RTD has zero area on the grid.') ;
    end
    E = E/area ;
end

function E = delayedPulse(grid,tau)
    if tau > grid.tFinal
        error('nirp:tracer:RTDOutsideGrid', ...
            'PFR residence time lies beyond the flowsheet final time.') ;
    end
    position = min(tau/grid.dt,grid.length-1) ;
    lower = floor(position) ;
    fraction = position-lower ;
    E = zeros(1,grid.length) ;
    E(lower+1) = (1-fraction)/grid.dt ;
    if fraction > 0
        E(lower+2) = fraction/grid.dt ;
    end
end
