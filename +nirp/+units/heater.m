function [out,info] = heater(params,in,rs)
%HEATER Solve a nonreactive heater or cooler through the common API.
%   PARAMS.mode is 'Outlet T' or 'Duty'. Outlet T requires Tout (K) and
%   computes duty (W). Duty requires Q (W) and solves outlet temperature.
%   Optional dP is a nonnegative pressure loss in Pa (default 0). Positive
%   duty means heat enters the stream. IN and all calculations use SI.
%   Degrees of freedom: the energy balance relates outlet T and duty, so
%   exactly one is specified. Pressure loss is independent. With the inlet
%   fixed, both current modes have zero remaining DOF.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 1, 2026
% =========================================================================

    if ~isstruct(params) || ~isscalar(params)
        error('nirp:units:invalidParameter','params must be a scalar struct.') ;
    end
    requireReactionSystem(rs) ;
    nirp.stream.validate(in,rs.nComponents) ;
    if in.status == 0
        out = emptyLike(in,rs.nComponents) ;
        info = baseInfo(0) ;
        return
    end
    mode = parameter(params,'mode',[],true) ;
    if isstring(mode) && isscalar(mode)
        mode = char(mode) ;
    end
    dP = parameter(params,'dP',0,false) ;
    if ~isnumeric(dP) || ~isreal(dP) || ~isscalar(dP) || ...
            ~isfinite(dP) || dP < 0 || dP >= in.P
        error('nirp:units:invalidParameter', ...
            'dP must be finite, nonnegative, and less than inlet P.') ;
    end
    Pout = in.P-dP ;

    if strcmp(mode,'Outlet T')
        Tout = parameter(params,'Tout',[],true) ;
        if ~isnumeric(Tout) || ~isreal(Tout) || ~isscalar(Tout) || ...
                ~isfinite(Tout) || Tout <= 0
            error('nirp:units:invalidParameter', ...
                'Tout must be a finite positive scalar in K.') ;
        end
        duty = in.F' * rs.compute_SensibleEnthalpy( ...
            in.T,Tout,Pout)' ;
    elseif strcmp(mode,'Duty')
        duty = parameter(params,'Q',[],true) ;
        if ~isnumeric(duty) || ~isreal(duty) || ~isscalar(duty) || ...
                ~isfinite(duty)
            error('nirp:units:invalidParameter','Q must be finite in W.') ;
        end
        residual = @(T) in.F' * rs.compute_SensibleEnthalpy( ...
            in.T,T,Pout)' - duty ;
        Tout = solveTemperature(residual,in.T) ;
    else
        error('nirp:units:invalidParameter', ...
            'mode must be ''Outlet T'' or ''Duty''.') ;
    end

    if in.phase == 0
        flow = in.Q ;
    else
        flow = [] ;
    end
    out = nirp.stream.create(in.F,Tout,Pout,in.phase,flow) ;
    info = baseInfo(in.status) ;
    info.heatDuty = duty ;
    out.status = in.status ;
end

function temperature = solveTemperature(residual,inletTemperature)
%SOLVETEMPERATURE Find a positive-temperature bracket and solve it.
% Javier Berenguer Sabater, October 1, 2026.
    valueAtInlet = residual(inletTemperature) ;
    if valueAtInlet == 0
        temperature = inletTemperature ;
        return
    end
    lower = max(eps,inletTemperature-50) ;
    upper = inletTemperature+50 ;
    for i = 1:60
        lowerValue = residual(lower) ;
        upperValue = residual(upper) ;
        if lowerValue == 0
            temperature = lower ;
            return
        elseif upperValue == 0
            temperature = upper ;
            return
        elseif sign(lowerValue) ~= sign(upperValue)
            temperature = fzero(residual,[lower upper]) ;
            return
        end
        lower = max(eps,lower-(upper-lower)) ;
        upper = upper+(upper-lower) ;
    end
    error('nirp:units:temperatureSolve', ...
        'Could not bracket a positive outlet temperature for the specified duty.') ;
end
