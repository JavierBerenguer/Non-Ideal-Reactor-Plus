function modelFiles = build_examples(folder)
%BUILD_EXAMPLES Generate the seven milestone-1 NIRP example flowsheets.
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
        'ex4_problem40b_parallel',nirp.pkg.examples.problem40Gas(),@buildEx4; ...
        'ex5_recycle_cstr',referencePkg,@buildEx5; ...
        'ex6_adjust_volume',referencePkg,@buildEx6; ...
        'ex7_problem44c',problem44Package(),@buildEx7};
    modelFiles=strings(size(definitions,1),1);
    for i=1:size(definitions,1)
        name=definitions{i,1}; pkg=definitions{i,2}; builder=definitions{i,3};
        modelFile=fullfile(folder,[name '.slx']); dictionaryFile=fullfile(folder,[name '.sldd']);
        if bdIsLoaded(name),close_system(name,0);end
        if isfile(modelFile),delete(modelFile);end
        if isfile(dictionaryFile),delete(dictionaryFile);end
        nirp.pkg.writeDictionary(pkg,dictionaryFile); new_system(name); save_system(name,modelFile);
        set_param(name,'DataDictionary',[name '.sldd']);
        nirp.flowsheet.addBlock(name,'Flowsheet',[20 20 140 75],200);
        builder(name); nirp.flowsheet.configure(name);
        save_system(name,modelFile); close_system(name,0); modelFiles(i)=string(modelFile);
        Simulink.data.dictionary.closeAll('-discard');
    end
end

function pkg=problem44Package()
    pkg.meta=struct('formatVersion',1,'name',"Problem 44c");
    cpA=struct('type',"constant",'value',15,'unit',"cal/(mol*K)");
    cpC=struct('type',"constant",'value',30,'unit',"cal/(mol*K)");
    pkg.components=struct('name',{"A","B","C"},'Mw',{[],[],[]}, ...
        'cp',{cpA,cpA,cpC},'hf',{[],[],[]});
    pkg.reactions.stoich=[-1 -1 1];
    pkg.reactions.DH=struct('value',-6,'unit',"kcal/mol");
    pkg.reactions.Tref=struct('value',273.15,'unit',"K");
    pkg.reactions.rateUnits=struct('concentration',"mol/L",'time',"s");
    k0=0.01*exp(10000*4.184/(8.314*300.15));
    pkg.reactions.kinetics=struct('type',"powerlaw",'k0',k0, ...
        'Ea',struct('value',10000,'unit',"cal/mol"),'orders',[1 1 0], ...
        'reverse',[],'expression',"");
    pkg.feeds=struct('name',"F1",'phase',"L", ...
        'T',struct('value',27,'unit',"C"),'P',struct('value',1,'unit',"atm"), ...
        'basis',"concentrations",'values',[1 1 0], ...
        'valuesUnit',"mol/L",'Q',struct('value',2,'unit',"L/s"));
    nirp.pkg.validate(pkg);
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

function buildEx5(model)
    addSystem(model,'Feed','nirp.blocks.Feed',[30 160 130 220],'FeedName','F1');
    addSystem(model,'Mixer','nirp.blocks.Mixer',[180 145 310 225],'NumInputs','2');
    addSystem(model,'CSTR','nirp.blocks.CSTR',[370 150 510 220],'V','0.1','VUnit','m^3');
    addSystem(model,'Splitter','nirp.blocks.Splitter',[570 140 700 230],'Fractions','[0.1 0.9]');
    addSystem(model,'Recycle','nirp.blocks.Recycle',[370 300 520 365], ...
        'Method','Wegstein','Orientation','left');
    addSystem(model,'Product','nirp.blocks.Product',[760 150 890 220], ...
        'ResultName','Product','ReferenceFeed','F1','KeyComponent','A');
    add_line(model,'Feed/1','Mixer/1','autorouting','on');
    add_line(model,'Recycle/1','Mixer/2','autorouting','on');
    add_line(model,'Mixer/1','CSTR/1','autorouting','on');
    add_line(model,'CSTR/1','Splitter/1','autorouting','on');
    add_line(model,'Splitter/1','Product/1','autorouting','on');
    add_line(model,'Splitter/2','Recycle/1','autorouting','on');
end

function buildEx6(model)
    addSystem(model,'Feed','nirp.blocks.Feed',[30 150 110 200],'FeedName','F1');
    addSystem(model,'CSTR','nirp.blocks.CSTR',[280 135 410 210], ...
        'VSource','Input port','HeatMode','Isothermal');
    addSystem(model,'Adjust','nirp.blocks.Adjust',[60 280 230 350], ...
        'TargetVariable','Conversion','KeyComponent','A','ReferenceFeed','F1', ...
        'TargetValue','0.8','InitialValue','0.1','MinValue','0.001', ...
        'MaxValue','1','ParameterUnit','m^3');
    addSystem(model,'Product','nirp.blocks.Product',[500 150 610 200], ...
        'ResultName','Product','ReferenceFeed','F1','KeyComponent','A');
    add_line(model,'Feed/1','CSTR/1');add_line(model,'Adjust/1','CSTR/2');
    add_line(model,'CSTR/1','Adjust/1');add_line(model,'CSTR/1','Product/1');
end

function buildEx7(model)
    addSystem(model,'Feed','nirp.blocks.Feed',[30 210 110 260],'FeedName','F1');
    addSystem(model,'CSTR 500 L','nirp.blocks.CSTR',[190 90 330 165], ...
        'V','500','VUnit','L','HeatMode','Adiabatic','InitialTGuess','495','InitialTGuessUnit','K');
    addSystem(model,'CSTR 250 L 1','nirp.blocks.CSTR',[190 300 330 375], ...
        'V','250','VUnit','L','HeatMode','Adiabatic','InitialTGuess','490','InitialTGuessUnit','K');
    addSystem(model,'CSTR 250 L 2','nirp.blocks.CSTR',[400 300 540 375], ...
        'V','250','VUnit','L','HeatMode','Adiabatic','InitialTGuess','499','InitialTGuessUnit','K');
    addSystem(model,'Product500','nirp.blocks.Product',[600 100 720 155], ...
        'ResultName','Product500','ReferenceFeed','F1','KeyComponent','A');
    addSystem(model,'ProductSeries','nirp.blocks.Product',[600 310 720 365], ...
        'ResultName','ProductSeries','ReferenceFeed','F1','KeyComponent','A');
    add_line(model,'Feed/1','CSTR 500 L/1');add_line(model,'CSTR 500 L/1','Product500/1');
    add_line(model,'Feed/1','CSTR 250 L 1/1');add_line(model,'CSTR 250 L 1/1','CSTR 250 L 2/1');
    add_line(model,'CSTR 250 L 2/1','ProductSeries/1');
end

function addSystem(model,name,className,position,varargin)
    minimumWidth=0;
    switch className
        case 'nirp.blocks.Feed',minimumWidth=120;
        case 'nirp.blocks.Product',minimumWidth=140;
        case 'nirp.blocks.Heater',minimumWidth=150;
        case 'nirp.blocks.Recycle',minimumWidth=180;
        case 'nirp.blocks.Adjust',minimumWidth=280;
    end
    position(3)=max(position(3),position(1)+minimumWidth);
    add_block('simulink/User-Defined Functions/MATLAB System',[model '/' name], ...
        'System',className,'Position',position,varargin{:});
end
