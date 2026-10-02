function libraryFile = setup()
%SETUP Make the NIRP Simulink library available in the current session.
%   LIBRARYFILE = nirp.setup() adds the Simulink support folders to the
%   MATLAB path, builds NirpLibrary when necessary during development, and
%   refreshes the Library Browser when it is available. Installed copies
%   use the generated library shipped in the toolbox.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    repoRoot = fileparts(fileparts(mfilename('fullpath'))) ;
    warnAboutMultipleCopies(repoRoot) ;
    simulinkFolder = fullfile(repoRoot,'simulink') ;
    exampleFolder = fullfile(simulinkFolder,'examples') ;
    addFolder(simulinkFolder) ;
    if isfolder(exampleFolder), addFolder(exampleFolder) ; end

    libraryFile = fullfile(simulinkFolder,'NirpLibrary.slx') ;
    developmentCopy = hasGitMetadata(repoRoot) && isWritable(repoRoot) ;
    if developmentCopy && (~isfile(libraryFile) || ...
            isStale(libraryFile,repoRoot,simulinkFolder))
        libraryFile = build_library(simulinkFolder) ;
    elseif ~isfile(libraryFile)
        error('nirp:setup:missingPackagedLibrary', ...
            'The installed NIRP toolbox does not contain simulink/NirpLibrary.slx.') ;
    end

    try
        browser = LibraryBrowser.LibraryBrowser2 ;
        browser.refresh() ;
    catch
        % The browser is unavailable in headless MATLAB and some releases.
    end
end

function tf = hasGitMetadata(folder)
    tf = isfile(fullfile(folder,'.git')) || isfolder(fullfile(folder,'.git')) ;
end

function tf = isWritable(folder)
    [ok,attributes] = fileattrib(folder) ;
    tf = ok && attributes.UserWrite ;
end

function warnAboutMultipleCopies(activeRoot)
    locations = which('NonIdealReactorApp','-all') ;
    if ischar(locations), locations = {locations} ; end
    roots = cellfun(@fileparts,locations,'UniformOutput',false) ;
    roots = unique(roots,'stable') ;
    if numel(roots) > 1
        warning('nirp:setup:multipleCopies', ...
            ['Multiple copies of Non-Ideal Reactor Plus are on the MATLAB path. ' ...
            'The active copy is "%s". Other copies: %s'], ...
            activeRoot,strjoin(setdiff(roots,{activeRoot},'stable'),', ')) ;
    end
end

function addFolder(folder)
    if ~contains([path pathsep],[folder pathsep]), addpath(folder) ; end
end
function tf = isStale(libraryFile,repoRoot,simulinkFolder)
%ISSTALE True when the generated library is older than its sources (Claude, T-108 review).
    sources = [dir(fullfile(simulinkFolder,'build_library.m')) ; ...
        dir(fullfile(repoRoot,'+nirp','+blocks','*.m')) ; ...
        dir(fullfile(repoRoot,'+nirp','+flowsheet','*.m'))] ;
    library = dir(libraryFile) ;
    tf = ~isempty(sources) && any([sources.datenum] > library.datenum) ;
end
