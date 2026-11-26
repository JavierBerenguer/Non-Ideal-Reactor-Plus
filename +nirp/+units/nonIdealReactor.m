function [out,info] = nonIdealReactor(params,in,rs)
%NONIDEALREACTOR Solve an isothermal liquid reactor from its RTD.
%   [OUT,INFO] = nirp.units.nonIdealReactor(PARAMS,IN,RS) uses SI units.
%   PARAMS requires rtd, micromixing, temperatureMode, and computeHeat.
%   The liquid volumetric flow Q is constant and heatDuty is positive into
%   the reactor. Invalid empty streams preserve the common unit contract.
% =========================================================================
% Javier Berenguer Sabater
% Created: November 3, 2026. Last update: November 3, 2026
% =========================================================================

    if ~isstruct(params) || ~isscalar(params)
        error('nirp:units:invalidParameter','params must be a scalar struct.') ;
    end
    requireReactionSystem(rs) ;
    nirp.stream.validate(in,rs.nComponents) ;
    if in.status == 0
        out = emptyLike(in,rs.nComponents) ; info = resultInfo(0) ; return
    end
    if in.phase == 1
        error('nirp:units:nonIdealGasNotSupported', ...
            'Non-ideal reactors currently support constant-flow liquids only.') ;
    end

    rtdSpec = parameter(params,'rtd',[],true) ;
    mode = lower(strtrim(char(parameter(params,'micromixing',[],true)))) ;
    if ~ismember(mode,{'segregation','maxmixedness'})
        error('nirp:units:invalidParameter', ...
            'micromixing must be segregation or maxmixedness.') ;
    end
    temperatureMode = lower(strtrim(char(parameter( ...
        params,'temperatureMode',[],true)))) ;
    switch temperatureMode
        case 'inlet'
            operatingTemperature = in.T ;
        case 'specified'
            operatingTemperature = parameter(params,'T',[],true) ;
            if ~(isnumeric(operatingTemperature) && isreal(operatingTemperature) && ...
                    isscalar(operatingTemperature) && isfinite(operatingTemperature) && ...
                    operatingTemperature > 0)
                error('nirp:units:invalidParameter','T must be positive in K.') ;
            end
        otherwise
            error('nirp:units:invalidParameter', ...
                'temperatureMode must be inlet or specified.') ;
    end
    computeHeat = parameter(params,'computeHeat',false,false) ;
    if ~(islogical(computeHeat) && isscalar(computeHeat))
        error('nirp:units:invalidParameter','computeHeat must be a logical scalar.') ;
    end
    if computeHeat, requireThermodynamicData(rs) ; end
    keySpecified = isfield(params,'keyIndex') && ~isempty(params.keyIndex) ;
    if keySpecified
        keyIndex = params.keyIndex ;
        if ~(isnumeric(keyIndex) && isreal(keyIndex) && isscalar(keyIndex) && ...
                isfinite(keyIndex) && keyIndex == fix(keyIndex) && ...
                keyIndex >= 1 && keyIndex <= rs.nComponents)
            error('nirp:units:invalidParameter','keyIndex must identify one component.') ;
        end
    else
        keyIndex = find(any(rs.stochiometricMatrix ~= 0,1),1) ;
        if isempty(keyIndex), keyIndex = 1 ; end
    end

    info = resultInfo(in.status) ; info.micromixing = mode ;
    if ~any(in.F)
        out = in ;
        info.warnings = {'Zero feed; reaction calculation was skipped.'} ;
        return
    end

    descriptor = nirp.tracer.rtdDescriptor(rtdSpec,in.Q) ;
    checkSizeConflict(rtdSpec,descriptor.tau,in.Q) ;
    vesselGrid = struct('dt',descriptor.grid.dt, ...
        'tFinal',descriptor.grid.tFinal,'t',descriptor.t, ...
        'length',descriptor.grid.n) ;
    inletConcentration = reshape(in.F/in.Q,1,[]) ;
    try
        result = nirp.tracer.reactiveVessel(vesselGrid,descriptor.E,rs, ...
            inletConcentration,operatingTemperature,keyIndex,'Mode',mode) ;
    catch exception
        out = in ; out.status = -1 ; info.status = -1 ;
        info.message = exception.message ; info.warnings = {exception.identifier} ;
        info.tau = descriptor.tau ; info.V = volumeValue(rtdSpec,descriptor.tau,in.Q) ;
        info.rtdTailFraction = descriptor.tailFraction ; info.grid = descriptor.grid ;
        return
    end
    if strcmp(mode,'segregation'), outletConcentration = result.Cseg ;
    else, outletConcentration = result.Cmm ; end
    outletFlow = max(reshape(outletConcentration,[],1)*in.Q,0) ;
    inert = ~any(rs.stochiometricMatrix ~= 0,1) ;
    outletFlow(inert) = in.F(inert) ;

    out = nirp.stream.create(outletFlow,operatingTemperature,in.P,0,in.Q) ;
    out.status = in.status ;
    info.tau = descriptor.tau ;
    info.V = volumeValue(rtdSpec,descriptor.tau,in.Q) ;
    info.rtdTailFraction = descriptor.tailFraction ;
    info.grid = descriptor.grid ;
    info.warnings = warningMessages(result.diagnostic.warnings) ;
    if ismember(descriptor.origin,{'data','session'}) && ...
            abs(descriptor.rawArea-1) > 1e-3
        info.warnings{end+1} = sprintf( ...
            'The supplied RTD area is %.4g; it was normalized to 1.', ...
            descriptor.rawArea) ;
    end
    if keySpecified && in.F(keyIndex) > 0
        info.conversion = min(1,max(0,1-out.F(keyIndex)/in.F(keyIndex))) ;
    elseif keySpecified
        info.warnings{end+1} = ...
            'Key-component inlet flow is zero; conversion is undefined.' ;
    end
    if computeHeat
        [info.heatDuty,heatWarning] = heatDuty(in,out,rs,operatingTemperature) ;
        if ~isempty(heatWarning), info.warnings{end+1} = heatWarning ; end
    end
end

function info = resultInfo(status)
    info = baseInfo(status) ; info.heatDuty = NaN ; info.tau = NaN ;
    info.V = NaN ; info.micromixing = '' ; info.rtdTailFraction = NaN ;
    info.grid = struct('dt',NaN,'tFinal',NaN,'n',0) ;
    info.conversion = NaN ;
end

function checkSizeConflict(spec,tau,Q)
    if ~isfield(spec,'origin') || strcmpi(char(spec.origin),'model'), return, end
    supplied = [] ;
    if isfield(spec,'tau') && ~isempty(spec.tau), supplied = spec.tau ; end
    if isfield(spec,'V') && ~isempty(spec.V)
        volumeTau = spec.V/Q ;
        if isempty(supplied), supplied = volumeTau ;
        elseif relativeDifference(supplied,volumeTau) > 1e-6
            error('nirp:units:nonIdealSizeConflict', ...
                'Supplied V and tau are mutually inconsistent.') ;
        end
    end
    if ~isempty(supplied) && ~(isnumeric(supplied) && isreal(supplied) && ...
            isscalar(supplied) && isfinite(supplied) && supplied > 0)
        error('nirp:units:invalidParameter', ...
            'RTD size must be a positive finite SI scalar.') ;
    end
    if ~isempty(supplied) && relativeDifference(supplied,tau) > 1e-6
        error('nirp:units:nonIdealSizeConflict', ...
            'Supplied size conflicts with the measured RTD mean.') ;
    end
end

function value = relativeDifference(a,b)
    value = abs(a-b)/max([abs(a),abs(b),realmin]) ;
end

function V = volumeValue(spec,tau,Q)
    if isfield(spec,'origin') && strcmpi(char(spec.origin),'model') && ...
            isfield(spec,'V') && ~isempty(spec.V)
        V = spec.V ;
    else
        V = tau*Q ;
    end
end

function messages = warningMessages(notices)
    ignored = {'nirp:tracer:UnnormalizedRTD','nirp:tracer:TruncatedRTD'} ;
    notices = notices(~ismember({notices.identifier},ignored)) ;
    messages = cell(1,numel(notices)) ;
    for k = 1:numel(notices), messages{k} = notices(k).message ; end
end

function requireThermodynamicData(rs)
    cp = rs.componentCp ;
    hasCp = false ;
    if isstruct(cp) && isfield(cp,'option')
        switch cp.option
            case 'User defined'
                hasCp = isfield(cp,'UserValues') && ...
                    numel(cp.UserValues) == rs.nComponents ;
            case 'Average'
                hasCp = isfield(cp,'Average') && ...
                    numel(cp.Average) == rs.nComponents ;
            case 'Cp = f(T)'
                hasCp = isfield(cp,'Function') && ...
                    numel(cp.Function) == rs.nComponents ;
            case 'Cp = f(T,P)'
                hasCp = isfield(cp,'FunctionWithP') && ...
                    numel(cp.FunctionWithP) == rs.nComponents ;
        end
    end
    hasFormation = numel(rs.componentHeatOfFormation) == rs.nComponents ;
    hasExplicitDH = ~isempty(rs.DHref) && ...
        ~(isempty(rs.componentHeatOfFormation) && all(rs.DHref == 1)) ;
    if ~(hasCp && (hasFormation || hasExplicitDH))
        error('nirp:blocks:noThermodynamics', ...
            ['Non-ideal reactor heat duty needs heat capacities and reaction ' ...
            'enthalpies, but the ReactionSys has no thermodynamic data.']) ;
    end
end

function [duty,message] = heatDuty(in,out,rs,T)
    nu = double(rs.stochiometricMatrix) ;
    singularValues = svd(nu) ;
    % Standard relative numerical-rank tolerance, scaled by matrix size.
    rankTolerance = max(size(nu))*eps(max(singularValues)) ;
    if rank(nu,rankTolerance) < size(nu,1)
        duty = NaN ;
        message = 'Heat duty unavailable: stoichiometric rows are rank deficient.' ;
        return
    end
    deltaFlow = out.F-in.F ;
    extent = pinv(nu.',rankTolerance)*deltaFlow ;
    residual = norm(nu.'*extent-deltaFlow,2) ;
    % 1e-8 relative to the material-flow scale rejects non-stoichiometric
    % changes while remaining above the ODE solvers' accumulated error.
    residualTolerance = 1e-8*max([norm(deltaFlow,2),norm(in.F,2),1]) ;
    if residual > residualTolerance
        duty = NaN ;
        message = 'Heat duty unavailable: outlet flow is inconsistent with stoichiometry.' ;
        return
    end
    sensible = in.F.'*rs.compute_SensibleEnthalpy(in.T,T,in.P).' ;
    reaction = rs.compute_ReactionEnthalpy(T,in.P)*extent ;
    duty = sensible+reaction ; message = '' ;
end
