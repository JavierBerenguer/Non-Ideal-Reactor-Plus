function paintStatus(modelName,varargin)
%PAINTSTATUS Color NIRP blocks according to the latest simulation run.
%   nirp.flowsheet.paintStatus(MODEL,'reset') clears previous run results
%   and restores supported NIRP blocks to a white background.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 9, 2026. Last update: October 9, 2026
% =========================================================================

    model = char(string(modelName)) ;
    if ~bdIsLoaded(model)
        error('nirp:flowsheet:modelNotLoaded','Model "%s" is not loaded.',model) ;
    end
    action = "paint" ;
    if ~isempty(varargin), action = lower(string(varargin{1})) ; end
    if ~isscalar(action) || ~any(action == ["paint","reset"])
        error('nirp:flowsheet:invalidStatusAction', ...
            'Status action must be ''paint'' or ''reset''.') ;
    end

    originalDirty = get_param(model,'Dirty') ;
    cleanup = onCleanup(@() restoreDirty(model,originalDirty)) ; %#ok<NASGU>
    blocks = supportedBlocks(model) ;
    if action == "reset"
        clearRunResults() ;
        for i = 1:numel(blocks)
            set_param(blocks{i},'BackgroundColor','[1 1 1]') ;
        end
        return
    end

    colors = struct('solved','[0.80 0.95 0.80]', ...
        'warning','[1.00 0.95 0.70]','error','[1.00 0.80 0.80]', ...
        'none','[1 1 1]') ;
    for i = 1:numel(blocks)
        status = nirp.flowsheet.blockStatus(blocks{i}) ;
        set_param(blocks{i},'BackgroundColor',colors.(char(status))) ;
    end
end

function blocks = supportedBlocks(model)
    supported = ["nirp.blocks.CSTR","nirp.blocks.PFR","nirp.blocks.Heater", ...
        "nirp.blocks.Jacket","nirp.blocks.Mixer","nirp.blocks.Splitter","nirp.blocks.Separator", ...
        "nirp.blocks.Recycle","nirp.blocks.Adjust","nirp.blocks.Stream"] ;
    candidates = find_system(model,'LookUnderMasks','all','SearchDepth',1, ...
        'BlockType','MATLABSystem') ;
    blocks = cell(0,1) ;
    for i = 1:numel(candidates)
        try
            if any(string(get_param(candidates{i},'System')) == supported)
                blocks{end+1,1} = candidates{i} ; %#ok<AGROW>
            end
        catch
        end
    end
end

function clearRunResults()
    if ~evalin('base','exist(''nirpResults'',''var'')'), return, end
    results = evalin('base','nirpResults') ;
    if ~isstruct(results), results = struct() ; end
    results.Diagnostics = struct() ;
    results.Streams = struct() ;
    if isfield(results,'Flowsheet'), results = rmfield(results,'Flowsheet') ; end
    assignin('base','nirpResults',results) ;
end

function restoreDirty(model,value)
    if bdIsLoaded(model), set_param(model,'Dirty',value) ; end
end
