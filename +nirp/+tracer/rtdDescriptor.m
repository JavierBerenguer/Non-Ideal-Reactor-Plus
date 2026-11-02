function descriptor = rtdDescriptor(spec,Q)
%RTDDESCRIPTOR Build an unnormalised RTD on an automatic uniform grid.
%   D = nirp.tracer.rtdDescriptor(SPEC,Q) accepts model, data, or session
%   origins. Time is in s, E in 1/s, and Q in m^3/s. D.tau is the mean of
%   the original distribution. D.rawArea and D.tailFraction are measured
%   before the downstream RTD class normalises E with trapz quadrature.
%   Automatic grids are capped at 50001 points to bound both memory and
%   the ODE work performed by the micromixing models.
% =========================================================================
% Javier Berenguer Sabater
% Created: November 3, 2026. Last update: November 3, 2026
% =========================================================================

    if nargin < 2, Q = [] ; end
    if ~isstruct(spec) || ~isscalar(spec) || ~isfield(spec,'origin')
        error('nirp:tracer:InvalidRTDDescriptor', ...
            'RTD specification must be a scalar struct with origin.') ;
    end
    origin = lower(strtrim(char(spec.origin))) ;
    switch origin
        case 'model'
            [t,E,tau,tailFraction] = modelDescriptor(spec,Q) ;
            rawArea = trapz(t,E) ;
        case 'data'
            [sourceT,sourceE] = dataValues(spec) ;
            [t,E,tau,rawArea,tailFraction] = dataDescriptor(sourceT,sourceE) ;
        case 'session'
            [sourceT,sourceE] = sessionValues(spec) ;
            [t,E,tau,rawArea,tailFraction] = dataDescriptor(sourceT,sourceE) ;
        otherwise
            error('nirp:tracer:InvalidRTDDescriptor', ...
                'RTD origin must be model, data, or session.') ;
    end
    if ~(isfinite(rawArea) && rawArea > 0)
        error('nirp:tracer:ZeroRTDArea','RTD must have positive finite area.') ;
    end
    descriptor = struct('t',t,'E',E,'tau',tau,'rawArea',rawArea, ...
        'tailFraction',tailFraction,'origin',origin, ...
        'grid',struct('dt',t(2)-t(1),'tFinal',t(end),'n',numel(t))) ;
end

function [t,E,tauMean,tail] = modelDescriptor(spec,Q)
    if ~isfield(spec,'model')
        error('nirp:tracer:InvalidRTDDescriptor','Model origin requires model.') ;
    end
    parameters = spec ;
    if isfield(spec,'parameters')
        if ~isstruct(spec.parameters) || ~isscalar(spec.parameters)
            error('nirp:tracer:InvalidRTDDescriptor','parameters must be a scalar struct.') ;
        end
        names = fieldnames(spec.parameters) ;
        for k = 1:numel(names), parameters.(names{k}) = spec.parameters.(names{k}) ; end
    end
    tau = residenceTime(parameters,Q) ;
    model = lower(strtrim(char(spec.model))) ;
    target = 5e-7 ; % Safety margin below the required 1e-6 lost tail.
    switch model
        case 'cstr'
            dt = tau/1000 ;
            tFinal = -log(target)*tau ;
            tail = exp(-tFinal/tau) ;
            tauMean = tau ;
            raw = @(x) exp(-x/tau)/tau ;
        case 'pfr'
            dt = tau/1000 ;
            tFinal = tau+dt ;
            tail = 0 ; tauMean = tau ; raw = [] ;
        case {'tanks','tanks-in-series','tanks_in_series'}
            n = requiredPositiveInteger(parameters,'N') ;
            sigma = tau/sqrt(n) ;
            dt = min(tau/1000,sigma/50) ;
            tFinal = tau+6*sigma ;
            tail = gammainc(n*tFinal/tau,n,'upper') ;
            while tail > target
                tFinal = tFinal+2*sigma ;
                tail = gammainc(n*tFinal/tau,n,'upper') ;
            end
            tauMean = tau ; tauTank = tau/n ;
            raw = @(x) exp((n-1).*log(max(x,realmin))-x/tauTank ...
                -gammaln(n)-n*log(tauTank)) ;
        case 'dispersion'
            pe = requiredPositive(parameters,'Pe') ;
            boundary = 'open' ;
            if isfield(parameters,'boundary'), boundary = lower(char(parameters.boundary)); end
            if ismember(boundary,{'open','open-open'})
                sigma = tau*sqrt(2/pe+8/pe^2) ;
                tauMean = tau*(1+2/pe) ;
                dt = min(tau/1000,max(sigma/50,tau/10000)) ;
                tFinal = max(tauMean+8*sigma,2*tau) ;
                raw = @(x) openDispersion(x,tau,pe) ;
                tail = max(0,1-trapz(0:dt:tFinal,raw(0:dt:tFinal))) ;
                while tail > target
                    tFinal = tFinal+2*max(sigma,dt) ;
                    enforcePointLimit(tFinal,dt) ;
                    values = 0:dt:tFinal ;
                    tail = max(0,1-trapz(values,raw(values))) ;
                end
            elseif ismember(boundary,{'closed','closed-closed'})
                sigma = tau*sqrt(2/pe-2/pe^2*(1-exp(-pe))) ;
                tauMean = tau ; dt = min(tau/1000,max(sigma/50,tau/10000)) ;
                tFinal = max(tau+8*sigma,2*tau) ;
                raw = @(x) closedDispersion(x,tau,pe) ;
                values = 0:dt:tFinal ;
                tail = max(0,1-trapz(values,raw(values))) ;
                while tail > target
                    tFinal = tFinal+2*max(sigma,dt) ;
                    enforcePointLimit(tFinal,dt) ;
                    values = 0:dt:tFinal ;
                    tail = max(0,1-trapz(values,raw(values))) ;
                end
            else
                error('nirp:tracer:InvalidBoundary', ...
                    'Dispersion boundary must be open or closed.') ;
            end
        otherwise
            error('nirp:tracer:UnknownModel','Unknown vessel RTD model: %s.',model) ;
    end
    count = ceil(tFinal/dt) ;
    if count+1 > 50001
        error('nirp:tracer:RTDGridTooLarge', ...
            'Automatic RTD grid needs %d points; the safety limit is 50001.',count+1) ;
    end
    t = (0:count)*(tFinal/count) ;
    if strcmp(model,'pfr')
        [~,index] = min(abs(t-tau)) ;
        E = zeros(size(t)) ; E(index) = 1/trapz(t,double((1:numel(t)) == index)) ;
    else
        E = raw(t) ;
        if ismember(model,{'tanks','tanks-in-series','tanks_in_series'}) && n > 1
            E(1) = 0 ;
        end
    end
end

function enforcePointLimit(tFinal,dt)
    points = ceil(tFinal/dt)+1 ;
    if points > 50001
        error('nirp:tracer:RTDGridTooLarge', ...
            ['The RTD tail cannot be reduced below 1e-6 within the ' ...
            '50001-point automatic-grid safety limit.']) ;
    end
end

function values = closedDispersion(t,tau,pe)
    theta = t/tau ; values = zeros(size(t)) ;
    if pe > 500
        [~,index] = min(abs(t-tau)) ;
        values(index) = 1/trapz(t,double((1:numel(t)) == index)) ;
        return
    end
    weights = zeros(1,12) ; halfOrder = 6 ;
    for i = 1:12
        for k = floor((i+1)/2):min(i,halfOrder)
            weights(i) = weights(i)+k^halfOrder*factorial(2*k)/( ...
                factorial(halfOrder-k)*factorial(k)*factorial(k-1)* ...
                factorial(i-k)*factorial(2*k-i)) ;
        end
        weights(i) = (-1)^(halfOrder+i)*weights(i) ;
    end
    for j = find(theta > 0)
        base = log(2)/theta(j) ; value = 0 ;
        for i = 1:12
            s = i*base ; q = sqrt(1+4*s/pe) ;
            numerator = 4*q*exp(pe/2) ;
            denominator = (1+q)^2*exp(q*pe/2) ...
                -(1-q)^2*exp(-q*pe/2) ;
            value = value+weights(i)*numerator/denominator ;
        end
        values(j) = max(0,value*base/tau) ;
    end
end

function values = openDispersion(t,tau,pe)
    theta = t/tau ; values = zeros(size(t)) ; positive = theta > 0 ;
    values(positive) = sqrt(pe)./(tau*sqrt(4*pi*theta(positive))).* ...
        exp(-pe*(1-theta(positive)).^2./(4*theta(positive))) ;
end

function tau = residenceTime(parameters,Q)
    if isfield(parameters,'tau') && ~isempty(parameters.tau) && ...
            isfield(parameters,'V') && ~isempty(parameters.V)
        if ~(isnumeric(Q) && isreal(Q) && isscalar(Q) && isfinite(Q) && Q > 0)
            error('nirp:tracer:InvalidFlow','Positive Q is required when V is specified.') ;
        end
        if abs(parameters.tau-parameters.V/Q)/max(abs(parameters.tau),realmin) > 1e-6
            error('nirp:tracer:InvalidModelParameter', ...
                'Model V and tau are inconsistent.') ;
        end
    end
    if isfield(parameters,'tau') && ~isempty(parameters.tau)
        tau = parameters.tau ;
    elseif isfield(parameters,'V') && ~isempty(parameters.V)
        if ~(isnumeric(Q) && isreal(Q) && isscalar(Q) && isfinite(Q) && Q > 0)
            error('nirp:tracer:InvalidFlow','Positive Q is required when V is specified.') ;
        end
        tau = parameters.V/Q ;
    else
        error('nirp:tracer:MissingResidenceTime','Specify tau or V.') ;
    end
    if ~(isnumeric(tau) && isreal(tau) && isscalar(tau) && isfinite(tau) && tau > 0)
        error('nirp:tracer:InvalidModelParameter','Residence time must be positive.') ;
    end
end

function value = requiredPositive(parameters,name)
    if ~isfield(parameters,name), error('nirp:tracer:InvalidModelParameter','Missing parameter %s.',name); end
    value = parameters.(name) ;
    if ~(isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value) && value > 0)
        error('nirp:tracer:InvalidModelParameter','%s must be positive.',name) ;
    end
end

function value = requiredPositiveInteger(parameters,name)
    value = requiredPositive(parameters,name) ;
    if value ~= fix(value)
        error('nirp:tracer:InvalidModelParameter','%s must be a positive integer.',name) ;
    end
end

function [t,E] = dataValues(spec)
    if ~all(isfield(spec,{'t','E'}))
        error('nirp:tracer:InvalidRTDDescriptor','Data origin requires t and E.') ;
    end
    t = spec.t ; E = spec.E ;
end

function [t,E] = sessionValues(spec)
    if isfield(spec,'file'), filePath = spec.file ;
    elseif isfield(spec,'filePath'), filePath = spec.filePath ;
    elseif isfield(spec,'path'), filePath = spec.path ;
    else, error('nirp:tracer:InvalidSession','Session origin requires file.'); end
    if ~(ischar(filePath) || (isstring(filePath) && isscalar(filePath))) || ~isfile(filePath)
        error('nirp:tracer:InvalidSession','Session file does not exist.') ;
    end
    loaded = load(char(filePath),'sessionData') ;
    if ~isfield(loaded,'sessionData') || ~isfield(loaded.sessionData,'shared') || ...
            ~isfield(loaded.sessionData.shared,'rtd')
        error('nirp:tracer:InvalidSession','Session does not contain a usable RTD.') ;
    end
    value = loaded.sessionData.shared.rtd ;
    if isa(value,'RTD'), t = value.t ; E = value.Et ;
    elseif isstruct(value) && all(isfield(value,{'t','Et'})), t = value.t ; E = value.Et ;
    else, error('nirp:tracer:InvalidSession','Session does not contain a usable RTD.'); end
end

function [gridT,gridE,tau,area,tail] = dataDescriptor(t,E)
    signal = nirp.conv.signal(t,E) ; t = signal.t ; E = signal.C ;
    if any(E < 0)
        error('nirp:tracer:InvalidRTDDescriptor','RTD E values must be nonnegative.') ;
    end
    area = trapz(t,E) ;
    if ~(isfinite(area) && area > 0), error('nirp:tracer:ZeroRTDArea','RTD data have zero area.'); end
    tau = trapz(t,t.*E)/area ;
    tail = max(0,1-area) ;
    differences = diff(t) ; dt = min(differences) ;
    count = ceil(t(end)/dt) ;
    if count+1 > 50001
        error('nirp:tracer:RTDGridTooLarge', ...
            'Automatic RTD grid needs %d points; the safety limit is 50001.',count+1) ;
    end
    gridT = linspace(0,t(end),count+1) ;
    gridE = interp1(t,E,gridT,'linear',0) ;
end
