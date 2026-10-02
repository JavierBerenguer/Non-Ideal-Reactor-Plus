function modelFile = chooseExample()
%CHOOSEEXAMPLE Select and open a NIRP example from a dialog.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    modelFile = '' ;
    if ~usejava('desktop')
        error('nirp:flowsheet:noDesktop', ...
            'The example selector requires MATLAB desktop.') ;
    end
    [names,descriptions] = nirp.flowsheet.exampleNames() ;
    labels = descriptions+" ("+names+")" ;
    [selection,accepted] = listdlg('PromptString','Select an example:', ...
        'SelectionMode','single','ListString',cellstr(labels), ...
        'Name','Open NIRP example') ;
    if accepted
        modelFile = nirp.flowsheet.openExample(names(selection)) ;
    end
end
