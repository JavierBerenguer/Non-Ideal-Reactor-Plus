function [modelFile,dictionaryFile] = newFromTemplate()
%NEWFROMTEMPLATE Create a flowsheet using the first-order liquid template.
%   This provisional dialog is replaced by the package editor in T-109.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    modelFile = '' ; dictionaryFile = '' ;
    if ~usejava('desktop')
        error('nirp:flowsheet:noDesktop', ...
            'Creating a flowsheet interactively requires MATLAB desktop.') ;
    end
    answer = inputdlg('Model name:','New NIRP flowsheet',1,{'nirp_flowsheet'}) ;
    if isempty(answer), return, end
    folder = uigetdir(pwd,'Select a folder for the flowsheet') ;
    if isequal(folder,0), return, end
    [modelFile,dictionaryFile] = nirp.flowsheet.new( ...
        strtrim(answer{1}),nirp.pkg.examples.firstOrderLiquid(),folder) ;
end
