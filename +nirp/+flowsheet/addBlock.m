function block = addBlock(model,path,position,maxIterations)
%ADDBLOCK Add the masked Flowsheet auto-stop subsystem to a model.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    if nargin < 2 || isempty(path), path = 'Flowsheet' ; end
    if nargin < 3 || isempty(position), position = [20 20 140 75] ; end
    if nargin < 4 || isempty(maxIterations), maxIterations = 200 ; end
    model = char(string(model)) ;
    block = [model '/' char(string(path))] ;
    add_block('simulink/Ports & Subsystems/Subsystem',block, ...
        'Position',position) ;
    delete_line(block,'In1/1','Out1/1') ;
    delete_block([block '/In1']) ;
    delete_block([block '/Out1']) ;
    add_block('simulink/User-Defined Functions/MATLAB System', ...
        [block '/Convergence'],'System','nirp.blocks.Flowsheet', ...
        'Position',[35 25 145 65]) ;
    add_block('simulink/Sinks/Stop Simulation',[block '/Stop'], ...
        'Position',[200 28 230 62]) ;
    add_line(block,'Convergence/1','Stop/1') ;
    mask = Simulink.Mask.create(block) ;
    mask.Description = 'Stops a stationary flowsheet when every Recycle and Adjust has converged.' ;
    mask.addParameter('Type','edit','Name','MaxIterations', ...
        'Prompt','Maximum iterations','Value',num2str(maxIterations)) ;
    mask.addParameter('Type','checkbox','Name','ShowResultsAfterRun', ...
        'Prompt','Show results after simulation','Value','on') ;
    button = mask.addDialogControl('Type','pushbutton','Name','ShowResults') ;
    button.Prompt = 'Show results' ;
    button.Tooltip = 'Display the latest Stream block results.' ;
    button.Callback = 'nirp.flowsheet.showResults(bdroot(gcb));' ;
    editButton = mask.addDialogControl('Type','pushbutton','Name','EditPackage') ;
    editButton.Prompt = 'Edit package...' ;
    editButton.Tooltip = 'Edit components, reactions, and feeds.' ;
    editButton.Callback = 'nirp.flowsheet.PackageEditor.openForModel(bdroot(gcb));' ;
    set_param(block,'MaskDisplay', ...
        "disp(['Flowsheet' newline 'max = ' get_param(gcb,'MaxIterations')])") ;
end
