function modelFile = openExample(name,varargin)
%OPENEXAMPLE Copy a packaged NIRP example to a writable user folder.
%   MODELFILE = nirp.flowsheet.openExample(NAME) copies the model and its
%   data dictionary to NIRP_examples under the first userpath folder.
%   ...openExample(NAME,'Folder',FOLDER,'NoWindow',true) selects a writable
%   destination and replaces existing files without displaying dialogs.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    [names,~] = nirp.flowsheet.exampleNames() ;
    name = string(name) ;
    if ~isscalar(name) || ~any(name == names)
        error('nirp:flowsheet:unknownExample', ...
            'Unknown example "%s". Valid examples: %s.', ...
            char(name),strjoin(cellstr(names),', ')) ;
    end
    options = parseOptions(varargin{:}) ;
    repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath')))) ;
    if isempty(options.Folder), options.Folder = defaultExampleFolder() ; end
    if ~isfolder(options.Folder), mkdir(options.Folder) ; end
    modelFile = fullfile(options.Folder,[char(name) '.slx']) ;
    dictionaryFile = fullfile(options.Folder,[char(name) '.sldd']) ;
    replace = options.NoWindow || ~usejava('desktop') ;
    if isfile(modelFile) || isfile(dictionaryFile)
        if ~replace
            answer = questdlg(sprintf(['Example "%s" already exists in:\n%s\n\n' ...
                'Replace it or open the existing copy?'],name,options.Folder), ...
                'Open NIRP example','Replace','Open existing','Cancel','Open existing') ;
            if strcmp(answer,'Cancel') || isempty(answer), modelFile = ''; return; end
            replace = strcmp(answer,'Replace') ;
        end
        if ~replace
            loadAndOpen(modelFile,name,options.NoWindow) ;
            return
        end
    end

    [sourceFolder,cleanup] = exampleSourceFolder(repoRoot) ; %#ok<ASGLU>
    sourceModel = fullfile(sourceFolder,[char(name) '.slx']) ;
    sourceDictionary = fullfile(sourceFolder,[char(name) '.sldd']) ;
    copyfile(sourceModel,modelFile,'f') ;
    copyfile(sourceDictionary,dictionaryFile,'f') ;
    addFolder(options.Folder) ;
    loadAndOpen(modelFile,name,options.NoWindow) ;
end

function folder = defaultExampleFolder()
    folder = char(userpath) ;
    if contains(folder,pathsep), folder = extractBefore(string(folder),pathsep) ; end
    folder = char(folder) ;
    if isempty(folder), folder = tempdir ; end
    folder = fullfile(folder,'NIRP_examples') ;
end

function [folder,cleanup] = exampleSourceFolder(repoRoot)
    folder = fullfile(repoRoot,'simulink','examples') ;
    cleanup = [] ;
    [names,~] = nirp.flowsheet.exampleNames() ;
    complete = all(arrayfun(@(name) isfile(fullfile(folder,name+".slx")) && ...
        isfile(fullfile(folder,name+".sldd")),names)) ;
    if complete, return; end

    folder = tempname ;
    mkdir(folder) ;
    cleanup = onCleanup(@() removeTemporaryFolder(folder)) ;
    simulinkFolder = fullfile(repoRoot,'simulink') ;
    addFolder(simulinkFolder) ;
    build_examples(folder) ;
end

function loadAndOpen(modelFile,name,noWindow)
    prioritizeFolder(fileparts(modelFile)) ;
    load_system(modelFile) ;
    if ~noWindow && usejava('desktop'), open_system(char(name)) ; end
end

function prioritizeFolder(folder)
    if contains([path pathsep],[folder pathsep]), rmpath(folder) ; end
    addpath(folder,'-begin') ;
end

function addFolder(folder)
    if ~contains([path pathsep],[folder pathsep]), addpath(folder) ; end
end

function removeTemporaryFolder(folder)
    if contains([path pathsep],[folder pathsep]), rmpath(folder) ; end
    if isfolder(folder), rmdir(folder,'s') ; end
end

function options = parseOptions(varargin)
    options = struct('Folder','','NoWindow',false) ;
    if mod(numel(varargin),2) ~= 0
        error('nirp:flowsheet:invalidOption','Options must be name-value pairs.') ;
    end
    for i = 1:2:numel(varargin)
        option = char(string(varargin{i})) ;
        switch lower(option)
            case 'folder'
                options.Folder = char(string(varargin{i+1})) ;
                if isempty(options.Folder)
                    error('nirp:flowsheet:invalidOption','Folder must not be empty.') ;
                end
            case 'nowindow'
                value = varargin{i+1} ;
                if ~isscalar(value) || (~islogical(value) && ~isnumeric(value))
                    error('nirp:flowsheet:invalidOption','NoWindow must be scalar logical.') ;
                end
                options.NoWindow = logical(value) ;
            otherwise
                error('nirp:flowsheet:invalidOption','Unknown option "%s".',option) ;
        end
    end
end
