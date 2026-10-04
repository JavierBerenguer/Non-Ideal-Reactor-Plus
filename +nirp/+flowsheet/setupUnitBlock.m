function setupUnitBlock(block)
%SETUPUNITBLOCK Install the structured editor callback for a unit block.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================
    block=getfullname(block);className=string(get_param(block,'System'));
    switch className
        case {"nirp.blocks.CSTR","nirp.blocks.PFR"}
            callback='nirp.flowsheet.ReactorDialog.open(gcb);';
        case "nirp.blocks.Heater"
            callback='nirp.flowsheet.HeaterDialog.open(gcb);';
        case "nirp.blocks.Splitter"
            callback='nirp.flowsheet.SplitterDialog.open(gcb);';
        case "nirp.blocks.Mixer"
            callback='nirp.flowsheet.MixerDialog.open(gcb);';
        otherwise
            return
    end
    set_param(block,'OpenFcn',callback);
end
