function pkg = selectReactions(pkg,reactions)
%SELECTREACTIONS Keep only some reactions of a package (T-147).
%   PKG = nirp.pkg.selectReactions(PKG,REACTIONS) returns the package with
%   the reactions listed in REACTIONS (indices into the package, or text
%   such as "1 3"). Empty REACTIONS keeps every reaction. Components,
%   feeds and units do not change, so a reactor can build its ReactionSys
%   from the subset with nirp.pkg.toReactionSys.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 10, 2026. Last update: October 10, 2026
% =========================================================================

    indices = nirp.pkg.reactionIndices(pkg,reactions) ;
    nReactions = size(pkg.reactions.stoich,1) ;
    if isequal(indices,1:nReactions), return, end
    types = lower(string({pkg.reactions.kinetics.type})) ;
    if any(types == "function")
        error('nirp:pkg:invalidReactionSelection', ...
            'Kinetics given as one function cannot be split; use all reactions.') ;
    end
    pkg.reactions.stoich = pkg.reactions.stoich(indices,:) ;
    pkg.reactions.DH.value = pkg.reactions.DH.value(indices) ;
    pkg.reactions.kinetics = pkg.reactions.kinetics(indices) ;
end
