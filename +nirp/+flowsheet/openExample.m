function modelFile = openExample(name,varargin)
%OPENEXAMPLE Generate a NIRP example in a writable user folder.
%   MODELFILE = nirp.flowsheet.openExample(NAME) generates the model and
%   its data dictionary in NIRP_examples under the first userpath folder.
%   ...openExample(NAME,'Folder',FOLDER,'NoWindow',true) selects a writable
%   destination and replaces existing files without displaying dialogs.
%   The test-only PromptFcn option accepts a function handle that receives
%   the dialog message and returns Restore, Open existing, or Cancel.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 17, 2026
% =========================================================================

    [names,descriptions] = nirp.flowsheet.exampleNames() ;
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
    complete = isfile(modelFile) && isfile(dictionaryFile) ;
    if complete
        description = descriptions(names == name) ;
        answer = existingExampleAction(description,options) ;
        if strcmp(answer,'Cancel') || isempty(answer), modelFile = ''; return; end
        if strcmp(answer,'Open existing')
            loadAndOpen(modelFile,name,options.NoWindow) ;
            return
        end
    end

    addFolder(fullfile(repoRoot,'simulink')) ;
    build_examples(options.Folder,name) ;
    loadAndOpen(modelFile,name,options.NoWindow) ;
end

function answer = existingExampleAction(description,options)
    message = sprintf(['Example "%s" already exists. Restore the original ' ...
        'example (your changes in it will be lost) or open your copy?'],description) ;
    if ~isempty(options.PromptFcn)
        answer = char(string(options.PromptFcn(message))) ;
    elseif options.NoWindow || ~usejava('desktop')
        answer = 'Restore' ;
    else
        answer = questdlg(message,'Open NIRP example', ...
            'Restore','Open existing','Cancel','Open existing') ;
    end
end

function folder = defaultExampleFolder()
    folder = char(userpath) ;
    if contains(folder,pathsep), folder = extractBefore(string(folder),pathsep) ; end
    folder = char(folder) ;
    if isempty(folder), folder = tempdir ; end
    folder = fullfile(folder,'NIRP_examples') ;
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

function options = parseOptions(varargin)
    options = struct('Folder','','NoWindow',false,'PromptFcn',[]) ;
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
            case 'promptfcn'
                value = varargin{i+1} ;
                if ~isa(value,'function_handle')
                    error('nirp:flowsheet:invalidOption', ...
                        'PromptFcn must be a function handle.') ;
                end
                options.PromptFcn = value ;
            otherwise
                error('nirp:flowsheet:invalidOption','Unknown option "%s".',option) ;
        end
    end
end
