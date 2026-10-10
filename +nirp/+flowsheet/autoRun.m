function ran = autoRun(block)
%AUTORUN Simulate the flowsheet after a block dialog is accepted (D-064).
%   RAN = nirp.flowsheet.autoRun(BLOCK) runs the model that contains BLOCK
%   when its Flowsheet block has "Auto-run" ticked (default), no simulation
%   is running and every block input is connected. An incomplete or failing
%   flowsheet is left without results and no error is shown; Run reports it.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 10, 2026. Last update: October 10, 2026
% =========================================================================

    ran = false ;
    if ~usejava('desktop'), return, end
    try
        model = bdroot(char(string(block))) ;
    catch
        return
    end
    if ~enabled(model) || ~strcmp(get_param(model,'SimulationStatus'),'stopped'), return, end
    blocks = find_system(model,'SearchDepth',1,'BlockType','MATLABSystem') ;
    for i = 1:numel(blocks)
        connectivity = get_param(blocks{i},'PortConnectivity') ;
        for j = 1:numel(connectivity)
            if isequal(connectivity(j).SrcBlock,-1), return, end
        end
    end
    try
        simOut = sim(model) ; %#ok<NASGU>
        ran = true ;
    catch
    end
end

function value = enabled(model)
    value = true ;
    flowsheets = find_system(model,'SearchDepth',1,'BlockType','SubSystem','Mask','on') ;
    for i = 1:numel(flowsheets)
        if any(strcmp(get_param(flowsheets{i},'MaskNames'),'AutoRun'))
            value = strcmp(get_param(flowsheets{i},'AutoRun'),'on') ;
            return
        end
    end
end
