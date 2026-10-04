function [next,state] = adjustStep(state,current,errorValue)
%ADJUSTSTEP Select a bounded secant step with a bisection fallback.
%   [NEXT,STATE] = ADJUSTSTEP(STATE,CURRENT,ERRORVALUE) updates the pure
%   iteration state after observing ERRORVALUE at CURRENT and returns the
%   next parameter value. STATE.minimum, STATE.maximum and STATE.damping
%   define the SI parameter interval and the damped-secant factor.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 4, 2026. Last update: October 4, 2026
% =========================================================================

    state = initializeState(state) ;
    validateInputs(state,current,errorValue) ;

    distinctPoints = state.havePrevious && abs(current-state.previous) > ...
        eps(max([abs(current),abs(state.previous),1])) ;
    if state.bracketed
        state = tightenBracket(state,current,errorValue) ;
    elseif distinctPoints && oppositeSigns(state.previousError,errorValue)
        state = setBracket(state,state.previous,state.previousError, ...
            current,errorValue) ;
    end
    if state.bracketed
        midpoint = (state.left+state.right)/2 ;
        if midpoint == state.left || midpoint == state.right
            state = clearBracket(state) ;
        end
    end

    if errorValue == 0
        next = current ;
    elseif ~state.havePrevious
        span = state.maximum-state.minimum ;
        direction = 1 ;
        if current+0.05*span > state.maximum, direction = -1 ; end
        next = current+direction*0.05*span ;
    else
        denominator = errorValue-state.previousError ;
        scale = max([abs(errorValue),abs(state.previousError),1]) ;
        usableSlope = abs(denominator) > eps(scale) ;
        if usableSlope
            secant = current-errorValue*(current-state.previous)/denominator ;
            secant = current+state.damping*(secant-current) ;
        else
            secant = NaN ;
        end

        if state.bracketed
            insufficientReduction = isfinite(state.errorTwoAgo) && ...
                abs(errorValue) > 0.5*abs(state.errorTwoAgo) ;
            inside = isfinite(secant) && secant > state.left && ...
                secant < state.right ;
            if insufficientReduction
                state.slowBracket = state.slowBracket+1 ;
            else
                state.slowBracket = 0 ;
            end
            if state.slowBracket >= 3
                if oppositeSigns(state.leftError,errorValue)
                    next = state.left ;
                else
                    next = state.right ;
                end
                state.slowBracket = 0 ;
            elseif ~inside || insufficientReduction
                next = (state.left+state.right)/2 ;
            else
                next = secant ;
            end
        else
            plateau = ~usableSlope || (isfinite(state.errorTwoAgo) && ...
                abs(errorValue-state.errorTwoAgo) <= eps(scale)) ;
            if plateau
                next = oppositeEndpoint(state,current) ;
            else
                next = secant ;
            end
        end
    end

    next = min(state.maximum,max(state.minimum,next)) ;
    if next == current && errorValue ~= 0 && ~state.bracketed
        next = oppositeEndpoint(state,current) ;
    end
    state.errorTwoAgo = state.previousError ;
    state.previous = current ;
    state.previousError = errorValue ;
    state.havePrevious = true ;
end

function state = initializeState(state)
    required = {'minimum','maximum','damping'} ;
    if ~isstruct(state) || ~isscalar(state) || ...
            ~all(isfield(state,required))
        error('nirp:blocks:invalidAdjustState', ...
            'State must contain minimum, maximum and damping.') ;
    end
    defaults = struct('havePrevious',false,'previous',NaN, ...
        'previousError',NaN,'errorTwoAgo',NaN,'bracketed',false, ...
        'left',NaN,'leftError',NaN,'right',NaN,'rightError',NaN, ...
        'slowBracket',0) ;
    names = fieldnames(defaults) ;
    for i = 1:numel(names)
        if ~isfield(state,names{i}), state.(names{i}) = defaults.(names{i}) ; end
    end
end

function validateInputs(state,current,errorValue)
    values = [state.minimum state.maximum state.damping current errorValue] ;
    if ~isnumeric(values) || ~isreal(values) || any(~isfinite(values)) || ...
            state.minimum >= state.maximum || state.damping <= 0 || ...
            state.damping > 1 || current < state.minimum || ...
            current > state.maximum
        error('nirp:blocks:invalidAdjustState', ...
            'Adjust state and observations must be finite bounded scalars.') ;
    end
end

function tf = oppositeSigns(first,second)
    tf = (first < 0 && second > 0) || (first > 0 && second < 0) ;
end

function state = setBracket(state,first,firstError,second,secondError)
    if first < second
        state.left = first ; state.leftError = firstError ;
        state.right = second ; state.rightError = secondError ;
    else
        state.left = second ; state.leftError = secondError ;
        state.right = first ; state.rightError = firstError ;
    end
    state.bracketed = true ;
    state.slowBracket = 0 ;
end

function state = tightenBracket(state,current,errorValue)
    if current < state.left || current > state.right, return, end
    tolerance = eps(max([abs(current),abs(state.left),abs(state.right),1])) ;
    if errorValue == 0
        state.left = current ; state.leftError = 0 ;
        state.right = current ; state.rightError = 0 ;
    elseif abs(current-state.left) <= tolerance
        state.leftError = errorValue ;
        if ~oppositeSigns(state.leftError,state.rightError)
            state = clearBracket(state) ;
        end
    elseif abs(current-state.right) <= tolerance
        state.rightError = errorValue ;
        if ~oppositeSigns(state.leftError,state.rightError)
            state = clearBracket(state) ;
        end
    elseif oppositeSigns(state.leftError,errorValue)
        state.right = current ; state.rightError = errorValue ;
    elseif oppositeSigns(state.rightError,errorValue)
        state.left = current ; state.leftError = errorValue ;
    end
end

function state = clearBracket(state)
    state.bracketed = false ;
    state.left = NaN ; state.leftError = NaN ;
    state.right = NaN ; state.rightError = NaN ;
    state.slowBracket = 0 ;
    state.havePrevious = false ; state.previous = NaN ;
    state.previousError = NaN ; state.errorTwoAgo = NaN ;
end

function endpoint = oppositeEndpoint(state,current)
    if current-state.minimum <= state.maximum-current
        endpoint = state.maximum ;
    else
        endpoint = state.minimum ;
    end
end
