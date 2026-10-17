function [E,info] = deconvolve(Cin,Cout,nE)
%DECONVOLVE Estimate a nonnegative RTD signal by least squares.
%   CIN and COUT use seconds and must have a common uniform DT. NE defaults
%   to numel(COUT)-numel(CIN)+1. The estimated E is not normalized.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 9, 2026. Last update: October 9, 2026
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

    if nargin < 3 || isempty(nE)
        nE = numel(Cout.C)-numel(Cin.C)+1 ;
    end
    if ~(isnumeric(nE) && isreal(nE) && isscalar(nE) && isfinite(nE) && ...
            nE == fix(nE) && nE >= 1 && nE <= numel(Cout.C))
        error('nirp:conv:InvalidLength', ...
            'nE must be a positive integer no larger than the output length.') ;
    end
    if numel(Cout.C) < numel(Cin.C) && nargin < 3
        error('nirp:conv:InvalidLength', ...
            'The default nE is impossible when output is shorter than input.') ;
    end

    v = numel(Cout.C) ;
    firstColumn = [Cin.C zeros(1,max(0,v-numel(Cin.C)))] ;
    firstColumn = firstColumn(1:v).' ;
    matrix = toeplitz(firstColumn,[Cin.C(1) zeros(1,nE-1)])*dtIn ;
    [estimated,resnorm,residual] = lsqnonneg(matrix,Cout.C.') ;
    t0 = Cout.t(1)-Cin.t(1) ;
    E = nirp.conv.signal(t0+(0:nE-1)*dtIn,estimated.') ;

    reconvolved = nirp.conv.convolve(E,Cin) ;
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
        'reconvolved',reconvolved) ;
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
