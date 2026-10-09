function out = resample(s,dt,t0)
%RESAMPLE Linearly resample a tracer signal on a uniform grid.
%   DT and optional T0 are in seconds. Values beyond the source support are
%   zero. T0 defaults to the first source time.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 9, 2026. Last update: October 9, 2026
% =========================================================================

    s = nirp.conv.signal(s.t,s.C) ;
    if ~(isnumeric(dt) && isreal(dt) && isscalar(dt) && isfinite(dt) && dt > 0)
        error('nirp:conv:InvalidStep','Time step dt must be a positive finite scalar.') ;
    end
    if nargin < 3
        t0 = s.t(1) ;
    end
    if ~(isnumeric(t0) && isreal(t0) && isscalar(t0) && isfinite(t0))
        error('nirp:conv:InvalidOrigin','Grid origin t0 must be a finite scalar.') ;
    end
    if t0 > s.t(1)
        error('nirp:conv:TruncatedResample', ...
            'Grid origin t0 must not be later than the first signal time.') ;
    end

    count = ceil((s.t(end)-t0)/dt) ;
    t = t0 + (0:count)*dt ;
    C = interp1(s.t,s.C,t,'linear',0) ;
    C = max(0,C) ;
    out = nirp.conv.signal(t,C) ;
end
