function [out,info] = cstr(params,in,rs)
%CSTR Solve a continuous stirred-tank reactor through the common API.
%   PARAMS uses SI and requires V (m^3). For a failed solve without an
%   explicit initialTemperatureGuess, progressively warmer guesses are
%   tried at 10 K intervals. Failure is returned as status -1, never as an
%   invalid stream exception.
%   Degrees of freedom: with inlet stream and reaction system fixed, V is
%   one size specification and the selected thermal mode supplies the
%   energy equation/specification. Bypass and catalyst data are additional
%   specified parameters; every supported mode has zero remaining DOF.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 3, 2026
% =========================================================================

    if ~isstruct(params) || ~isscalar(params)
        error('nirp:units:invalidParameter','params must be a scalar struct.') ;
    end
    requireReactionSystem(rs) ;
    nirp.stream.validate(in,rs.nComponents) ;
    if in.status == 0
        out = emptyLike(in,rs.nComponents) ; info = baseInfo(0) ; return
    end

    reactor = CSTR ;
    reactor.V = parameter(params,'V',[],true) ;
    if ~isnumeric(reactor.V) || ~isscalar(reactor.V) || ...
            ~isfinite(reactor.V) || reactor.V <= 0
        error('nirp:units:invalidParameter','V must be positive in m^3.') ;
    end
    reactor = configureThermalReactor(reactor,params) ;
    explicitGuess = isfield(params,'initialTemperatureGuess') && ...
        ~isempty(params.initialTemperatureGuess) ;
    feed = nirp.stream.toStream(in) ;
    warningIds = {'CSTR:notConverged','CSTR:initialGuessNotConverged'} ;
    failureWarningIds = {'CSTR:notConverged'} ; % T-118: an auxiliary-guess warning does not invalidate a converged final solve.
    oldStates = cell(size(warningIds)) ;
    for i = 1:numel(warningIds)
        oldStates{i} = warning('query',warningIds{i}) ;
        warning('off',warningIds{i}) ;
    end
    cleanup = onCleanup(@() restoreWarnings(warningIds,oldStates)) ; %#ok<NASGU>

    guesses = reactor.initialTemperatureGuess ;
    if ~explicitGuess
        maximumTemperature = in.T+estimatedAdiabaticRise(in,rs)+100 ;
        finalGuess = in.T+10*ceil((maximumTemperature-in.T)/10) ;
        guesses = [NaN, (in.T+10):10:finalGuess] ;
    end
    lastMessage = '' ; lastWarnings = {} ; lastProduct = [] ; lastReactor = reactor ;
    for i = 1:numel(guesses)
        trial = reactor ;
        if isnan(guesses(i)), trial.initialTemperatureGuess = [] ;
        else, trial.initialTemperatureGuess = guesses(i) ; end
        lastwarn('') ;
        try
            [product,trial] = trial.compute_output(feed,rs) ;
            [warningMessage,warningId] = lastwarn ;
            converged = ~ismember(warningId,failureWarningIds) ;
            [valid,product] = validProduct(product,in) ;
            lastProduct = product ; lastReactor = trial ;
            if ~isempty(warningId) && ismember(warningId,failureWarningIds)
                lastWarnings = {warningId} ; lastMessage = warningMessage ;
            elseif ~valid
                lastWarnings = {'CSTR:invalidProduct'} ;
                lastMessage = 'CSTR returned a physically invalid product stream.' ;
            end
            if converged && valid
                out = nirp.stream.fromStream(product) ;
                info = baseInfo(in.status) ; info.heatDuty = trial.heatDuty ;
                if in.status == -1, info.status = -1 ; out.status = -1 ; end
                return
            end
        catch exception
            lastMessage = exception.message ;
            lastWarnings = {exception.identifier} ;
        end
        if explicitGuess, break, end
    end

    out = sanitizedFailure(lastProduct,in) ;
    info = baseInfo(-1) ; info.heatDuty = lastReactor.heatDuty ;
    info.warnings = lastWarnings ;
    if isempty(lastMessage)
        lastMessage = 'CSTR did not converge to a physically valid state.' ;
    end
    info.message = lastMessage ; out.status = -1 ;
end

function rise = estimatedAdiabaticRise(in,rs)
%ESTIMATEDADIABATICRISE Conservative heat-release temperature bound (K).
    rise = 0 ;
    try
        cp = rs.compute_HeatCapacity(in.T,in.P) ;
        capacity = sum(in.F(:)'.*cp) ;
        if ~isfinite(capacity) || capacity <= 0, return, end
        stoich = rs.stochiometricMatrix ; dh = rs.DHref ;
        heat = 0 ;
        for reaction = 1:size(stoich,1)
            reactants = find(stoich(reaction,:) < 0) ;
            if isempty(reactants), continue, end
            extent = min(in.F(reactants)'./(-stoich(reaction,reactants))) ;
            heat = heat+max(0,-dh(reaction))*max(0,extent) ;
        end
        rise = max(0,heat/capacity) ;
        if ~isfinite(rise), rise = 0 ; end
    catch
        rise = 0 ;
    end
end

function [valid,product] = validProduct(product,in)
%VALIDPRODUCT Accept only finite positive-temperature, nonnegative-flow states.
    valid = isa(product,'Stream') && isfinite(product.T) && product.T > 0 && ...
        isfinite(product.P) && product.P > 0 && ...
        all(isfinite(product.molarFlow(:))) ;
    if ~valid, return, end
    scale = max([max(abs(in.F)),max(abs(product.molarFlow(:))),1]) ;
    tolerance = 1e-12*scale ;
    valid = all(product.molarFlow(:) >= -tolerance) ;
    if valid, product.molarFlow(product.molarFlow < 0) = 0 ; end
end

function out = sanitizedFailure(product,in)
%SANITIZEDFAILURE Return a valid warning stream, falling back to the feed.
    out = in ;
    if isempty(product), return, end
    [valid,product] = validProduct(product,in) ;
    if ~valid, return, end
    try
        out = nirp.stream.fromStream(product) ;
    catch
        out = in ;
    end
end

function restoreWarnings(ids,states)
%RESTOREWARNINGS Restore warning states changed during silent CSTR solving.
    for i = 1:numel(ids), warning(states{i}.state,ids{i}) ; end
end
