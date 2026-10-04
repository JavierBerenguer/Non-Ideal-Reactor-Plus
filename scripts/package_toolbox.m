function toolboxFile = package_toolbox(outputFolder)
%PACKAGE_TOOLBOX Build the distributable Non-Ideal Reactor Plus toolbox.
%   TOOLBOXFILE = PACKAGE_TOOLBOX(OUTPUTFOLDER) creates a clean staging
%   copy, generates the Simulink library and examples, and packages the
%   application as NonIdealReactorPlus_0.1.0.mltbx.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    arguments
        outputFolder (1,:) char = fullfile(fileparts(fileparts( ...
            mfilename('fullpath'))),'release')
    end
    version = '0.1.0' ;
    repoRoot = fileparts(fileparts(mfilename('fullpath'))) ;
    if ~isfolder(outputFolder), mkdir(outputFolder) ; end
    outputFolder = char(java.io.File(outputFolder).getCanonicalPath()) ;
    stagingRoot = tempname(outputFolder) ;
    mkdir(stagingRoot) ;
    cleanupStaging = onCleanup(@() removeStaging(stagingRoot)) ;

    copyApplication(repoRoot,stagingRoot) ;
    simulinkFolder = fullfile(stagingRoot,'simulink') ;
    oldPath = path ;
    cleanupPath = onCleanup(@() path(oldPath)) ;
    addpath(stagingRoot,'-begin') ;
    addpath(simulinkFolder,'-begin') ;
    clear build_library build_examples
    build_library(simulinkFolder) ;
    build_examples(fullfile(simulinkFolder,'examples')) ;

    toolboxFile = fullfile(outputFolder, ...
        ['NonIdealReactorPlus_' version '.mltbx']) ;
    options = matlab.addons.toolbox.ToolboxOptions(stagingRoot, ...
        '8f50a73a-8ea5-4ab8-a01f-45f4e0966489') ;
    options.ToolboxName = 'Non-Ideal Reactor Plus' ;
    options.ToolboxVersion = version ;
    options.AuthorName = 'Javier Berenguer Sabater' ;
    options.Summary = 'Analysis and simulation of ideal and non-ideal chemical reactors.' ;
    options.Description = ['Non-Ideal Reactor Plus MATLAB app and Simulink library. ' ...
        'Requires MATLAB R2025b, Simulink, and Optimization Toolbox.'] ;
    options.MinimumMatlabRelease = 'R2025b' ;
    options.ToolboxFiles = packageFiles(stagingRoot) ;
    options.ToolboxMatlabPath = {stagingRoot,simulinkFolder} ;
    options.AppGalleryFiles = {fullfile(stagingRoot,'NonIdealReactorApp.m')} ;
    options.OutputFile = toolboxFile ;
    matlab.addons.toolbox.packageToolbox(options) ;
    path(oldPath) ;
    clear cleanupPath
    clear build_library build_examples
    clear cleanupStaging
end

function copyApplication(sourceRoot,destinationRoot)
    entries = dir(sourceRoot) ;
    excludedFolders = {'.git','.local','C__','tests','scripts','release','slprj'} ;
    for i = 1:numel(entries)
        name = entries(i).name ;
        if any(strcmp(name,{'.','..'})) || startsWith(name,'.git')
            continue
        end
        source = fullfile(sourceRoot,name) ;
        destination = fullfile(destinationRoot,name) ;
        if entries(i).isdir
            if any(strcmp(name,excludedFolders)), continue; end
            copyfile(source,destination) ;
        elseif ~isExcludedFile(name)
            copyfile(source,destination) ;
        end
    end
end

function files = packageFiles(root)
    entries = dir(fullfile(root,'**','*')) ;
    entries = entries(~[entries.isdir]) ;
    paths = string(fullfile({entries.folder},{entries.name}))' ;
    relative = erase(paths,string(root)+filesep) ;
    relative = replace(relative,'\','/') ;
    wrapped = "/"+relative+"/" ;
    forbidden = false(size(relative)) ;
    for folder = [".git",".local","C__","tests","scripts","release","slprj"]
        forbidden = forbidden | contains(wrapped,"/"+folder+"/") ;
    end
    excludedExtension = endsWith(relative,[".slxc",".asv"], ...
        'IgnoreCase',true) ;
    hiddenGit = startsWith(relative,'.git') ;
    files = cellstr(paths(~forbidden & ~excludedExtension & ~hiddenGit)) ;
end

function tf = isExcludedFile(name)
    tf = endsWith(name,{'.slxc','.asv'},'IgnoreCase',true) ;
end

function removeStaging(folder)
    if isfolder(folder), rmdir(folder,'s') ; end
end
