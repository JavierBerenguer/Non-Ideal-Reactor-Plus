function s = fromRTD(rtd,dt)
%FROMRTD Discretize an RTD into interval-average E values.
%   DT is the target interval width in seconds. Each sample is obtained from
%   the change in F over the interval centered on that sample.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 9, 2026. Last update: October 9, 2026
% =========================================================================

    if ~isa(rtd,'RTD') || isempty(rtd.t) || isempty(rtd.Et)
        error('nirp:conv:InvalidRTD','Input must be a nonempty RTD object.') ;
    end
    if ~(isnumeric(dt) && isreal(dt) && isscalar(dt) && isfinite(dt) && dt > 0)
        error('nirp:conv:InvalidStep','Time step dt must be a positive finite scalar.') ;
    end

    tStart = rtd.t(1) ;
    count = ceil((rtd.t(end)-tStart)/dt) ;
    t = tStart + (0:count)*dt ;
    left = t-dt/2 ;
    right = t+dt/2 ;
    Ft = rtd.Ft ;
    leftF = interp1(rtd.t,Ft,left,'linear',NaN) ;
    rightF = interp1(rtd.t,Ft,right,'linear',NaN) ;
    leftF(left < rtd.t(1)) = 0 ;
    rightF(right > rtd.t(end)) = Ft(end) ;
    leftF(left > rtd.t(end)) = Ft(end) ;
    rightF(right < rtd.t(1)) = 0 ;
    E = max(0,(rightF-leftF)/dt) ;
    s = nirp.conv.signal(t,E) ;
end
