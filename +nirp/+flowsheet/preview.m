function output = preview(action,model,value)
%PREVIEW Store material streams calculated before a Simulink run.
%   This registry is deliberately separate from nirpResults. Actions are
%   GET, SET and CLEAR; GET returns an empty preview when none is stored.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 15, 2026. Last update: October 15, 2026
% =========================================================================

    persistent models
    if isempty(models)
        models=containers.Map('KeyType','char','ValueType','any');
    end
    action=lower(char(string(action)));
    model=char(string(model));
    output=[];
    switch action
        case 'get'
            if isKey(models,model),output=models(model);else,output=emptyPreview(model);end
        case 'set'
            if nargin<3||~isstruct(value)||~isscalar(value)
                error('nirp:flowsheet:invalidPreview','Preview data must be a scalar struct.');
            end
            models(model)=value;output=value;
        case 'clear'
            if isKey(models,model),remove(models,model);end
        otherwise
            error('nirp:flowsheet:invalidPreview','Unknown preview action "%s".',action);
    end
end

function value=emptyPreview(model)
    value=struct('Model',string(model),'Streams',struct(),'Blocks',struct(), ...
        'Elapsed',0,'Complete',false,'GeneratedAt',NaT);
end
