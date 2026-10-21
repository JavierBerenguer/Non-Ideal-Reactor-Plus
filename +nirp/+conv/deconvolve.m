function [E,info] = deconvolve(Cin,Cout,support)
%DECONVOLVE Estimate a nonnegative RTD signal by least squares.
%   CIN and COUT use seconds and must have a common uniform DT. SUPPORT is
%   either [TAUMIN TAUMAX] in seconds or the legacy scalar number of RTD
%   samples. When omitted, the legacy complete-convolution length is used.
%   CIN is zero outside its stated interval. The estimated E is not
%   normalized.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 9, 2026. Last update: October 21, 2026
% =========================================================================

    Cin = nirp.conv.signal(Cin.t,Cin.C) ;
    Cout = nirp.conv.signal(Cout.t,Cout.C) ;
    dtIn = uniformStep(Cin) ;
    dtOut = uniformStep(Cout) ;
    tolerance = 100*eps(max([1 abs(dtIn) abs(dtOut)])) ;
    if abs(dtIn-dtOut) > tolerance
        error('nirp:conv:StepMismatch', ...
            ['Signals must have the same uniform time step. ' ...
             'Use nirp.conv.resample before deconvolution.']) ;
    end

    if nargin < 3 || isempty(support)
        nE = numel(Cout.C)-numel(Cin.C)+1 ;
        if nE < 1
            error('nirp:conv:InvalidLength', ...
                'The default nE is impossible when output is shorter than input.') ;
        end
        tau = Cout.t(1)-Cin.t(1)+(0:nE-1)*dtIn ;
    elseif isnumeric(support) && isreal(support) && isscalar(support) && ...
            isfinite(support)
        nE = support ;
        if nE ~= fix(nE) || nE < 1 || nE > numel(Cout.C)
            error('nirp:conv:InvalidLength', ...
                'nE must be a positive integer no larger than the output length.') ;
        end
        tau = Cout.t(1)-Cin.t(1)+(0:nE-1)*dtIn ;
    elseif isnumeric(support) && isreal(support) && numel(support) == 2 && ...
            all(isfinite(support)) && support(1) >= 0 && support(2) >= support(1)
        support = double(support(:).') ;
        intervals = (support(2)-support(1))/dtIn ;
        if abs(intervals-round(intervals)) > 1e-9*max(1,abs(intervals))
            error('nirp:conv:SupportGridMismatch', ...
                'E support endpoints must lie on the common time-step grid.') ;
        end
        tau = support(1)+(0:round(intervals))*dtIn ;
        nE = numel(tau) ;
    else
        error('nirp:conv:InvalidSupport', ...
            'Support must be [tau_min tau_max] with 0 <= tau_min <= tau_max.') ;
    end

    sampleTimes = Cout.t(:)-tau ;
    matrix = interp1(Cin.t,Cin.C,sampleTimes,'linear',0)*dtIn ;
    [estimated,resnorm,residual] = lsqnonneg(matrix,Cout.C.') ;
    E = nirp.conv.signal(tau,estimated.') ;

    fitted = (matrix*estimated).' ;
    reconvolved = nirp.conv.signal(Cout.t,fitted) ;
    areaE = sum(E.C)*dtIn ;
    areaIn = sum(Cin.C)*dtIn ;
    areaOut = sum(Cout.C)*dtIn ;
    if areaIn > 0
        massBalance = areaOut/areaIn ;
    else
        massBalance = NaN ;
    end
    info = struct('residualNorm',sqrt(resnorm),'residual',residual.', ...
        'areaE',areaE,'massBalance',massBalance, ...
        'reconvolved',reconvolved,'support',tau([1 end]), ...
        'numberOfEquations',numel(Cout.C),'numberOfUnknowns',nE, ...
        'underdetermined',nE > numel(Cout.C)) ;
end

function dt = uniformStep(s)
    steps = diff(s.t) ;
    dt = steps(1) ;
    tolerance = 100*eps(max([1 abs(s.t) abs(dt)])) ;
    if any(abs(steps-dt) > tolerance)
        error('nirp:conv:NonuniformGrid', ...
            ['Signal time vectors must be uniform. ' ...
             'Use nirp.conv.resample before deconvolution.']) ;
    end
end
