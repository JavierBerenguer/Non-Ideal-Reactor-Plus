function out = registry(action,model,key,value)
%REGISTRY Store convergence state for tear and adjust blocks by model.
%   Actions are clear, set, allConverged, count, and list. SET values may
%   be logical scalars or structs containing a logical converged field.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    persistent models
    if isempty(models)
        models = containers.Map('KeyType','char','ValueType','any') ;
    end
    action = char(string(action)) ;
    model = char(string(model)) ;
    out = [] ;
    switch lower(action)
        case 'clear'
            if isKey(models,model), remove(models,model) ; end
        case 'set'
            if nargin < 4
                error('nirp:flowsheet:registry','SET requires key and value.') ;
            end
            key = char(string(key)) ;
            if islogical(value) || isnumeric(value)
                value = struct('converged',logical(value),'status',0) ;
            end
            if ~isstruct(value) || ~isscalar(value) || ...
                    ~isfield(value,'converged') || ~isscalar(value.converged)
                error('nirp:flowsheet:registry', ...
                    'Registry values must contain scalar converged state.') ;
            end
            if ~isfield(value,'status'), value.status = 0 ; end
            if ~isfield(value,'kind'), value.kind = '' ; end
            if ~isfield(value,'iteration'), value.iteration = 0 ; end
            if ~isKey(models,model)
                models(model) = containers.Map('KeyType','char','ValueType','any') ;
            end
            entries = models(model) ;
            entries(key) = value ;
        case 'allconverged'
            if ~isKey(models,model), out = false ; return, end
            entries = models(model) ;
            valuesCell = values(entries) ;
            out = ~isempty(valuesCell) && all(cellfun( ...
                @(item) logical(item.converged),valuesCell)) ;
        case 'count'
            if isKey(models,model), out = models(model).Count ; else, out = 0 ; end
        case 'list'
            if ~isKey(models,model)
                out = struct('key',{},'converged',{},'status',{},'kind',{},'iteration',{},'finalError',{}) ;
                return
            end
            entries = models(model) ;
            keysCell = keys(entries) ;
            out = repmat(struct('key','','converged',false,'status',0,'kind','','iteration',0,'finalError',NaN), ...
                numel(keysCell),1) ;
            for i = 1:numel(keysCell)
                item = entries(keysCell{i}) ;
                out(i).key = keysCell{i} ;
                out(i).converged = logical(item.converged) ;
                out(i).status = item.status ;
                out(i).kind = item.kind ;
                out(i).iteration = item.iteration ;
                if isfield(item,'finalError'), out(i).finalError = item.finalError ; end
            end
        otherwise
            error('nirp:flowsheet:registry','Unknown registry action "%s".',action) ;
    end
end
