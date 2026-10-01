function idx = componentIndex(pkg,name)
%COMPONENTINDEX Return the one-based index of a named component.
%   IDX = nirp.pkg.componentIndex(PKG,NAME) errors when NAME is unknown.
%   Example: idx = nirp.pkg.componentIndex(pkg,"A").
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 1, 2026
% =========================================================================

    names = nirp.pkg.componentNames(pkg) ;
    if ~(ischar(name) || (isstring(name) && isscalar(name)))
        error('nirp:pkg:invalid','Component name must be scalar text.') ;
    end
    idx = find(names == string(name),1) ;
    if isempty(idx)
        error('nirp:pkg:invalid','Unknown component "%s". Valid names: %s.', ...
            char(string(name)),strjoin(cellstr(names),', ')) ;
    end
end
