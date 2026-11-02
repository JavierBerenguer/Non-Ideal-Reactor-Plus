function value = presentationMoments(grid,signal,tauCorrection)
%PRESENTATIONMOMENTS Report moments on the Tab 1/Tab 6 time convention.
%   The viewer applies a topology-derived correction for discrete
%   convolution bias without changing the core rectangular quadrature or
%   the simulated signal.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================
    if nargin<3,tauCorrection=0;end
    value=nirp.tracer.moments(grid,signal);
    if isfinite(value.tau)
        value.tau=value.tau+tauCorrection;
        if value.tau>0,value.sigma2Theta=value.sigma2/value.tau^2;else,value.sigma2Theta=NaN;end
        if value.sigma2Theta>0,value.N=1/value.sigma2Theta;else,value.N=Inf;end
    end
end
