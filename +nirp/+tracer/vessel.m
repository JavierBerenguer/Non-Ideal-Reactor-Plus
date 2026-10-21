function [out,info] = vessel(grid,in,E)
%VESSEL Apply a vessel RTD to tracer concentration and accumulated RTD.
%   E is in 1/s. Outputs are truncated to the common grid. INFO reports
%   discarded rectangular area for both C and E, without renormalization.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================

    grid = nirp.tracer.validateGrid(grid) ;
    in = nirp.tracer.validateStream(in,grid) ;
    E = density(E,grid.length) ;
    vesselSignal = nirp.conv.signal(grid.t,E) ;
    concentration = nirp.conv.convolve(vesselSignal, ...
        nirp.conv.signal(grid.t,in.C)) ;
    accumulated = nirp.conv.convolve(vesselSignal, ...
        nirp.conv.signal(grid.t,in.E)) ;
    n = grid.length ;
    out = in ;
    out.C = concentration.C(1:n) ;
    out.E = accumulated.C(1:n) ;
    areaCFull = grid.dt*sum(concentration.C) ;
    areaEFull = grid.dt*sum(accumulated.C) ;
    areaCKept = grid.dt*sum(out.C) ;
    areaEKept = grid.dt*sum(out.E) ;
    info = struct('areaCFull',areaCFull,'areaCKept',areaCKept, ...
        'areaCLost',max(0,areaCFull-areaCKept), ...
        'fractionCLost',fractionLost(areaCFull,areaCKept), ...
        'areaEFull',areaEFull,'areaEKept',areaEKept, ...
        'areaELost',max(0,areaEFull-areaEKept), ...
        'fractionELost',fractionLost(areaEFull,areaEKept)) ;
    out = nirp.tracer.validateStream(out,grid) ;
end

function value = density(value,n)
    if ~(isnumeric(value) && isreal(value) && isvector(value) && ...
            numel(value) == n && all(isfinite(value(:))) && all(value(:) >= 0))
        error('nirp:tracer:InvalidRTD', ...
            'Vessel RTD must be a nonnegative finite vector of grid length.') ;
    end
    value = reshape(double(value),1,[]) ;
end

function value = fractionLost(full,kept)
    if full > 0, value = max(0,1-kept/full); else, value = 0; end
end
