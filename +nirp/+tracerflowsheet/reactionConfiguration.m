function value = reactionConfiguration(block)
%REACTIONCONFIGURATION Read and resolve the diagram-wide reaction settings.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 25, 2026. Last update: October 25, 2026
% =========================================================================

    root = bdroot(block) ;
    coordinators = find_system(root,'SearchDepth',1,'BlockType','MATLABSystem', ...
        'System','nirp.tracerblocks.Flowsheet') ;
    if numel(coordinators) ~= 1
        error('nirp:tracerflowsheet:CoordinatorCount', ...
            'A tracer model requires exactly one Tracer Flowsheet block.') ;
    end
    coordinator = coordinators{1} ;
    modeName = get_param(coordinator,'Micromixing') ;
    mode = modeCode(modeName) ;
    value = struct('enabled',mode > 0,'mode',mode,'modeName',modeName, ...
        'RS',[],'componentNames',{{'Component 1'}},'keyIndex',1, ...
        'temperature',298.15,'origin',get_param(coordinator,'ReactionOrigin'), ...
        'reference',get_param(coordinator,'ReactionReference')) ;
    if mode == 0, return, end
    value.RS = nirp.tracerflowsheet.loadReactionSystem( ...
        value.origin,value.reference,root) ;
    value.componentNames = componentNames(value.RS) ;
    value.keyIndex = str2double(get_param(coordinator,'KeyComponent')) ;
    value.temperature = str2double(get_param(coordinator,'Temperature')) ;
    if ~(isfinite(value.keyIndex) && value.keyIndex == fix(value.keyIndex) && ...
            value.keyIndex >= 1 && value.keyIndex <= value.RS.nComponents)
        error('nirp:tracerflowsheet:InvalidKeyComponent', ...
            'Key component must identify one reaction-system component.') ;
    end
    if ~(isfinite(value.temperature) && value.temperature > 0)
        error('nirp:tracerflowsheet:InvalidTemperature', ...
            'Operating temperature must be positive in K.') ;
    end
end

function value = modeCode(name)
    switch lower(strtrim(char(string(name))))
        case 'none', value = uint8(0) ;
        case 'segregation', value = uint8(1) ;
        case {'max mixedness','maximum mixedness'}, value = uint8(2) ;
        case 'both', value = uint8(3) ;
        otherwise
            error('nirp:tracerflowsheet:InvalidMicromixing', ...
                'Micromixing must be None, Segregation, Max mixedness, or Both.') ;
    end
end

function names = componentNames(RS)
    names = cellstr(string(RS.componentNames)) ;
    if numel(names) ~= RS.nComponents || any(strlength(string(names)) == 0)
        names = arrayfun(@(k)sprintf('Component %d',k),1:RS.nComponents, ...
            'UniformOutput',false) ;
    end
end
