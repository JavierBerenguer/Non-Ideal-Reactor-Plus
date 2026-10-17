function indices = reactionIndices(pkg,reactions)
%REACTIONINDICES Validate a reaction selection and return sorted indices.
%   INDICES = nirp.pkg.reactionIndices(PKG,REACTIONS) accepts a numeric
%   vector or text such as "[1 3]" (T-147); empty means all reactions.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 10, 2026. Last update: October 10, 2026
% =========================================================================

    nReactions = size(pkg.reactions.stoich,1) ;
    if ischar(reactions) || isstring(reactions)
        text = strtrim(char(strjoin(string(reactions),' '))) ;
        if isempty(text), indices = 1:nReactions ; return, end
        text = strtrim(regexprep(text,'[\[\],;]',' ')) ;
        if isempty(text), indices = 1:nReactions ; return, end
        values = str2double(split(string(text))) ;
        values = values(:)' ;
    else
        values = double(reactions(:)') ;
    end
    if isempty(values), indices = 1:nReactions ; return, end
    if any(~isfinite(values)) || any(values ~= fix(values)) || ...
            any(values < 1) || any(values > nReactions) || numel(unique(values)) ~= numel(values)
        error('nirp:pkg:invalidReactionSelection', ...
            'Reactions must be distinct integers between 1 and %d.',nReactions) ;
    end
    indices = sort(values) ;
end
