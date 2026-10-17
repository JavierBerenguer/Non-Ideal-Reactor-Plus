function opened = openLibraryBlockGuide(block)
%OPENLIBRARYBLOCKGUIDE Open block help instead of editing library templates.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 17, 2026. Last update: October 17, 2026
% =========================================================================

    block = getfullname(block) ;
    root = bdroot(block) ;
    opened = strcmp(get_param(root, 'BlockDiagramType'), 'library') ;
    if ~opened
        return
    end

    if strcmp(block, root)
        guide = 'guides/flowsheet-reactive-system.html' ;
    else
        className = string(get_param(block, 'System')) ;
        switch className
            case "nirp.blocks.Stream"
                guide = 'guides/flowsheet-streams.html#stream' ;
            case "nirp.blocks.CSTR"
                guide = 'guides/flowsheet-reactors.html#cstr' ;
            case "nirp.blocks.PFR"
                guide = 'guides/flowsheet-reactors.html#pfr' ;
            case "nirp.blocks.Jacket"
                guide = 'guides/flowsheet-reactors.html#jacket' ;
            case "nirp.blocks.Mixer"
                guide = 'guides/flowsheet-units.html#mixer' ;
            case "nirp.blocks.Splitter"
                guide = 'guides/flowsheet-units.html#splitter' ;
            case "nirp.blocks.Separator"
                guide = 'guides/flowsheet-units.html#separator' ;
            case "nirp.blocks.Heater"
                guide = 'guides/flowsheet-units.html#heater' ;
            case "nirp.blocks.Recycle"
                guide = 'guides/flowsheet-recycle-adjust.html#recycle' ;
            case "nirp.blocks.Adjust"
                guide = 'guides/flowsheet-recycle-adjust.html#adjust' ;
            otherwise
                error('nirp:flowsheet:UnknownLibraryBlock', ...
                    'No guide is registered for library block %s.', block) ;
        end
    end
    openNirpGuide(guide) ;
end
