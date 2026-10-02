function [modelFile,dictionaryFile] = new(modelName,pkg,folder,varargin)
%NEW Create and open a configured NIRP flowsheet and data dictionary.
%   [MODELFILE,DICTIONARYFILE] = nirp.flowsheet.new(NAME,PKG,FOLDER).
%   Name-value OpenModel=false creates the files without opening the model.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    parser = inputParser ;
    addParameter(parser,'OpenModel',true) ;
    parse(parser,varargin{:}) ;
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
        nirp.flowsheet.addBlock(name,'Flowsheet',[60 50 180 105],200) ;
        nirp.flowsheet.configure(name) ;
        save_system(name) ;
        if parser.Results.OpenModel, open_system(name) ; end
    catch exception
        if bdIsLoaded(name), close_system(name,0) ; end
        rethrow(exception) ;
    end
end
