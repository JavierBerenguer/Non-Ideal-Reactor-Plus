function libraryFile = build_library(folder)
%BUILD_LIBRARY Generate the NIRP Simulink block library.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 9, 2026
% =========================================================================

    repoRoot=fileparts(fileparts(mfilename('fullpath'))); addpath(repoRoot);
    if nargin<1||isempty(folder),folder=fileparts(mfilename('fullpath'));end
    if ~isfolder(folder),mkdir(folder);end
    name='NirpLibrary'; libraryFile=fullfile(folder,[name '.slx']);
    if bdIsLoaded(name),close_system(name,0);end
    if isfile(libraryFile),delete(libraryFile);end
    new_system(name,'Library');
    cleanup=onCleanup(@() closeLoaded(name));
    set_param(name,'EnableLBRepository','on');
    labels={'Stream','CSTR','PFR','Mixer','Splitter','Separator','Heater','Jacket','Recycle','Adjust'};
    classes={'Stream','CSTR','PFR','Mixer','Splitter','Separator','Heater','Jacket','Recycle','Adjust'};
    for i=1:numel(classes)
        row=mod(i-1,3); col=floor((i-1)/3);
        block=[name '/' labels{i}];
        add_block('simulink/User-Defined Functions/MATLAB System',block, ...
            'System',['nirp.blocks.' classes{i}],'Position', ...
            [40+col*320 50+row*115 320+col*320 125+row*115]);
        if strcmp(classes{i},'Stream')
            set_param(block,'Role','Intermediate');nirp.flowsheet.setupStreamBlock(block);
        else
            nirp.flowsheet.setupUnitBlock(block);
        end
    end
    nirp.flowsheet.addBlock(name,'Flowsheet',[680 395 960 470],200);
    [exampleNames,descriptions]=nirp.flowsheet.exampleNames();
    numberOfColumns=ceil(numel(classes)/3);
    exampleX=40+numberOfColumns*320;
    heading=Simulink.Annotation(name,'Examples');heading.Position=[exampleX 30 250 35];
    heading.FontWeight='bold';heading.FontSize=14;
    for i=1:numel(exampleNames)
        note=Simulink.Annotation(name,char(descriptions(i)));
        note.Position=[exampleX 55+i*48 290 34];note.ForegroundColor='blue';
        note.ClickFcn=sprintf('nirp.flowsheet.openExample(''%s'');',exampleNames(i));
        note.UseDisplayTextAsClickCallback=false;
    end
    set_param(name,'Lock','on'); save_system(name,libraryFile); clear cleanup; close_system(name,0);
end

function closeLoaded(name),if bdIsLoaded(name),close_system(name,0);end,end
