function graph = topology(model)
%TOPOLOGY Return unit-to-stream and stream-to-unit model connectivity.
%   The Inputs and Outputs cell arrays preserve arbitrary Simulink port
%   counts. Empty entries denote unconnected or direct unit connections.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    model = char(string(model)) ;
    if ~bdIsLoaded(model), load_system(model) ; end
    systems = find_system(model,'LookUnderMasks','all','SearchDepth',1, ...
        'BlockType','SubSystem') ;
    matlabSystems = find_system(model,'LookUnderMasks','all','SearchDepth',1, ...
        'BlockType','MATLABSystem') ;
    blocks = unique([systems(:);matlabSystems(:)]) ;
    blocks(strcmp(blocks,model)) = [] ;
    streamPaths = strings(0,1) ; unitPaths = strings(0,1) ;
    unitTypes = strings(0,1) ;
    for i = 1:numel(blocks)
        className = systemClass(blocks{i}) ;
        if className == "nirp.blocks.Stream"
            streamPaths(end+1,1) = string(blocks{i}) ;
        elseif startsWith(className,"nirp.blocks.") && ...
                ~any(className == ["nirp.blocks.Flowsheet","nirp.blocks.Adjust", ...
                "nirp.blocks.Jacket"])
            unitPaths(end+1,1) = string(blocks{i}) ;
            unitTypes(end+1,1) = extractAfter(className,"nirp.blocks.") ;
        end
    end
    graph = struct('Units',struct(),'Streams',struct(),'Order',strings(0,1), ...
        'MissingStreamConnections',struct('From',{},'To',{})) ;
    streamNames = strings(size(streamPaths)) ;
    for i = 1:numel(streamPaths)
        path = char(streamPaths(i)) ; name = string(get_param(path,'Name')) ;
        streamNames(i) = name ; connectivity = get_param(path,'PortConnectivity') ;
        producer = neighborNames(connectivity,'in',unitPaths) ;
        consumer = neighborNames(connectivity,'out',unitPaths) ;
        item = struct('Name',name,'Path',string(path), ...
            'Role',string(get_param(path,'Role')),'Producer',producer, ...
            'Consumer',consumer) ;
        graph.Streams.(matlab.lang.makeValidName(name)) = item ;
    end
    for i = 1:numel(unitPaths)
        path = char(unitPaths(i)) ; name = string(get_param(path,'Name')) ;
        connectivity = get_param(path,'PortConnectivity') ;
        inputs = portStreams(connectivity,'in',streamPaths,streamNames) ;
        outputs = portStreams(connectivity,'out',streamPaths,streamNames) ;
        item = struct('Name',name,'Path',string(path),'Type',unitTypes(i), ...
            'Inputs',{inputs},'Outputs',{outputs}) ;
        graph.Units.(matlab.lang.makeValidName(name)) = item ;
        direct = directUnitConnections(connectivity,path,unitPaths) ;
        graph.MissingStreamConnections = [graph.MissingStreamConnections direct] ;
    end
    graph.Order = processOrder(graph,streamNames) ;
end

function name = systemClass(block)
    name = "" ;
    try
        name = string(get_param(block,'System')) ;
    catch
    end
end

function values = neighborNames(connectivity,direction,unitPaths)
    values = strings(0,1) ;
    for i = 1:numel(connectivity)
        if strcmp(direction,'in'), handles = connectivity(i).SrcBlock ;
        else, handles = connectivity(i).DstBlock ; end
        handles = handles(handles ~= -1) ;
        for h = reshape(handles,1,[])
            path = string(getfullname(h)) ;
            if any(unitPaths == path), values(end+1,1) = string(get_param(h,'Name')) ; end %#ok<AGROW>
        end
    end
end

function values = portStreams(connectivity,direction,streamPaths,streamNames)
    values = cell(1,0) ;
    inputPort = 0 ; outputPort = 0 ;
    for i = 1:numel(connectivity)
        if strcmp(direction,'in')
            if isempty(connectivity(i).SrcBlock), continue, end
            inputPort = inputPort+1 ; port = inputPort ; handles = connectivity(i).SrcBlock ;
        else
            if isempty(connectivity(i).DstBlock), continue, end
            outputPort = outputPort+1 ; port = outputPort ; handles = connectivity(i).DstBlock ;
        end
        if isempty(port) || port < 1, continue, end
        while numel(values) < port, values{end+1} = strings(0,1) ; end %#ok<AGROW>
        for h = reshape(handles(handles ~= -1),1,[])
            index = find(streamPaths == string(getfullname(h)),1) ;
            if ~isempty(index), values{port}(end+1,1) = streamNames(index) ; end
        end
    end
end

function direct = directUnitConnections(connectivity,path,unitPaths)
    direct = struct('From',{},'To',{}) ;
    fromName = string(get_param(path,'Name')) ;
    for i = 1:numel(connectivity)
        handles = connectivity(i).DstBlock ;
        for h = reshape(handles(handles ~= -1),1,[])
            target = string(getfullname(h)) ;
            if any(unitPaths == target)
                direct(end+1) = struct('From',fromName, ...
                    'To',string(get_param(h,'Name'))) ;
            end
        end
    end
end

function order = processOrder(graph,fallback)
    order = strings(0,1) ; remaining = fallback(:) ;
    fields = fieldnames(graph.Streams) ;
    for pass = 1:numel(fields)+1
        changed = false ;
        for i = 1:numel(fields)
            item = graph.Streams.(fields{i}) ;
            if any(order == item.Name), continue, end
            if item.Role == "Feed" || isempty(item.Producer) || ...
                    producerReady(item.Producer,graph,order)
                order(end+1,1) = item.Name ; changed = true ; %#ok<AGROW>
            end
        end
        if ~changed, break, end
    end
    for item = remaining'
        if ~any(order == item), order(end+1,1) = item ; end %#ok<AGROW>
    end
end

function ready = producerReady(producers,graph,order)
    ready = false ; unitFields = fieldnames(graph.Units) ;
    for p = producers'
        index = find(strcmp(cellfun(@(f) char(graph.Units.(f).Name), ...
            unitFields,'UniformOutput',false),char(p)),1) ;
        if isempty(index), continue, end
        inputs = graph.Units.(unitFields{index}).Inputs ;
        names = strings(0,1) ;
        for i = 1:numel(inputs), names = [names; string(inputs{i}(:))] ; end %#ok<AGROW>
        ready = isempty(names) || all(ismember(names,order)) ;
        if ready, return, end
    end
end
