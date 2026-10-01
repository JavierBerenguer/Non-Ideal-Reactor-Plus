function out = emptyLike(in,nComp)
%EMPTYLIKE Return an empty stream retaining inlet T, P, and phase.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 1, 2026
% =========================================================================

    out = nirp.stream.empty(nComp,in.T,in.P,in.phase) ;
end
