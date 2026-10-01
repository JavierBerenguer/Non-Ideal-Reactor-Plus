function [modelFile,dictionaryFile] = new(modelName,pkg,folder)
%NEW Create and open a configured NIRP flowsheet and data dictionary.
%   [MODELFILE,DICTIONARYFILE] = nirp.flowsheet.new(NAME,PKG,FOLDER).
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    if nargin < 3 || isempty(folder), folder = pwd ; end
    folder = char(string(folder)) ;
    if ~isfolder(folder), mkdir(folder) ; end
    if ~contains([path pathsep],[folder pathsep]), addpath(folder) ; end
    name = char(string(modelName)) ;
    if ~isvarname(name)
        error('nirp:flowsheet:invalidName','modelName must be a valid MATLAB identifier.') ;
    end
    modelFile = fullfile(folder,[name '.slx']) ;
    dictionaryFile = fullfile(folder,[name '.sldd']) ;
    if isfile(modelFile) || isfile(dictionaryFile)
        error('nirp:flowsheet:fileExists','The model or dictionary already exists for "%s".',name) ;
    end
    nirp.pkg.writeDictionary(pkg,dictionaryFile) ;
    new_system(name) ;
    try
        save_system(name,modelFile) ;
        set_param(name,'DataDictionary',[name '.sldd']) ;
        nirp.flowsheet.configure(name) ;
        add_block('simulink/User-Defined Functions/MATLAB System', ...
            [name '/Flowsheet'],'System','nirp.blocks.Flowsheet', ...
            'Position',[60 50 170 100]) ;
        save_system(name) ;
        open_system(name) ;
    catch exception
        if bdIsLoaded(name), close_system(name,0) ; end
        rethrow(exception) ;
    end
end
