function libraryFile = build_tracer_library(folder)
%BUILD_TRACER_LIBRARY Generate the separate NirpTracer block library.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================
    root=fileparts(fileparts(mfilename('fullpath')));addpath(root);if nargin<1||isempty(folder),folder=fileparts(mfilename('fullpath'));end;if ~isfolder(folder),mkdir(folder),end
    name='NirpTracerLibrary';libraryFile=fullfile(folder,[name '.slx']);if bdIsLoaded(name),close_system(name,0),end;if isfile(libraryFile),delete(libraryFile),end
    new_system(name,'Library');cleanup=onCleanup(@()closeLoaded(name));set_param(name,'EnableLBRepository','on');
    labels={'Tracer Flowsheet','Tracer Source','Non-ideal Vessel','Tracer Splitter','Tracer Mixer','Tracer Monitor'};
    classes={'Flowsheet','Source','Vessel','Splitter','Mixer','Monitor'};
    for k=1:numel(classes)
        row=mod(k-1,3);column=floor((k-1)/3);block=[name '/' labels{k}];
        add_block('simulink/User-Defined Functions/MATLAB System',block,'System',['nirp.tracerblocks.' classes{k}], ...
            'Position',[45+column*330 45+row*125 285+column*330 120+row*125], ...
            'BackgroundColor','cyan','ForegroundColor','darkBlue');
        nirp.tracerflowsheet.setupBlock(block);
    end
    note=Simulink.Annotation(name,'NirpTracer: inert tracer signals on one fixed time grid');note.Position=[45 430 570 40];note.FontWeight='bold';note.ForegroundColor='darkBlue';
    set_param(name,'Lock','on');save_system(name,libraryFile);clear cleanup;close_system(name,0);
end
function closeLoaded(name),if bdIsLoaded(name),close_system(name,0),end,end
