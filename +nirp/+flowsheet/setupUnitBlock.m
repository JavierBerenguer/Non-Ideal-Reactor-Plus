function setupUnitBlock(block)
%SETUPUNITBLOCK Install the structured editor callback for a unit block.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 9, 2026
% =========================================================================
    block=getfullname(block);className=string(get_param(block,'System'));
    switch className
        case {"nirp.blocks.CSTR","nirp.blocks.PFR"}
            callback='nirp.flowsheet.ReactorDialog.open(gcb);';
        case "nirp.blocks.Heater"
            callback='nirp.flowsheet.HeaterDialog.open(gcb);';
        case "nirp.blocks.Jacket"
            callback='nirp.flowsheet.JacketDialog.open(gcb);';
        case "nirp.blocks.Adjust"
            callback='nirp.flowsheet.AdjustDialog.open(gcb);';
        case "nirp.blocks.Splitter"
            callback='nirp.flowsheet.SplitterDialog.open(gcb);';
        case "nirp.blocks.Separator"
            callback='nirp.flowsheet.SeparatorDialog.open(gcb);';
        case "nirp.blocks.Recycle"
            callback='nirp.flowsheet.RecycleDialog.open(gcb);';
        case "nirp.blocks.Mixer"
            callback='nirp.flowsheet.MixerDialog.open(gcb);';
        otherwise
            return
    end
    set_param(block,'OpenFcn',callback);
    % Specifications must remain a serialized block parameter for saved
    % models, but it is edited only through the structured dialog.
    try
        mask=Simulink.Mask.get(block);parameter=mask.getParameter('Specifications');
        if ~isempty(parameter)
            parameter.Visible='off';
            % MATLAB System masks are regenerated when a saved model is
            % loaded. Reapply the structured-editor setup so the serialized
            % implementation detail stays hidden after that regeneration.
            set_param(block,'LoadFcn','nirp.flowsheet.setupUnitBlock(gcb);');
        end
    catch
    end
end
