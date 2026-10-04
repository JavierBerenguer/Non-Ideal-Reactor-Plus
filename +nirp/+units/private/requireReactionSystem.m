function requireReactionSystem(rs)
%REQUIREREACTIONSYSTEM Validate the common ReactionSys argument.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 1, 2026
% =========================================================================

    if ~isa(rs,'ReactionSys') || ~isscalar(rs) || rs.nComponents < 1
        error('nirp:units:invalidReactionSystem', ...
            'rs must be a scalar ReactionSys with at least one component.') ;
    end
end
