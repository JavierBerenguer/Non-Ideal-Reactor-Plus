function libraryFile = build_library(folder)
%BUILD_LIBRARY Generate the NIRP Simulink block library.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    repoRoot=fileparts(fileparts(mfilename('fullpath'))); addpath(repoRoot);
    if nargin<1||isempty(folder),folder=fileparts(mfilename('fullpath'));end
    if ~isfolder(folder),mkdir(folder);end
    name='NirpLibrary'; libraryFile=fullfile(folder,[name '.slx']);
    if bdIsLoaded(name),close_system(name,0);end
    if isfile(libraryFile),delete(libraryFile);end
    new_system(name,'Library');
    cleanup=onCleanup(@() closeLoaded(name));
    classes={'Flowsheet','Feed','Product','CSTR','PFR','Mixer','Splitter','Heater'};
    for i=1:numel(classes)
        row=mod(i-1,4); col=floor((i-1)/4);
        add_block('simulink/User-Defined Functions/MATLAB System',[name '/' classes{i}], ...
            'System',['nirp.blocks.' classes{i}],'Position',[50+col*180 40+row*100 170+col*180 100+row*100]);
    end
    set_param(name,'Lock','on'); save_system(name,libraryFile); clear cleanup; close_system(name,0);
end

function closeLoaded(name),if bdIsLoaded(name),close_system(name,0);end,end
