function requireSpecifications(type,block,names)
%REQUIRESPECIFICATIONS Raise a uniform incomplete-block diagnostic.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================
    names=string(names);names=names(strlength(names)>0);n=numel(names);
    if n==0,return,end
    suffix='s';if n==1,suffix='';end
    error('nirp:blocks:missingSpecifications','%s "%s": %d specification%s missing: %s', ...
        char(string(type)),char(string(block)),n,suffix,strjoin(names,', '));
end
