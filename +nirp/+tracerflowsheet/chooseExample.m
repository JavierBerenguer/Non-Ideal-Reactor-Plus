function modelFile = chooseExample()
%CHOOSEEXAMPLE Select and open a tracer flowsheet example.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================
    if ~usejava('desktop'),error('nirp:tracerflowsheet:noDesktop','The example selector requires MATLAB desktop.');end
    [names,descriptions]=nirp.tracerflowsheet.exampleNames();
    [selection,accepted]=listdlg('PromptString','Select a tracer example:','SelectionMode','single', ...
        'ListString',cellstr(descriptions+" ("+names+")"),'Name','Open tracer example','ListSize',[520 180]);
    if accepted,modelFile=nirp.tracerflowsheet.openExample(names(selection));else,modelFile='';end
end
