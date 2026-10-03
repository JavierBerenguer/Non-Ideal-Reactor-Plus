function modelFiles = build_examples(folder)
%BUILD_EXAMPLES Generate the twenty milestone-1 NIRP example flowsheets.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 3, 2026
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
        'ex7_problem44c',nirp.pkg.examples.problem44Liquid(),@buildEx7; ...
        'ex8_problem37a_series',nirp.pkg.examples.problem37Liquid(),@buildEx8; ...
        'ex9_problem40a_series',nirp.pkg.examples.problem40Gas(),@buildEx9; ...
        'ex10_problem42_cstr_pfr',nirp.pkg.examples.problem42SecondOrder(),@buildEx10; ...
        'ex11_problem42_pfr_cstr',nirp.pkg.examples.problem42SecondOrder(),@buildEx11; ...
        'ex12_problem19_adiabatic_pfr',nirp.pkg.examples.problem19Gas(),@buildEx12; ...
        'ex13_problem21a_isothermal_pfr',nirp.pkg.examples.problem21Gas(),@buildEx13; ...
        'ex14_problem21b_adiabatic_pfr',nirp.pkg.examples.problem21Gas(),@buildEx14; ...
        'ex15_problem27_jacketed_cstr',nirp.pkg.examples.problem27Jacketed(),@buildEx15; ...
        'ex16_problem30_adiabatic_cstr',nirp.pkg.examples.problem30Liquid(),@buildEx16; ...
        'ex17_problem31_cooled_cstr',nirp.pkg.examples.problem30Liquid(),@buildEx17; ...
        'ex18_problem44a_volumes',nirp.pkg.examples.problem44Liquid(),@buildEx18; ...
        'ex19_problem45a_three_cstrs',nirp.pkg.examples.problem45Liquid(),@buildEx19; ...
        'ex20_problem45b_feed_temperature',nirp.pkg.examples.problem45Liquid(),@buildEx20};
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

function pkg=firstOrderReferencePackage()
    % T-101 base data (k = 0.6 1/min = 0.01 1/s) straight from the template.
    pkg=nirp.pkg.examples.firstOrderLiquid();
    nirp.pkg.validate(pkg);
end

function buildEx1(model)
    addSystem(model,'F1','nirp.blocks.Stream',[40 120 160 170],'Role','Feed');
    addSystem(model,'CSTR','nirp.blocks.CSTR',[200 110 320 180],'V','100','VUnit','L','HeatMode','Isothermal');
    addSystem(model,'Product','nirp.blocks.Stream',[390 120 520 170], ...
        'Role','Product','ReferenceFeed','F1','KeyComponent','A');
    add_line(model,'F1/1','CSTR/1'); add_line(model,'CSTR/1','Product/1');
end

function buildEx2(model)
    addSystem(model,'F1','nirp.blocks.Stream',[20 120 130 170],'Role','Feed');
    addSystem(model,'CSTR','nirp.blocks.CSTR',[180 110 300 180],'V','100','VUnit','L','HeatMode','Adiabatic');
    addSystem(model,'CSTR outlet','nirp.blocks.Stream',[340 120 460 170],'Role','Intermediate');
    addSystem(model,'Cooler','nirp.blocks.Heater',[510 110 630 180],'Mode','Outlet T','Tout','300','ToutUnit','K','ShowHeatPort','on');
    addSystem(model,'Product','nirp.blocks.Stream',[690 120 810 170],'Role','Product','ReferenceFeed','F1','KeyComponent','A');
    add_block('simulink/Sinks/Terminator',[model '/Cooler duty'],'Position',[680 205 700 225]);
    add_line(model,'F1/1','CSTR/1');add_line(model,'CSTR/1','CSTR outlet/1');add_line(model,'CSTR outlet/1','Cooler/1');add_line(model,'Cooler/1','Product/1');add_line(model,'Cooler/2','Cooler duty/1');
end

function buildEx3(model)
    addSystem(model,'F1','nirp.blocks.Stream',[40 120 160 170],'Role','Feed');
    addSystem(model,'PFR','nirp.blocks.PFR',[200 105 330 185],'GeometryMode','Volume','V','0.1','VUnit','m^3','D','0.1','DUnit','m','HeatMode','Adiabatic');
    addSystem(model,'Product','nirp.blocks.Stream',[400 120 530 170],'Role','Product','ReferenceFeed','F1','KeyComponent','A');
    add_line(model,'F1/1','PFR/1');add_line(model,'PFR/1','Product/1');
end

function buildEx4(model)
    addSystem(model,'F1','nirp.blocks.Stream',[20 180 130 230],'Role','Feed');
    addSystem(model,'Splitter','nirp.blocks.Splitter',[160 165 270 245],'Fractions','[0.5 0.5]');
    addSystem(model,'Branch 1','nirp.blocks.Stream',[310 90 420 140],'Role','Intermediate');
    addSystem(model,'Branch 2','nirp.blocks.Stream',[310 275 420 325],'Role','Intermediate');
    addSystem(model,'CSTR 1','nirp.blocks.CSTR',[460 80 580 150],'V','400','VUnit','L','HeatMode','Isothermal');
    addSystem(model,'CSTR 2','nirp.blocks.CSTR',[460 265 580 335],'V','400','VUnit','L','HeatMode','Isothermal');
    addSystem(model,'CSTR 1 outlet','nirp.blocks.Stream',[620 90 750 140],'Role','Intermediate');
    addSystem(model,'CSTR 2 outlet','nirp.blocks.Stream',[620 275 750 325],'Role','Intermediate');
    addSystem(model,'Mixer','nirp.blocks.Mixer',[790 165 900 245],'NumInputs','2');
    addSystem(model,'Product','nirp.blocks.Stream',[950 180 1070 230],'Role','Product','ReferenceFeed','F1','KeyComponent','A');
    add_line(model,'F1/1','Splitter/1');add_line(model,'Splitter/1','Branch 1/1');add_line(model,'Splitter/2','Branch 2/1');
    add_line(model,'Branch 1/1','CSTR 1/1');add_line(model,'Branch 2/1','CSTR 2/1');
    add_line(model,'CSTR 1/1','CSTR 1 outlet/1');add_line(model,'CSTR 2/1','CSTR 2 outlet/1');
    add_line(model,'CSTR 1 outlet/1','Mixer/1');add_line(model,'CSTR 2 outlet/1','Mixer/2');add_line(model,'Mixer/1','Product/1');
end

function buildEx5(model)
    addSystem(model,'F1','nirp.blocks.Stream',[20 160 130 215],'Role','Feed');
    addSystem(model,'Mixer','nirp.blocks.Mixer',[180 145 310 225],'NumInputs','2');
    addSystem(model,'Mixer outlet','nirp.blocks.Stream',[350 160 470 215],'Role','Intermediate');
    addSystem(model,'CSTR','nirp.blocks.CSTR',[510 150 640 220],'V','0.1','VUnit','m^3');
    addSystem(model,'CSTR outlet','nirp.blocks.Stream',[680 160 800 215],'Role','Intermediate');
    addSystem(model,'Splitter','nirp.blocks.Splitter',[840 140 970 230],'Fractions','[0.1 0.9]');
    addSystem(model,'Recycle feed','nirp.blocks.Stream',[790 300 920 355],'Role','Intermediate','Orientation','left');
    addSystem(model,'Recycle','nirp.blocks.Recycle',[570 300 720 365], ...
        'Method','Wegstein','Orientation','left');
    addSystem(model,'Recycle outlet','nirp.blocks.Stream',[350 300 490 355],'Role','Intermediate','Orientation','left');
    addSystem(model,'Product','nirp.blocks.Stream',[1020 150 1150 220], ...
        'Role','Product','ReferenceFeed','F1','KeyComponent','A');
    add_line(model,'F1/1','Mixer/1','autorouting','on');
    add_line(model,'Recycle outlet/1','Mixer/2','autorouting','on');
    add_line(model,'Mixer/1','Mixer outlet/1','autorouting','on');
    add_line(model,'Mixer outlet/1','CSTR/1','autorouting','on');
    add_line(model,'CSTR/1','CSTR outlet/1','autorouting','on');
    add_line(model,'CSTR outlet/1','Splitter/1','autorouting','on');
    add_line(model,'Splitter/1','Product/1','autorouting','on');
    add_line(model,'Splitter/2','Recycle feed/1','autorouting','on');
    add_line(model,'Recycle feed/1','Recycle/1','autorouting','on');
    add_line(model,'Recycle/1','Recycle outlet/1','autorouting','on');
end

function buildEx6(model)
    addSystem(model,'F1','nirp.blocks.Stream',[30 150 140 200],'Role','Feed');
    addSystem(model,'CSTR','nirp.blocks.CSTR',[280 135 410 210], ...
        'VSource','Input port','HeatMode','Isothermal');
    addSystem(model,'Adjust','nirp.blocks.Adjust',[60 280 230 350], ...
        'TargetVariable','Conversion','KeyComponent','A','ReferenceFeed','F1', ...
        'TargetValue','0.8','InitialValue','0.1','MinValue','0.001', ...
        'MaxValue','1','ParameterUnit','m^3');
    addSystem(model,'Product','nirp.blocks.Stream',[500 150 630 200], ...
        'Role','Product','ReferenceFeed','F1','KeyComponent','A');
    add_line(model,'F1/1','CSTR/1');add_line(model,'Adjust/1','CSTR/2');
    add_line(model,'CSTR/1','Adjust/1');add_line(model,'CSTR/1','Product/1');
end

function buildEx7(model)
    addSystem(model,'F1','nirp.blocks.Stream',[20 210 130 260],'Role','Feed');
    addSystem(model,'CSTR 500 L','nirp.blocks.CSTR',[190 90 330 165], ...
        'V','500','VUnit','L','HeatMode','Adiabatic','InitialTGuess','495','InitialTGuessUnit','K');
    addSystem(model,'CSTR 250 L 1','nirp.blocks.CSTR',[190 300 330 375], ...
        'V','250','VUnit','L','HeatMode','Adiabatic','InitialTGuess','490','InitialTGuessUnit','K');
    addSystem(model,'CSTR 250 L 2','nirp.blocks.CSTR',[400 300 540 375], ...
        'V','250','VUnit','L','HeatMode','Adiabatic','InitialTGuess','499','InitialTGuessUnit','K');
    addSystem(model,'Product500','nirp.blocks.Stream',[650 100 780 155], ...
        'Role','Product','ReferenceFeed','F1','KeyComponent','A');
    addSystem(model,'Series intermediate','nirp.blocks.Stream',[370 300 520 355],'Role','Intermediate');
    addSystem(model,'ProductSeries','nirp.blocks.Stream',[650 310 790 365], ...
        'Role','Product','ReferenceFeed','F1','KeyComponent','A');
    add_line(model,'F1/1','CSTR 500 L/1');add_line(model,'CSTR 500 L/1','Product500/1');
    add_line(model,'F1/1','CSTR 250 L 1/1');add_line(model,'CSTR 250 L 1/1','Series intermediate/1');
    add_line(model,'Series intermediate/1','CSTR 250 L 2/1');
    add_line(model,'CSTR 250 L 2/1','ProductSeries/1');
end

function buildEx8(model)
    addSystem(model,'Feed A','nirp.blocks.Stream',[20 90 140 140],'Role','Feed');
    addSystem(model,'Feed B','nirp.blocks.Stream',[20 230 140 280],'Role','Feed');
    addSystem(model,'Mixer','nirp.blocks.Mixer',[190 135 310 225],'NumInputs','2');
    addSystem(model,'Mixed feed','nirp.blocks.Stream',[350 155 480 205],'Role','Intermediate');
    addSystem(model,'CSTR 1','nirp.blocks.CSTR',[520 145 640 215], ...
        'V','200','VUnit','L','HeatMode','Isothermal');
    addSystem(model,'CSTR 1 outlet','nirp.blocks.Stream',[680 155 820 205],'Role','Intermediate');
    addSystem(model,'CSTR 2','nirp.blocks.CSTR',[860 145 980 215], ...
        'V','200','VUnit','L','HeatMode','Isothermal');
    addSystem(model,'Product','nirp.blocks.Stream',[1020 155 1150 205], ...
        'Role','Product','ReferenceFeed','Feed A','KeyComponent','A');
    add_line(model,'Feed A/1','Mixer/1');add_line(model,'Feed B/1','Mixer/2');
    add_line(model,'Mixer/1','Mixed feed/1');add_line(model,'Mixed feed/1','CSTR 1/1');
    add_line(model,'CSTR 1/1','CSTR 1 outlet/1');add_line(model,'CSTR 1 outlet/1','CSTR 2/1');
    add_line(model,'CSTR 2/1','Product/1');
end

function buildEx9(model)
    addSystem(model,'F1','nirp.blocks.Stream',[30 120 150 170],'Role','Feed');
    addSystem(model,'CSTR 1','nirp.blocks.CSTR',[200 110 320 180], ...
        'V','400','VUnit','L','HeatMode','Isothermal');
    addSystem(model,'CSTR 1 outlet','nirp.blocks.Stream',[360 120 500 170],'Role','Intermediate');
    addSystem(model,'CSTR 2','nirp.blocks.CSTR',[540 110 660 180], ...
        'V','400','VUnit','L','HeatMode','Isothermal');
    addSystem(model,'Product','nirp.blocks.Stream',[710 120 840 170], ...
        'Role','Product','ReferenceFeed','F1','KeyComponent','A');
    add_line(model,'F1/1','CSTR 1/1');add_line(model,'CSTR 1/1','CSTR 1 outlet/1');
    add_line(model,'CSTR 1 outlet/1','CSTR 2/1');add_line(model,'CSTR 2/1','Product/1');
end

function buildEx10(model)
    buildProblem42Train(model,'CSTR','PFR');
end

function buildEx11(model)
    buildProblem42Train(model,'PFR','CSTR');
end

function buildProblem42Train(model,firstType,secondType)
    addSystem(model,'F1','nirp.blocks.Stream',[30 120 150 170],'Role','Feed');
    addProblem42Reactor(model,[firstType ' 1'],firstType,[200 105 330 185]);
    addSystem(model,'Intermediate','nirp.blocks.Stream',[370 120 500 170],'Role','Intermediate');
    addProblem42Reactor(model,[secondType ' 2'],secondType,[540 105 670 185]);
    addSystem(model,'Product','nirp.blocks.Stream',[720 120 850 170], ...
        'Role','Product','ReferenceFeed','F1','KeyComponent','A');
    add_line(model,'F1/1',[firstType ' 1/1']);
    add_line(model,[firstType ' 1/1'],'Intermediate/1');
    add_line(model,'Intermediate/1',[secondType ' 2/1']);
    add_line(model,[secondType ' 2/1'],'Product/1');
end

function addProblem42Reactor(model,name,type,position)
    if strcmp(type,'PFR')
        addSystem(model,name,'nirp.blocks.PFR',position,'GeometryMode','Volume', ...
            'V','1','VUnit','m^3','D','0.1','DUnit','m','HeatMode','Isothermal');
    else
        addSystem(model,name,'nirp.blocks.CSTR',position, ...
            'V','1','VUnit','m^3','HeatMode','Isothermal');
    end
end

function buildEx12(model)
    addSystem(model,'F1','nirp.blocks.Stream',[40 120 160 170],'Role','Feed');
    addSystem(model,'PFR','nirp.blocks.PFR',[210 105 350 185], ...
        'GeometryMode','Volume','V','1.5','VUnit','m^3','D','0.1', ...
        'DUnit','m','HeatMode','Adiabatic');
    addSystem(model,'Product','nirp.blocks.Stream',[400 120 540 170], ...
        'Role','Product','ReferenceFeed','F1','KeyComponent','A');
    add_line(model,'F1/1','PFR/1');add_line(model,'PFR/1','Product/1');
end

function buildEx13(model)
    buildProblem21(model,'Isothermal',380,330,450) ;
end

function buildEx14(model)
    buildProblem21(model,'Adiabatic',430,380,520) ;
end

function buildProblem21(model,heatMode,initialValue,minimum,maximum)
    addSystem(model,'F1','nirp.blocks.Stream',[250 120 380 170], ...
        'Role','Feed','TSource','Input port') ;
    addSystem(model,'PFR','nirp.blocks.PFR',[440 105 580 185], ...
        'GeometryMode','Volume','V','1000','VUnit','L','D','0.1', ...
        'DUnit','m','HeatMode',heatMode) ;
    addSystem(model,'Adjust','nirp.blocks.Adjust',[20 250 300 320], ...
        'TargetVariable','Conversion','KeyComponent','A','ReferenceFeed','F1', ...
        'TargetValue','0.9','InitialValue',num2str(initialValue), ...
        'MinValue',num2str(minimum),'MaxValue',num2str(maximum), ...
        'ParameterUnit','K','Tolerance','1e-10') ;
    addSystem(model,'Product','nirp.blocks.Stream',[650 120 790 170], ...
        'Role','Product','ReferenceFeed','F1','KeyComponent','A') ;
    add_line(model,'Adjust/1','F1/1') ; add_line(model,'F1/1','PFR/1') ;
    add_line(model,'PFR/1','Adjust/1') ; add_line(model,'PFR/1','Product/1') ;
end

function buildEx15(model)
    addSystem(model,'F1','nirp.blocks.Stream',[250 120 380 170], ...
        'Role','Feed','TSource','Input port') ;
    addSystem(model,'CSTR','nirp.blocks.CSTR',[440 105 580 185], ...
        'V','200','VUnit','L','HeatMode','Heat exchange', ...
        'U','300','UUnit','W/(m^2*K)','A','9','AUnit','m^2', ...
        'UtilityTin','273','UtilityTinUnit','K','UtilityTout','NaN') ;
    addSystem(model,'Adjust','nirp.blocks.Adjust',[20 250 300 320], ...
        'TargetVariable','Conversion','KeyComponent','A','ReferenceFeed','F1', ...
        'TargetValue','0.8','InitialValue','295','MinValue','285', ...
        'MaxValue','305','ParameterUnit','K','Tolerance','1e-10') ;
    addSystem(model,'Product','nirp.blocks.Stream',[650 120 790 170], ...
        'Role','Product','ReferenceFeed','F1','KeyComponent','A') ;
    add_line(model,'Adjust/1','F1/1') ; add_line(model,'F1/1','CSTR/1') ;
    add_line(model,'CSTR/1','Adjust/1') ; add_line(model,'CSTR/1','Product/1') ;
end

function buildEx16(model)
    buildProblem30(model,'Adiabatic') ;
end

function buildEx17(model)
    buildProblem30(model,'Heat exchange') ;
end

function buildProblem30(model,heatMode)
    addSystem(model,'Feed PO','nirp.blocks.Stream',[20 90 150 140],'Role','Feed') ;
    addSystem(model,'Feed W','nirp.blocks.Stream',[20 230 150 280],'Role','Feed') ;
    addSystem(model,'Mixer','nirp.blocks.Mixer',[200 135 320 225],'NumInputs','2') ;
    addSystem(model,'Mixed feed','nirp.blocks.Stream',[360 155 490 205], ...
        'Role','Intermediate') ;
    reactorArgs = {'V','1.136','VUnit','m^3','HeatMode',heatMode} ;
    if strcmp(heatMode,'Heat exchange')
        reactorArgs = [reactorArgs {'U','567.7','UUnit','W/(m^2*K)', ...
            'A','3.7','AUnit','m^2','UtilityTin','29.5', ...
            'UtilityTinUnit',[char(176) 'C'],'UtilityTout','NaN'}] ;
    end
    addSystem(model,'CSTR','nirp.blocks.CSTR',[540 145 680 215],reactorArgs{:}) ;
    addSystem(model,'Product','nirp.blocks.Stream',[730 155 870 205], ...
        'Role','Product','ReferenceFeed','Feed PO','KeyComponent','PO') ;
    add_line(model,'Feed PO/1','Mixer/1') ; add_line(model,'Feed W/1','Mixer/2') ;
    add_line(model,'Mixer/1','Mixed feed/1') ; add_line(model,'Mixed feed/1','CSTR/1') ;
    add_line(model,'CSTR/1','Product/1') ;
end

function buildEx18(model)
    addSystem(model,'F1','nirp.blocks.Stream',[20 205 140 255],'Role','Feed') ;
    addSystem(model,'PFR','nirp.blocks.PFR',[380 75 520 155], ...
        'GeometryMode','Volume','VSource','Input port','D','0.1', ...
        'DUnit','m','HeatMode','Adiabatic') ;
    addSystem(model,'Adjust PFR','nirp.blocks.Adjust',[40 320 320 390], ...
        'TargetVariable','Conversion','KeyComponent','A','ReferenceFeed','F1', ...
        'TargetValue','0.85','InitialValue','20','MinValue','5', ...
        'MaxValue','100','ParameterUnit','L','Tolerance','1e-10') ;
    add_block('simulink/Sinks/To Workspace',[model '/Adjusted PFR volume'], ...
        'Position',[360 320 490 350],'VariableName','nirpAdjustedPfrVolume', ...
        'SaveFormat','Array') ;
    addSystem(model,'Product PFR','nirp.blocks.Stream',[600 90 750 140], ...
        'Role','Product','ReferenceFeed','F1','KeyComponent','A') ;
    addSystem(model,'CSTR','nirp.blocks.CSTR',[380 230 520 305], ...
        'VSource','Input port','HeatMode','Adiabatic') ;
    addSystem(model,'Adjust CSTR','nirp.blocks.Adjust',[360 360 640 430], ...
        'TargetVariable','Conversion','KeyComponent','A','ReferenceFeed','F1', ...
        'TargetValue','0.85','InitialValue','15','MinValue','10', ...
        'MaxValue','30','ParameterUnit','L','Tolerance','1e-10') ;
    addSystem(model,'Product CSTR','nirp.blocks.Stream',[600 245 750 295], ...
        'Role','Product','ReferenceFeed','F1','KeyComponent','A') ;
    add_line(model,'F1/1','PFR/1') ; add_line(model,'Adjust PFR/1','PFR/2') ;
    add_line(model,'Adjust PFR/1','Adjusted PFR volume/1') ;
    add_line(model,'PFR/1','Adjust PFR/1') ; add_line(model,'PFR/1','Product PFR/1') ;
    add_line(model,'F1/1','CSTR/1') ; add_line(model,'Adjust CSTR/1','CSTR/2') ;
    add_line(model,'CSTR/1','Adjust CSTR/1') ; add_line(model,'CSTR/1','Product CSTR/1') ;
end

function buildEx19(model)
    addSystem(model,'F1','nirp.blocks.Stream',[20 135 140 185],'Role','Feed') ;
    addSystem(model,'CSTR 1','nirp.blocks.CSTR',[370 120 510 195], ...
        'VSource','Input port','HeatMode','Specified T', ...
        'SpecifiedT','95','SpecifiedTUnit',[char(176) 'C']) ;
    addSystem(model,'CSTR 1 outlet','nirp.blocks.Stream',[550 135 690 185], ...
        'Role','Intermediate') ;
    addSystem(model,'CSTR 2','nirp.blocks.CSTR',[730 120 870 195], ...
        'VSource','Input port','HeatMode','Specified T', ...
        'SpecifiedT','95','SpecifiedTUnit',[char(176) 'C']) ;
    addSystem(model,'CSTR 2 outlet','nirp.blocks.Stream',[910 135 1050 185], ...
        'Role','Intermediate') ;
    addSystem(model,'CSTR 3','nirp.blocks.CSTR',[1090 120 1230 195], ...
        'VSource','Input port','HeatMode','Specified T', ...
        'SpecifiedT','95','SpecifiedTUnit',[char(176) 'C']) ;
    addSystem(model,'Adjust','nirp.blocks.Adjust',[40 270 320 340], ...
        'TargetVariable','Conversion','KeyComponent','A','ReferenceFeed','F1', ...
        'TargetValue','0.9','InitialValue','200','MinValue','100', ...
        'MaxValue','500','ParameterUnit','L','Tolerance','1e-10') ;
    addSystem(model,'Product','nirp.blocks.Stream',[1280 135 1420 185], ...
        'Role','Product','ReferenceFeed','F1','KeyComponent','A') ;
    add_line(model,'F1/1','CSTR 1/1') ; add_line(model,'Adjust/1','CSTR 1/2') ;
    add_line(model,'CSTR 1/1','CSTR 1 outlet/1') ;
    add_line(model,'CSTR 1 outlet/1','CSTR 2/1') ; add_line(model,'Adjust/1','CSTR 2/2') ;
    add_line(model,'CSTR 2/1','CSTR 2 outlet/1') ;
    add_line(model,'CSTR 2 outlet/1','CSTR 3/1') ; add_line(model,'Adjust/1','CSTR 3/2') ;
    add_line(model,'CSTR 3/1','Adjust/1') ; add_line(model,'CSTR 3/1','Product/1') ;
end

function buildEx20(model)
    addSystem(model,'F1','nirp.blocks.Stream',[250 120 380 170], ...
        'Role','Feed','TSource','Input port') ;
    addSystem(model,'CSTR','nirp.blocks.CSTR',[440 105 580 185], ...
        'V','250.480335','VUnit','L','HeatMode','Adiabatic') ;
    addSystem(model,'Adjust','nirp.blocks.Adjust',[20 250 300 320], ...
        'TargetVariable','Temperature','KeyComponent','A','ReferenceFeed','F1', ...
        'TargetValue','95','TargetUnit',[char(176) 'C'], ...
        'InitialValue','345','MinValue','335','MaxValue','355', ...
        'ParameterUnit','K','Tolerance','1e-10') ;
    addSystem(model,'Product','nirp.blocks.Stream',[650 120 790 170], ...
        'Role','Product','ReferenceFeed','F1','KeyComponent','A') ;
    add_line(model,'Adjust/1','F1/1') ; add_line(model,'F1/1','CSTR/1') ;
    add_line(model,'CSTR/1','Adjust/1') ; add_line(model,'CSTR/1','Product/1') ;
end

function addSystem(model,name,className,position,varargin)
    minimumWidth=0;
    switch className
        case 'nirp.blocks.Stream',minimumWidth=120;
        case 'nirp.blocks.Heater',minimumWidth=150;
        case 'nirp.blocks.Recycle',minimumWidth=180;
        case 'nirp.blocks.Adjust',minimumWidth=280;
    end
    position(3)=max(position(3),position(1)+minimumWidth);
    add_block('simulink/User-Defined Functions/MATLAB System',[model '/' name], ...
        'System',className,'Position',position,varargin{:});
    if ~strcmp(className,'nirp.blocks.Stream')
        nirp.flowsheet.setupUnitBlock([model '/' name]);
    end
end
