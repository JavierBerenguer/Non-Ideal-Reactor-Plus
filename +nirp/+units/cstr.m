function [out,info] = cstr(params,in,rs)
%CSTR Solve a continuous stirred-tank reactor through the common API.
%   PARAMS uses SI and requires V (m^3). heatMode defaults to Isothermal.
%   Modes Specified T and Specified Q require specifiedT (K) and specifiedQ
%   (W), respectively. Other requires U (W/(m^2*K)), A (m^2), and
%   utilityTin (K); utilityTout (K) is optional. Optional defaults are
%   bypassRatio=0, catalystDensity=1, catalystPorosity=0, and no initial
%   temperature guess. IN is a NIRP stream and RS is a ReactionSys.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 1, 2026
% =========================================================================

    if ~isstruct(params) || ~isscalar(params)
        error('nirp:units:invalidParameter','params must be a scalar struct.') ;
    end
    requireReactionSystem(rs) ;
    nirp.stream.validate(in,rs.nComponents) ;
    if in.status == 0
        out = emptyLike(in,rs.nComponents) ;
        info = baseInfo(0) ;
        return
    end

    reactor = CSTR ;
    reactor.V = parameter(params,'V',[],true) ;
    if ~isnumeric(reactor.V) || ~isscalar(reactor.V) || ...
            ~isfinite(reactor.V) || reactor.V <= 0
        error('nirp:units:invalidParameter','V must be positive in m^3.') ;
    end
    reactor = configureThermalReactor(reactor,params) ;
    feed = nirp.stream.toStream(in) ;

    warningIds = {'CSTR:notConverged','CSTR:initialGuessNotConverged'} ;
    oldStates = cell(size(warningIds)) ;
    for i = 1:numel(warningIds)
        oldStates{i} = warning('query',warningIds{i}) ;
        warning('off',warningIds{i}) ;
    end
    cleanup = onCleanup(@() restoreWarnings(warningIds,oldStates)) ;
    lastwarn('') ;
    [product,reactor] = reactor.compute_output(feed,rs) ;
    [warningMessage,warningId] = lastwarn ;

    out = nirp.stream.fromStream(product) ;
    info = baseInfo(in.status) ;
    info.heatDuty = reactor.heatDuty ;
    if ismember(warningId,warningIds)
        info.warnings = {warningId} ;
        info.message = warningMessage ;
        info.status = -1 ;
    end
    if in.status == -1
        info.status = -1 ;
    end
    out.status = info.status ;
end

function restoreWarnings(ids,states)
%RESTOREWARNINGS Restore warning states changed during silent CSTR solving.
% Javier Berenguer Sabater, October 1, 2026.
    for i = 1:numel(ids)
        warning(states{i}.state,ids{i}) ;
    end
end
