function value = parameter(params,name,defaultValue,required)
%PARAMETER Read a unit parameter or raise the common missing-parameter error.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 1, 2026
% =========================================================================

    if isfield(params,name) && ~isempty(params.(name))
        value = params.(name) ;
    elseif required
        error('nirp:units:missingParameter', ...
            'Required parameter ''%s'' is missing.',name) ;
    else
        value = defaultValue ;
    end
end
