function value = boundValidity(RS,keyIndex)
%BOUNDVALIDITY Determine whether micromixing results are guaranteed bounds.
%   VALUE = BOUNDVALIDITY(RS,KEYINDEX) reports guaranteed=true only for one
%   irreversible power-law reaction involving one consumed reactant, with a
%   constant order other than one and without an adsorption denominator.
%   For order > 1 segregation is the upper conversion bound; for 0 < order
%   < 1 maximum mixedness is the upper conversion bound. First-order results
%   coincide and are therefore reported as not forming distinct bounds.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 25, 2026. Last update: October 25, 2026
% =========================================================================

    if nargin < 2, keyIndex = [] ; end
    value = result(false,NaN,'none','Unclassified reaction system.') ;
    if ~isa(RS,'ReactionSys')
        value.reason = 'RS must be a ReactionSys object.' ;
        return
    end
    if RS.nReactions ~= 1
        value.reason = 'Guaranteed bounds require exactly one reaction.' ;
        return
    end
    if ~isempty(RS.userDefinedKinetics)
        value.reason = ['User-defined kinetics cannot be certified as a ' ...
            'single irreversible power law.'] ;
        return
    end
    if any(RS.k0_denominator(:) ~= 0)
        value.reason = ['Kinetics with an adsorption denominator do not ' ...
            'have guaranteed micromixing bounds.'] ;
        return
    end
    orders = RS.partialOrders(1,:) ;
    reactants = find(orders > 0) ;
    if numel(reactants) ~= 1
        value.reason = 'Guaranteed bounds require one power-law reactant.' ;
        return
    end
    if ~isempty(keyIndex) && reactants ~= keyIndex
        value.reason = 'The key component is not the single kinetic reactant.' ;
        return
    end
    order = orders(reactants) ;
    value.order = order ;
    tolerance = 100*eps(max(1,abs(order))) ;
    if abs(order-1) <= tolerance
        value.reason = 'First-order segregation and maximum-mixedness results coincide.' ;
        value.direction = 'coincident' ;
        return
    end
    if order <= 0
        value.reason = 'The single-reactant order must be positive.' ;
        return
    end
    value.guaranteed = true ;
    if order > 1
        value.direction = 'segregation-upper' ;
        value.reason = 'Constant single-reactant order above one.' ;
    else
        value.direction = 'maximum-mixedness-upper' ;
        value.reason = 'Constant single-reactant order between zero and one.' ;
    end
end

function value = result(guaranteed,order,direction,reason)
    value = struct('guaranteed',logical(guaranteed),'order',order, ...
        'direction',direction,'reason',reason) ;
end
