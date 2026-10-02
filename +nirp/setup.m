function libraryFile = setup()
%SETUP Make the NIRP Simulink library available in the current session.
%   LIBRARYFILE = nirp.setup() adds the Simulink support folders to the
%   MATLAB path, builds NirpLibrary when necessary, and refreshes the
%   Library Browser when it is available.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    repoRoot = fileparts(fileparts(mfilename('fullpath'))) ;
    simulinkFolder = fullfile(repoRoot,'simulink') ;
    exampleFolder = fullfile(simulinkFolder,'examples') ;
    if ~isfolder(exampleFolder), mkdir(exampleFolder) ; end
    addFolder(simulinkFolder) ;
    addFolder(exampleFolder) ;

    libraryFile = fullfile(simulinkFolder,'NirpLibrary.slx') ;
    if ~isfile(libraryFile) || isStale(libraryFile,repoRoot,simulinkFolder)
        libraryFile = build_library(simulinkFolder) ;
    end

    try
        browser = LibraryBrowser.LibraryBrowser2 ;
        browser.refresh() ;
    catch
        % The browser is unavailable in headless MATLAB and some releases.
    end
end

function addFolder(folder)
    if ~contains([path pathsep],[folder pathsep]), addpath(folder) ; end
end
function tf = isStale(libraryFile,repoRoot,simulinkFolder)
%ISSTALE True when the generated library is older than its sources (Claude, T-108 review).
    sources = [dir(fullfile(simulinkFolder,'build_library.m')) ; ...
        dir(fullfile(repoRoot,'+nirp','+blocks','*.m'))] ;
    library = dir(libraryFile) ;
    tf = ~isempty(sources) && any([sources.datenum] > library.datenum) ;
end
