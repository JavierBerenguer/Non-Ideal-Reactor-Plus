function graph = checkTopology(model)
%CHECKTOPOLOGY Warn when two functional blocks are directly connected.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    graph = nirp.flowsheet.topology(model) ;
    for i = 1:numel(graph.MissingStreamConnections)
        item = graph.MissingStreamConnections(i) ;
        warning('nirp:flowsheet:missingStream', ...
            'Blocks "%s" and "%s" are directly connected; insert a Stream block.', ...
            item.From,item.To) ;
    end
end
