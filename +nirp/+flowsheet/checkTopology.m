function graph = checkTopology(model)
%CHECKTOPOLOGY Warn when two functional blocks are directly connected.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 9, 2026
% =========================================================================

    graph = nirp.flowsheet.topology(model) ;
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
            {'Volume','Temperature','VolumetricFlow','Area'})) ;
        if category ~= target.Category
            error('nirp:blocks:invalidAdjustParameterUnit', ...
                'Adjust "%s" moves %s (%s) but its parameter unit is %s (%s).', ...
                get_param(adjusts{i},'Name'),target.Label,target.Category,unit,category) ;
        end
    end
end
