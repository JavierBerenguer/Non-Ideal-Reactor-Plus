function modelFile = openExample(name,varargin)
%OPENEXAMPLE Build, load, and optionally display a NIRP example model.
%   MODELFILE = nirp.flowsheet.openExample(NAME) generates the examples
%   when NAME is not present and opens it when MATLAB has a desktop.
%   ...openExample(NAME,'Folder',FOLDER,'NoWindow',true) supports headless
%   callers and tests without changing the example definition.
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
    if isempty(options.Folder)
        repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath')))) ;
        options.Folder = fullfile(repoRoot,'simulink','examples') ;
    end
    if ~isfolder(options.Folder), mkdir(options.Folder) ; end
    if ~contains([path pathsep],[options.Folder pathsep]), addpath(options.Folder) ; end
    modelFile = fullfile(options.Folder,[char(name) '.slx']) ;
    if ~isfile(modelFile)
        simulinkFolder = fullfile(fileparts(fileparts(fileparts( ...
            mfilename('fullpath')))),'simulink') ;
        if ~contains([path pathsep],[simulinkFolder pathsep]), addpath(simulinkFolder) ; end
        build_examples(options.Folder) ;
    end
    load_system(modelFile) ;
    if ~options.NoWindow && usejava('desktop'), open_system(char(name)) ; end
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
