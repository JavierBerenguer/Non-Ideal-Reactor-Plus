function graph = checkTopology(model)
%CHECKTOPOLOGY Warn when two functional blocks are directly connected.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 9, 2026
% =========================================================================

    graph = nirp.flowsheet.topology(model) ;
    rejectNonIdealCycles(graph) ;
    streamFields = fieldnames(graph.Streams) ;
    for i = 1:numel(streamFields)
        item = graph.Streams.(streamFields{i}) ;
        if item.Role == "Unconnected"
            warning('nirp:flowsheet:unconnectedStream', ...
                'Stream "%s" is not connected to a process unit.',item.Name) ;
        end
    end
    for i = 1:numel(graph.MissingStreamConnections)
        item = graph.MissingStreamConnections(i) ;
        warning('nirp:flowsheet:missingStream', ...
            'Blocks "%s" and "%s" are directly connected; insert a Stream block.', ...
            item.From,item.To) ;
    end
    adjusts = find_system(model,'LookUnderMasks','all','SearchDepth',1, ...
        'BlockType','MATLABSystem','System','nirp.blocks.Adjust') ;
    for i = 1:numel(adjusts)
        target = nirp.flowsheet.adjustTarget(adjusts{i}) ;
        if target.Label == "<not connected>", continue, end
        unit = string(get_param(adjusts{i},'ParameterUnit')) ;
        category = string(nirp.blocks.internal.unitCategory(char(unit), ...
            {'Volume','Time','Temperature','VolumetricFlow','Area'})) ;
        if category ~= target.Category
            error('nirp:blocks:invalidAdjustParameterUnit', ...
                'Adjust "%s" moves %s (%s) but its parameter unit is %s (%s).', ...
                get_param(adjusts{i},'Name'),target.Label,target.Category,unit,category) ;
        end
    end
end

function rejectNonIdealCycles(graph)
    unitFields=fieldnames(graph.Units);
    count=numel(unitFields);names=strings(count,1);types=strings(count,1);
    adjacency=false(count);
    for i=1:count
        names(i)=graph.Units.(unitFields{i}).Name;
        types(i)=graph.Units.(unitFields{i}).Type;
    end
    streamFields=fieldnames(graph.Streams);
    for i=1:numel(streamFields)
        stream=graph.Streams.(streamFields{i});
        for producer=reshape(string(stream.Producer),1,[])
            from=find(names==producer,1);
            if isempty(from),continue,end
            for consumer=reshape(string(stream.Consumer),1,[])
                to=find(names==consumer,1);
                if ~isempty(to),adjacency(from,to)=true;end
            end
        end
    end
    for i=1:numel(graph.MissingStreamConnections)
        item=graph.MissingStreamConnections(i);
        from=find(names==string(item.From),1);
        to=find(names==string(item.To),1);
        if ~isempty(from)&&~isempty(to),adjacency(from,to)=true;end
    end
    reactors=find(types=="NonIdealReactor");
    for reactor=reshape(reactors,1,[])
        reachable=adjacency(reactor,:);previous=false(1,count);
        while ~isequal(reachable,previous)
            previous=reachable;
            next=find(reachable);
            for node=reshape(next,1,[]),reachable=reachable|adjacency(node,:);end
        end
        if reachable(reactor)
            error('nirp:flowsheet:nonIdealReactorCycle', ...
                ['Material recycle cycles through Non-ideal Reactor "%s" are not ' ...
                'supported. Move the Recycle to another branch or remove this cycle.'], ...
                names(reactor));
        end
    end
end
