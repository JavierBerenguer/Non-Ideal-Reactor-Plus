function opened = openLibraryBlockGuide(block)
%OPENLIBRARYBLOCKGUIDE Open block help instead of editing library templates.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================

    block = getfullname(block) ;
    root = bdroot(block) ;
    opened = strcmp(get_param(root, 'BlockDiagramType'), 'library') ;
    if ~opened
        return
    end

    className = string(get_param(block, 'System')) ;
    switch className
        case "nirp.tracerblocks.Flowsheet"
            anchor = 'flowsheet' ;
        case "nirp.tracerblocks.Source"
            anchor = 'source' ;
        case "nirp.tracerblocks.Vessel"
            anchor = 'vessel' ;
        case "nirp.tracerblocks.Splitter"
            anchor = 'splitter' ;
        case "nirp.tracerblocks.Mixer"
            anchor = 'mixer' ;
        case "nirp.tracerblocks.Monitor"
            anchor = 'monitor' ;
        otherwise
            error('nirp:tracerflowsheet:UnknownLibraryBlock', ...
                'No guide is registered for library block %s.', block) ;
    end
    openNirpGuide(nirp.tracerflowsheet.helpTarget(anchor)) ;
end
