function [out,info] = mixer(params,ins,rs)
%MIXER Mix NIRP streams using an adiabatic enthalpy balance.
%   PARAMS may be empty. INS is a nonempty cell array of streams. F is
%   summed (mol/s), P is the minimum flowing-stream pressure (Pa), liquid
%   Q values are summed (m^3/s), and gas Q is recalculated. Mixed phases
%   raise nirp:units:phaseMismatch. RS supplies heat capacities.
%   Degrees of freedom: component, energy, volume, and pressure equations
%   determine the outlet from all specified inlets. There are no unit
%   parameters and zero remaining DOF.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 1, 2026
% =========================================================================

    if ~(isempty(params) || (isstruct(params) && isscalar(params)))
        error('nirp:units:invalidParameter', ...
            'params must be empty or a scalar struct.') ;
    end
    requireReactionSystem(rs) ;
    if ~iscell(ins) || isempty(ins)
        error('nirp:units:invalidInput','ins must be a nonempty cell array.') ;
    end
    for i = 1:numel(ins)
        nirp.stream.validate(ins{i},rs.nComponents) ;
    end
    statuses = cellfun(@(s) s.status,ins) ;
    if all(statuses == 0)
        out = emptyLike(ins{1},rs.nComponents) ;
        info = baseInfo(0) ;
        return
    end

    flows = cell2mat(cellfun(@(s) s.F(:)',ins(:), ...
        'UniformOutput',false)) ;
    flowing = sum(flows,2) > 0 ;
    if ~any(flowing)
        out = emptyLike(ins{1},rs.nComponents) ;
        info = baseInfo(min(statuses)) ;
        out.status = info.status ;
        return
    end
    phases = cellfun(@(s) s.phase,ins) ;
    activePhases = phases(flowing) ;
    if any(activePhases ~= activePhases(1))
        error('nirp:units:phaseMismatch', ...
            'Liquid and gas streams cannot be mixed in the v1 API.') ;
    end
    temperatures = cellfun(@(s) s.T,ins) ;
    pressures = cellfun(@(s) s.P,ins) ;
    phase = activePhases(1) ;
    P = min(pressures(flowing)) ;
    [T,ok] = Reactor.mixTemperature(rs,flows(flowing,:), ...
        temperatures(flowing),P) ;
    if ~ok
        error('nirp:units:enthalpyBalance', ...
            'The mixer enthalpy balance could not be solved.') ;
    end
    F = sum(flows,1)' ;
    if phase == 0
        Q = sum(cellfun(@(s) s.Q,ins)) ;
    else
        Q = [] ;
    end
    out = nirp.stream.create(F,T,P,phase,Q) ;
    info = baseInfo(1) ;
    if any(statuses == -1)
        info.status = -1 ;
        out.status = -1 ;
    end
end
