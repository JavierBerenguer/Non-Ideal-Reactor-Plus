function configure(modelName)
%CONFIGURE Apply the stationary milestone-1 solver configuration.
%   nirp.flowsheet.configure(MODELNAME) sets one discrete sample at t=0.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 9, 2026
% =========================================================================

    model = char(string(modelName)) ;
    [~,base,extension] = fileparts(model) ;
    if ~isempty(extension)
        load_system(model) ;
        model = base ;
    elseif ~bdIsLoaded(model)
        load_system(model) ;
    end
    streams = find_system(model,'SearchDepth',1,'BlockType','MATLABSystem', ...
        'System','nirp.blocks.Stream') ;
    for i = 1:numel(streams)
        nirp.flowsheet.setupStreamBlock(streams{i}) ;
        nirp.flowsheet.streamRole(streams{i}) ;
    end
    units=find_system(model,'SearchDepth',1,'BlockType','MATLABSystem') ;
    for i=1:numel(units),nirp.flowsheet.setupUnitBlock(units{i});end
    iterative = [find_system(model,'LookUnderMasks','all','FollowLinks','on', ...
        'System','nirp.blocks.Recycle'); ...
        find_system(model,'LookUnderMasks','all','FollowLinks','on', ...
        'System','nirp.blocks.Adjust')] ;
    flowsheets = find_system(model,'SearchDepth',1,'BlockType','SubSystem') ;
    maxIterations = 200 ;
    for i = 1:numel(flowsheets)
        if strcmp(get_param(flowsheets{i},'Mask'),'on') && ...
                any(strcmp(get_param(flowsheets{i},'MaskNames'),'MaxIterations'))
            value = str2double(get_param(flowsheets{i},'MaxIterations')) ;
            if isfinite(value) && value >= 1 && value == fix(value)
                maxIterations = value ;
            else
                error('nirp:flowsheet:invalidMaxIterations', ...
                    'MaxIterations must be a positive integer.') ;
            end
            break
        end
    end
    if isempty(iterative), stopTime = 0 ; else, stopTime = maxIterations ; end
    set_param(model,'SolverType','Fixed-step','Solver','FixedStepDiscrete', ...
        'FixedStep','1','StopTime',num2str(stopTime), ...
        'InitFcn',sprintf(['nirp.flowsheet.registry(''clear'',''%s'');' ...
        'nirp.flowsheet.paintStatus(''%s'',''reset'');' ...
        'nirp.flowsheet.checkTopology(''%s'');'],model,model,model), ...
        'StopFcn',sprintf(['nirp.flowsheet.finish(''%s'');' ...
        'nirp.flowsheet.paintStatus(''%s'');' ...
        'nirp.flowsheet.showResultsAfterRun(''%s'');'],model,model,model)) ;
    nirp.flowsheet.checkTopology(model) ;
end
