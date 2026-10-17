function [out,info] = convolve(E,Cin)
%CONVOLVE Convolve a residence-time signal and an inlet tracer signal.
%   Both time vectors are in seconds and must be uniform with the same DT.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 9, 2026. Last update: October 9, 2026
% =========================================================================

    E = nirp.conv.signal(E.t,E.C) ;
    Cin = nirp.conv.signal(Cin.t,Cin.C) ;
    dtE = uniformStep(E) ;
    dtIn = uniformStep(Cin) ;
    tolerance = 100*eps(max([1 abs(dtE) abs(dtIn)])) ;
    if abs(dtE-dtIn) > tolerance
        error('nirp:conv:StepMismatch', ...
            ['Signals must have the same uniform time step. ' ...
             'Use nirp.conv.resample before convolution.']) ;
    end

    dt = (dtE+dtIn)/2 ;
    C = conv(E.C,Cin.C)*dt ;
    t0 = E.t(1)+Cin.t(1) ;
    out = nirp.conv.signal(t0+(0:numel(C)-1)*dt,C) ;
    eMoments = nirp.conv.moments(E) ;
    inMoments = nirp.conv.moments(Cin) ;
    outMoments = nirp.conv.moments(out) ;
    denominator = eMoments.area*inMoments.area ;
    if denominator > 0
        balance = outMoments.area/denominator ;
    else
        balance = NaN ;
    end
    info = struct('dt',dt,'areaE',eMoments.area, ...
        'areaIn',inMoments.area,'areaOut',outMoments.area, ...
        'massBalance',balance,'momentsE',eMoments, ...
        'momentsIn',inMoments,'momentsOut',outMoments) ;
end

function dt = uniformStep(s)
    steps = diff(s.t) ;
    dt = steps(1) ;
    tolerance = 100*eps(max([1 abs(s.t) abs(dt)])) ;
    if any(abs(steps-dt) > tolerance)
        error('nirp:conv:NonuniformGrid', ...
            ['Signal time vectors must be uniform. ' ...
             'Use nirp.conv.resample before convolution.']) ;
    end
end
