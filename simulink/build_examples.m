function modelFiles = build_examples(folder)
%BUILD_EXAMPLES Generate the four milestone-1 NIRP example flowsheets.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    repoRoot=fileparts(fileparts(mfilename('fullpath'))); addpath(repoRoot);
    if nargin<1||isempty(folder),folder=fullfile(fileparts(mfilename('fullpath')),'examples');end
    if ~isfolder(folder),mkdir(folder);end
    if ~contains([path pathsep],[folder pathsep]),addpath(folder);end
    referencePkg=firstOrderReferencePackage();
    definitions={ ...
        'ex1_cstr_isothermal',referencePkg,@buildEx1; ...
        'ex2_cstr_adiabatic_cooler',referencePkg,@buildEx2; ...
        'ex3_pfr_adiabatic',referencePkg,@buildEx3; ...
        'ex4_problem40b_parallel',nirp.pkg.examples.problem40Gas(),@buildEx4};
    modelFiles=strings(size(definitions,1),1);
    for i=1:size(definitions,1)
        name=definitions{i,1}; pkg=definitions{i,2}; builder=definitions{i,3};
        modelFile=fullfile(folder,[name '.slx']); dictionaryFile=fullfile(folder,[name '.sldd']);
        if bdIsLoaded(name),close_system(name,0);end
        if isfile(modelFile),delete(modelFile);end
        if isfile(dictionaryFile),delete(dictionaryFile);end
        nirp.pkg.writeDictionary(pkg,dictionaryFile); new_system(name); save_system(name,modelFile);
        set_param(name,'DataDictionary',[name '.sldd']); nirp.flowsheet.configure(name);
        addSystem(name,'Flowsheet','nirp.blocks.Flowsheet',[20 20 120 65]);
        builder(name); save_system(name,modelFile); close_system(name,0); modelFiles(i)=string(modelFile);
        Simulink.data.dictionary.closeAll('-discard');
    end
end

function pkg=firstOrderReferencePackage()
    % T-101 base data (k = 0.6 1/min = 0.01 1/s) straight from the template.
    pkg=nirp.pkg.examples.firstOrderLiquid();
    nirp.pkg.validate(pkg);
end

function buildEx1(model)
    addSystem(model,'Feed','nirp.blocks.Feed',[40 120 130 170],'FeedName','F1');
    addSystem(model,'CSTR','nirp.blocks.CSTR',[200 110 320 180],'V','100','VUnit','L','HeatMode','Isothermal');
    addSystem(model,'Product','nirp.blocks.Product',[390 120 500 170], ...
        'ResultName','Product','ReferenceFeed','F1','KeyComponent','A');
    add_line(model,'Feed/1','CSTR/1'); add_line(model,'CSTR/1','Product/1');
end

function buildEx2(model)
    addSystem(model,'Feed','nirp.blocks.Feed',[30 120 120 170],'FeedName','F1');
    addSystem(model,'CSTR','nirp.blocks.CSTR',[180 110 300 180],'V','100','VUnit','L','HeatMode','Adiabatic');
    addSystem(model,'Cooler','nirp.blocks.Heater',[360 110 480 180],'Mode','Outlet T','Tout','300','ToutUnit','K','ShowHeatPort','on');
    addSystem(model,'Product','nirp.blocks.Product',[550 120 660 170],'ResultName','Product','ReferenceFeed','F1','KeyComponent','A');
    add_block('simulink/Sinks/Terminator',[model '/Cooler duty'],'Position',[540 205 560 225]);
    add_line(model,'Feed/1','CSTR/1');add_line(model,'CSTR/1','Cooler/1');add_line(model,'Cooler/1','Product/1');add_line(model,'Cooler/2','Cooler duty/1');
end

function buildEx3(model)
    addSystem(model,'Feed','nirp.blocks.Feed',[40 120 130 170],'FeedName','F1');
    addSystem(model,'PFR','nirp.blocks.PFR',[200 105 330 185],'GeometryMode','Volume','V','0.1','VUnit','m^3','D','0.1','DUnit','m','HeatMode','Adiabatic');
    addSystem(model,'Product','nirp.blocks.Product',[400 120 510 170],'ResultName','Product','ReferenceFeed','F1','KeyComponent','A');
    add_line(model,'Feed/1','PFR/1');add_line(model,'PFR/1','Product/1');
end

function buildEx4(model)
    addSystem(model,'Feed','nirp.blocks.Feed',[30 180 110 230],'FeedName','F1');
    addSystem(model,'Splitter','nirp.blocks.Splitter',[160 165 270 245],'Fractions','[0.5 0.5]');
    addSystem(model,'CSTR 1','nirp.blocks.CSTR',[330 100 450 170],'V','400','VUnit','L','HeatMode','Isothermal');
    addSystem(model,'CSTR 2','nirp.blocks.CSTR',[330 250 450 320],'V','400','VUnit','L','HeatMode','Isothermal');
    addSystem(model,'Mixer','nirp.blocks.Mixer',[510 165 620 245],'NumInputs','2');
    addSystem(model,'Product','nirp.blocks.Product',[680 180 790 230],'ResultName','Product','ReferenceFeed','F1','KeyComponent','A');
    add_line(model,'Feed/1','Splitter/1');add_line(model,'Splitter/1','CSTR 1/1');add_line(model,'Splitter/2','CSTR 2/1');
    add_line(model,'CSTR 1/1','Mixer/1');add_line(model,'CSTR 2/1','Mixer/2');add_line(model,'Mixer/1','Product/1');
end

function addSystem(model,name,className,position,varargin)
    add_block('simulink/User-Defined Functions/MATLAB System',[model '/' name], ...
        'System',className,'Position',position,varargin{:});
end
