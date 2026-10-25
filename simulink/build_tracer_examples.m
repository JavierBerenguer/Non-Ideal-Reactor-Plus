function modelFiles = build_tracer_examples(folder,only)
%BUILD_TRACER_EXAMPLES Generate the non-ideal tracer flowsheet examples.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 25, 2026
% =========================================================================
    root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
    if nargin<1||isempty(folder),folder=fullfile(fileparts(mfilename('fullpath')),'tracer_examples');end
    if ~isfolder(folder),mkdir(folder),end
    definitions={ ...
        'tracer_two_cstr',0.02,40,@buildTwoCstr; ...
        'tracer_pfr_cstr_parallel',0.02,40,@buildParallel; ...
        'tracer_sec01_series',0.05,42,@buildSec01; ...
        'reactive_two_cstr_first_order',0.02,40,@buildReactiveFirstOrder; ...
        'reactive_two_cstr_second_order',0.02,40,@buildReactiveSecondOrder; ...
        'reactive_pfr_cstr_parallel_second_order',0.02,40,@buildReactiveParallel};
    if nargin>=2&&~isempty(only),definitions=definitions(ismember(string(definitions(:,1)),string(only)),:);end
    modelFiles=strings(size(definitions,1),1);
    for i=1:size(definitions,1)
        name=definitions{i,1};dt=definitions{i,2};tFinal=definitions{i,3};builder=definitions{i,4};
        modelFile=fullfile(folder,[name '.slx']);dictionaryFile=fullfile(folder,[name '.sldd']);
        if bdIsLoaded(name),close_system(name,0),end
        if isfile(modelFile),delete(modelFile),end
        if isfile(dictionaryFile),delete(dictionaryFile),end
        nirp.tracerflowsheet.new(name,folder,'Dt',dt,'TFinal',tFinal,'OpenModel',false);
        load_system(modelFile);set_param(name,'StopTime','0');builder(name,dt,tFinal,folder,dictionaryFile);
        save_system(name,modelFile);close_system(name,0);Simulink.data.dictionary.closeAll('-discard');modelFiles(i)=string(modelFile);
    end
end

function buildTwoCstr(model,dt,tFinal,varargin)
addSource(model,'Source',[40 150 165 210],dt,tFinal,1);
addSystem(model,'CSTR 1','nirp.tracerblocks.Vessel',[220 145 350 215],{'Model','CSTR','Tau','2'});
addSystem(model,'CSTR 2','nirp.tracerblocks.Vessel',[405 145 535 215],{'Model','CSTR','Tau','2'});
addSystem(model,'Monitor','nirp.tracerblocks.Monitor',[600 150 730 210],{'ShowViewer','0'});
add_line(model,'Source/1','CSTR 1/1');add_line(model,'CSTR 1/1','CSTR 2/1');add_line(model,'CSTR 2/1','Monitor/1');
end

function buildParallel(model,dt,tFinal,varargin)
addSource(model,'Source',[35 190 160 250],dt,tFinal,1);
addSystem(model,'Splitter','nirp.tracerblocks.Splitter',[205 180 325 260],{'Fractions','0.25'});
addSystem(model,'PFR','nirp.tracerblocks.Vessel',[375 105 500 170],{'Model','PFR','Tau','3'});
addSystem(model,'CSTR','nirp.tracerblocks.Vessel',[375 275 500 340],{'Model','CSTR','Tau','3'});
addSystem(model,'Mixer','nirp.tracerblocks.Mixer',[550 180 675 260],{'NumInputs','2'});
addSystem(model,'Monitor','nirp.tracerblocks.Monitor',[725 190 850 250],{'ShowViewer','0'});
add_line(model,'Source/1','Splitter/1');add_line(model,'Splitter/1','PFR/1');add_line(model,'Splitter/2','CSTR/1');
add_line(model,'PFR/1','Mixer/1');add_line(model,'CSTR/1','Mixer/2');add_line(model,'Mixer/1','Monitor/1');
end

function buildSec01(model,dt,tFinal,varargin)
addSource(model,'Source',[35 150 160 210],dt,tFinal,1);
t=0:dt:tFinal;e1=zeros(size(t));selected=t>=2&t<=5;e1(selected)=(t(selected)-2)/18;
selected=t>5&t<=8;e1(selected)=1/6;selected=t>8&t<=11;e1(selected)=(11-t(selected))/18;
addSystem(model,'Trapezoidal RTD','nirp.tracerblocks.Vessel',[220 140 375 220], ...
    {'Origin','Data','DataTime',mat2str(t,15),'DataE',mat2str(e1,15)});
addSystem(model,'CSTR tau 2 s','nirp.tracerblocks.Vessel',[430 140 570 220],{'Model','CSTR','Tau','2'});
addSystem(model,'Monitor','nirp.tracerblocks.Monitor',[630 150 755 210],{'ShowViewer','0'});
add_line(model,'Source/1','Trapezoidal RTD/1');add_line(model,'Trapezoidal RTD/1','CSTR tau 2 s/1');add_line(model,'CSTR tau 2 s/1','Monitor/1');
end

function buildReactiveFirstOrder(model,dt,tFinal,folder,dictionaryFile)
configureReaction(model,dt,tFinal,folder,dictionaryFile,1,0.4);
addReactiveSource(model,dt,tFinal);
addSystem(model,'CSTR 1','nirp.tracerblocks.Vessel',[220 145 350 215],{'Model','CSTR','Tau','2'});
addSystem(model,'CSTR 2','nirp.tracerblocks.Vessel',[405 145 535 215],{'Model','CSTR','Tau','2'});
addSystem(model,'Monitor','nirp.tracerblocks.Monitor',[600 150 730 210],{'ShowViewer','0'});
add_line(model,'Source/1','CSTR 1/1');add_line(model,'CSTR 1/1','CSTR 2/1');add_line(model,'CSTR 2/1','Monitor/1');
end

function buildReactiveSecondOrder(model,dt,tFinal,folder,dictionaryFile)
configureReaction(model,dt,tFinal,folder,dictionaryFile,2,0.05);
addReactiveSource(model,dt,tFinal);
addSystem(model,'CSTR 1','nirp.tracerblocks.Vessel',[220 145 350 215],{'Model','CSTR','Tau','2'});
addSystem(model,'CSTR 2','nirp.tracerblocks.Vessel',[405 145 535 215],{'Model','CSTR','Tau','2'});
addSystem(model,'Monitor','nirp.tracerblocks.Monitor',[600 150 730 210],{'ShowViewer','0'});
add_line(model,'Source/1','CSTR 1/1');add_line(model,'CSTR 1/1','CSTR 2/1');add_line(model,'CSTR 2/1','Monitor/1');
end

function buildReactiveParallel(model,dt,tFinal,folder,dictionaryFile)
configureReaction(model,dt,tFinal,folder,dictionaryFile,2,0.05);
addReactiveSource(model,dt,tFinal);
addSystem(model,'Splitter','nirp.tracerblocks.Splitter',[205 180 325 260],{'Fractions','0.25'});
addSystem(model,'PFR','nirp.tracerblocks.Vessel',[375 105 500 170],{'Model','PFR','Tau','3'});
addSystem(model,'CSTR','nirp.tracerblocks.Vessel',[375 275 500 340],{'Model','CSTR','Tau','3'});
addSystem(model,'Mixer','nirp.tracerblocks.Mixer',[550 180 675 260],{'NumInputs','2'});
addSystem(model,'Monitor','nirp.tracerblocks.Monitor',[725 190 850 250],{'ShowViewer','0'});
add_line(model,'Source/1','Splitter/1');add_line(model,'Splitter/1','PFR/1');add_line(model,'Splitter/2','CSTR/1');
add_line(model,'PFR/1','Mixer/1');add_line(model,'CSTR/1','Mixer/2');add_line(model,'Mixer/1','Monitor/1');
end

function configureReaction(model,dt,tFinal,folder,dictionaryFile,order,k)
RS=ReactionSys;RS.componentNames={'A','B'};
if order==1
    RS.stochiometricMatrix=[-1 1];RS.k0=k;RS.Ea=0;
else
    % ReactionSys derives power-law orders from stoichiometry. Scaling the
    % extent coefficient by 1/2 gives the requested -r_A = k*C_A^2 law.
    RS.stochiometricMatrix=[-2 2];RS.k0=k/2;RS.Ea=0;
end
reactionFile=[model '_reaction.mat'];save(fullfile(folder,reactionFile),'RS','-mat');
nirp.tracerflowsheet.writeDictionary(dictionaryFile,nirp.tracer.grid(dt,tFinal),RS.nComponents);
set_param([model '/Tracer Flowsheet'],'Micromixing','Both','ReactionOrigin','File', ...
    'ReactionReference',reactionFile,'KeyComponent','1','Temperature','298.15');
end

function addReactiveSource(model,dt,tFinal)
addSource(model,'Source',[40 150 165 210],dt,tFinal,1);
set_param([model '/Source'],'FeedConcentrations','[10 0]');
end

function addSource(model,name,position,dt,~,id)
addSystem(model,name,'nirp.tracerblocks.Source',position,{'SignalMode','Data','DataTime',mat2str([0 dt 2*dt],15), ...
    'DataConcentration',mat2str([1/dt 0 0],15),'SourceId',num2str(id),'Q','1'});
end
function addSystem(model,name,className,position,parameters)
block=[model '/' name];add_block('simulink/User-Defined Functions/MATLAB System',block,'System',className,'Position',position);
for k=1:2:numel(parameters),set_param(block,parameters{k},parameters{k+1});end
nirp.tracerflowsheet.setupBlock(block);
end
