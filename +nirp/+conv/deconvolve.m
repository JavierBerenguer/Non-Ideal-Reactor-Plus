function [E,info] = deconvolve(Cin,Cout,support,regularization)
%DECONVOLVE Estimate a nonnegative RTD signal by regularized least squares.
%   CIN and COUT use seconds and must have a common uniform DT. SUPPORT is
%   either [TAUMIN TAUMAX] in seconds or the legacy scalar number of RTD
%   samples. When omitted, the legacy complete-convolution length is used.
%   CIN is zero outside its stated interval. The estimated E is not
%   normalized.
%
%   REGULARIZATION is an optional structure with fields:
%     lambda       nonnegative scalar or 'auto' (default: 0)
%     smoothing    'second difference' (default) or 'identity'
%     lambdaRange  positive two-element multiplier range (default: [1e-6 1e2])
%     lambdaCount  number of L-curve samples, at least 3 (default: 40)
%   Automatic lambda values are lambdaRange*norm(A,2). The L-curve corner
%   is the interior sample with maximum positive discrete log-log
%   curvature. Concave active-set bends are not L-curve corners.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 9, 2026. Last update: October 25, 2026
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

    if nargin < 4 || isempty(regularization)
        regularization = struct() ;
    end
    options = regularizationOptions(regularization) ;

    sampleTimes = Cout.t(:)-tau ;
    matrix = interp1(Cin.t,Cin.C,sampleTimes,'linear',0)*dtIn ;
    L = regularizationMatrix(nE,options.smoothing) ;
    lCurve = struct('lambda',[],'residualNorm',[],'seminorm',[], ...
        'curvature',[],'selectedIndex',[]) ;
    selectedAutomatically = ischar(options.lambda) ;
    if selectedAutomatically
        scale = norm(matrix,2) ;
        if scale == 0, scale = 1 ; end
        lambdas = logspace(log10(options.lambdaRange(1)*scale), ...
            log10(options.lambdaRange(2)*scale),options.lambdaCount) ;
        residualNorms = zeros(size(lambdas)) ;
        seminorms = zeros(size(lambdas)) ;
        estimates = cell(size(lambdas)) ;
        for k = 1:numel(lambdas)
            estimates{k} = solveRegularized(matrix,Cout.C.',L,lambdas(k)) ;
            residualNorms(k) = norm(matrix*estimates{k}-Cout.C.') ;
            seminorms(k) = norm(L*estimates{k}) ;
        end
        curvature = lCurveCurvature(residualNorms,seminorms) ;
        [~,selectedIndex] = max(curvature(2:end-1)) ;
        selectedIndex = selectedIndex+1 ;
        lambda = lambdas(selectedIndex) ;
        estimated = estimates{selectedIndex} ;
        lCurve = struct('lambda',lambdas,'residualNorm',residualNorms, ...
            'seminorm',seminorms,'curvature',curvature, ...
            'selectedIndex',selectedIndex) ;
    else
        lambda = options.lambda ;
        estimated = solveRegularized(matrix,Cout.C.',L,lambda) ;
    end
    residual = Cout.C.'-matrix*estimated ;
    resnorm = residual.'*residual ;
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
        'underdetermined',nE > numel(Cout.C), ...
        'lambda',lambda,'lambdaSelectedAutomatically',selectedAutomatically, ...
        'smoothing',options.smoothing,'regularizationMatrix',L, ...
        'lCurve',lCurve) ;
end

function options = regularizationOptions(value)
    if ~isstruct(value) || ~isscalar(value)
        error('nirp:conv:InvalidRegularization', ...
            'Regularization options must be a scalar structure.') ;
    end
    options = struct('lambda',0,'smoothing','second difference', ...
        'lambdaRange',[1e-6 1e2],'lambdaCount',40) ;
    names = fieldnames(value) ;
    allowed = fieldnames(options) ;
    if any(~ismember(names,allowed))
        error('nirp:conv:InvalidRegularization', ...
            'Unknown regularization option: %s.',names{find(~ismember(names,allowed),1)}) ;
    end
    for k = 1:numel(names), options.(names{k}) = value.(names{k}) ; end
    if isstring(options.lambda) && isscalar(options.lambda)
        options.lambda = char(options.lambda) ;
    end
    if ischar(options.lambda)
        if ~strcmpi(strtrim(options.lambda),'auto')
            error('nirp:conv:InvalidLambda','Lambda must be nonnegative or ''auto''.') ;
        end
        options.lambda = 'auto' ;
    elseif ~(isnumeric(options.lambda) && isreal(options.lambda) && ...
            isscalar(options.lambda) && isfinite(options.lambda) && options.lambda >= 0)
        error('nirp:conv:InvalidLambda','Lambda must be nonnegative or ''auto''.') ;
    else
        options.lambda = double(options.lambda) ;
    end
    options.smoothing = lower(strtrim(char(string(options.smoothing)))) ;
    if ~ismember(options.smoothing,{'second difference','identity'})
        error('nirp:conv:InvalidSmoothing', ...
            'Smoothing must be ''second difference'' or ''identity''.') ;
    end
    if ~(isnumeric(options.lambdaRange) && isreal(options.lambdaRange) && ...
            numel(options.lambdaRange) == 2 && all(isfinite(options.lambdaRange)) && ...
            all(options.lambdaRange > 0) && options.lambdaRange(2) > options.lambdaRange(1))
        error('nirp:conv:InvalidLambdaRange', ...
            'lambdaRange must contain two increasing positive multipliers.') ;
    end
    options.lambdaRange = double(options.lambdaRange(:).') ;
    if ~(isnumeric(options.lambdaCount) && isreal(options.lambdaCount) && ...
            isscalar(options.lambdaCount) && isfinite(options.lambdaCount) && ...
            options.lambdaCount == fix(options.lambdaCount) && options.lambdaCount >= 3)
        error('nirp:conv:InvalidLambdaCount','lambdaCount must be an integer of at least 3.') ;
    end
    options.lambdaCount = double(options.lambdaCount) ;
end

function L = regularizationMatrix(n,smoothing)
    if strcmp(smoothing,'identity')
        L = eye(n) ;
    else
        L = diff(eye(n),2,1) ;
    end
end

function estimate = solveRegularized(A,b,L,lambda)
    if lambda == 0
        estimate = lsqnonneg(A,b) ;
    else
        estimate = lsqnonneg([A; lambda*L],[b; zeros(size(L,1),1)]) ;
    end
end

function curvature = lCurveCurvature(residualNorms,seminorms)
    x = log(max(residualNorms,realmin('double'))) ;
    y = log(max(seminorms,realmin('double'))) ;
    xRange = max(x)-min(x) ;
    yRange = max(y)-min(y) ;
    if xRange > 0, x = (x-min(x))/xRange ; end
    if yRange > 0, y = (y-min(y))/yRange ; end
    curvature = zeros(size(x)) ;
    segmentFloor = 0.01*hypot(double(xRange > 0),double(yRange > 0)) ;
    for k = 2:numel(x)-1
        first = [x(k)-x(k-1), y(k)-y(k-1)] ;
        second = [x(k+1)-x(k), y(k+1)-y(k)] ;
        chord = [x(k+1)-x(k-1), y(k+1)-y(k-1)] ;
        denominator = norm(first)*norm(second)*norm(chord) ;
        % A wide logarithmic sweep can contain an initial plateau where
        % adjacent NNLS solutions differ only by roundoff. Its formal
        % three-point curvature is large but it is not an L-curve corner.
        if denominator > 0 && norm(first) >= segmentFloor && ...
                norm(second) >= segmentFloor
            % As lambda increases, a convex L-curve corner turns from a
            % falling segment towards a rightward segment and therefore
            % has positive orientation. Negative values are concave NNLS
            % active-set bends and must not compete with the corner.
            curvature(k) = 2*(first(1)*second(2)-first(2)*second(1)) / denominator ;
        end
    end
    if ~any(curvature(2:end-1) > 0)
        % Exact data can have no convex corner. Prefer the least regularized
        % interior sample instead of imposing an arbitrary mid-sweep bias.
        curvature(2) = eps ;
    end
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
