classdef NirpParameterPortsTest < matlab.unittest.TestCase
    % NirpParameterPortsTest verifies adjustable flow and thermal ports.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 4, 2026. Last update: October 4, 2026
    % =========================================================================

    properties
        Folder
        SimulinkFolder
        Files
        FileGenerationConfig
        GeneratedFolder
    end

    methods (TestClassSetup)
        function createExamples(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture) ;
            testCase.Folder = fixture.Folder ; addpath(testCase.Folder) ;
            testCase.SimulinkFolder = fullfile( ...
                fileparts(fileparts(mfilename('fullpath'))),'simulink') ;
            addpath(testCase.SimulinkFolder) ;
            testCase.addTeardown(@() rmpath(testCase.Folder)) ;
            testCase.addTeardown(@() rmpath(testCase.SimulinkFolder)) ;
            testCase.FileGenerationConfig = Simulink.fileGenControl('getConfig') ;
            testCase.GeneratedFolder = fullfile(testCase.Folder,'generated') ;
            Simulink.fileGenControl('set','CacheFolder', ...
                fullfile(testCase.GeneratedFolder,'cache'),'CodeGenFolder', ...
                fullfile(testCase.GeneratedFolder,'codegen'),'createDir',true) ;
            testCase.addTeardown(@() Simulink.fileGenControl('setConfig', ...
                'config',testCase.FileGenerationConfig)) ;
            testCase.Files = build_examples(testCase.Folder) ;
        end
    end

    methods (TestMethodTeardown)
        function closeModels(~)
            bdclose('all') ; Simulink.data.dictionary.closeAll('-discard') ;
            evalin('base','clear nirpResults') ;
        end
    end

    methods (Test)
        function liquidFlowPortPreservesConcentration(testCase)
            results = simulateExample(testCase.Files(31), ...
                "ex31_problem41_three_cstrs") ;
            feed = results.Streams.F1.streamSI ;
            expected = nirp.pkg.feedStream( ...
                nirp.pkg.examples.problem41SecondOrder(),"F1") ;
            testCase.verifyEqual(nirp.stream.concentration(feed), ...
                nirp.stream.concentration(expected),'RelTol',1e-12) ;
            flow = diagnosticParameter(results,"ex31_problem41_three_cstrs","Adjust") ;
            testCase.verifyEqual(feed.Q,flow,'RelTol',1e-12) ;
            product = threeCstr(flow,expected) ;
            verifyStream(testCase,results.Streams.Product.streamSI,product,1e-12) ;
        end

        function gasFlowPortScalesComposition(testCase)
            pkg = nirp.pkg.examples.problem33Gas() ;
            reference = nirp.pkg.feedStream(pkg,"F1") ; requested = 1.7*reference.Q ;
            name = 'parameter_port_gas' ;
            buildFeedPortModel(testCase.Folder,name,pkg,requested) ;
            results = simulateExample(fullfile(testCase.Folder,name+".slx"),name) ;
            actual = results.Streams.F1.streamSI ;
            testCase.verifyEqual(actual.Q,requested,'RelTol',1e-12) ;
            testCase.verifyEqual(actual.F/sum(actual.F), ...
                reference.F/sum(reference.F),'RelTol',1e-12) ;
            testCase.verifyEqual(actual.F,1.7*reference.F,'RelTol',1e-12) ;
        end

        function areaAndUtilityPortsMatchDialogCalculations(testCase)
            areaResults = simulateExample(testCase.Files(34), ...
                "ex34_problem45c_cooled_tanks") ;
            pkg45 = nirp.pkg.examples.problem45Liquid() ;
            rs45 = nirp.pkg.toReactionSys(pkg45) ;
            first = nirp.units.cstr(struct('V',0.250480335, ...
                'heatMode','Specified T','specifiedT',368.15), ...
                nirp.pkg.feedStream(pkg45,"F1"),rs45) ;
            area = diagnosticParameter(areaResults, ...
                "ex34_problem45c_cooled_tanks","Adjust 2") ;
            expected = nirp.units.cstr(struct('V',0.250480335, ...
                'heatMode','Other','U',1180,'A',area,'utilityTin',293.15), ...
                first,rs45) ;
            verifyStream(testCase,areaResults.Streams.CSTR2Outlet.streamSI, ...
                expected,1e-12) ;

            utilityResults = simulateExample(testCase.Files(35), ...
                "ex35_problem28_steam_jacket") ;
            pkg28 = nirp.pkg.examples.problem28SteamJacket() ;
            rs28 = nirp.pkg.toReactionSys(pkg28) ;
            utilityT = diagnosticParameter(utilityResults, ...
                "ex35_problem28_steam_jacket","Adjust") ;
            expected = nirp.units.cstr(struct('V',1.2,'heatMode','Other', ...
                'U',15070e3/3600,'A',6,'utilityTin',utilityT), ...
                nirp.pkg.feedStream(pkg28,"F1"),rs28) ;
            verifyStream(testCase,utilityResults.Streams.Product.streamSI, ...
                expected,1e-12) ;
        end

        function thermalPortsBelongToJacket(testCase)
            for className = ["nirp.blocks.CSTR","nirp.blocks.PFR"]
                properties=meta.class.fromName(className).PropertyList;
                for name=["ASource","UtilityTinSource"]
                    testCase.verifyTrue(properties(strcmp({properties.Name},name)).Hidden);
                end
            end
            properties=meta.class.fromName('nirp.blocks.Jacket').PropertyList;
            for name=["ASource","UtilityTinSource"]
                testCase.verifyFalse(properties(strcmp({properties.Name},name)).Hidden);
            end
        end

        function collectionExamplesMeetReferences(testCase)
            results41 = simulateExample(testCase.Files(31),"ex31_problem41_three_cstrs") ;
            verifyAdjusted(testCase,results41,"ex31_problem41_three_cstrs","Adjust", ...
                1.953848/60000) ;
            verifyConversion(testCase,results41,0.8) ;

            results43a = simulateExample(testCase.Files(32),"ex32_problem43_pfr_then_cstr") ;
            verifyAdjusted(testCase,results43a,"ex32_problem43_pfr_then_cstr","Adjust", ...
                3.876476*100/3600) ; verifyConversion(testCase,results43a,0.96) ;
            results43b = simulateExample(testCase.Files(33),"ex33_problem43_cstr_then_pfr") ;
            verifyAdjusted(testCase,results43b,"ex33_problem43_cstr_then_pfr","Adjust", ...
                1.837571*100/3600) ; verifyConversion(testCase,results43b,0.96) ;

            results45 = simulateExample(testCase.Files(34),"ex34_problem45c_cooled_tanks") ;
            verifyAdjusted(testCase,results45,"ex34_problem45c_cooled_tanks","Adjust 2",0.195240) ;
            verifyAdjusted(testCase,results45,"ex34_problem45c_cooled_tanks","Adjust 3",0.090622) ;
            testCase.verifyEqual(results45.Streams.CSTR2Outlet.streamSI.T,368.15,'AbsTol',1e-4) ;
            testCase.verifyEqual(results45.Streams.Product.streamSI.T,368.15,'AbsTol',1e-4) ;

            results28 = simulateExample(testCase.Files(35),"ex35_problem28_steam_jacket") ;
            verifyAdjusted(testCase,results28,"ex35_problem28_steam_jacket","Adjust",401.4397) ;
            verifyConversion(testCase,results28,0.6) ;
            testCase.verifyEqual(results28.Streams.Product.streamSI.T,399.7748,'AbsTol',1e-4) ;

            results36 = simulateExample(testCase.Files(36),"ex36_problem36_air_cooled_cstr") ;
            verifyAdjusted(testCase,results36,"ex36_problem36_air_cooled_cstr","Adjust",9.4288) ;
            verifyConversion(testCase,results36,0.85,"FeedA") ;
            testCase.verifyEqual(results36.Streams.Product.streamSI.T,298.5748,'AbsTol',1e-4) ;
        end
    end
end

function results = simulateExample(file,name)
    evalin('base','clear nirpResults') ; load_system(char(file)) ;
    sim(char(name)) ; results = evalin('base','nirpResults') ;
    close_system(char(name),0) ; Simulink.data.dictionary.closeAll('-discard') ;
end

function value = diagnosticParameter(results,model,block)
    field = matlab.lang.makeValidName(model+"_"+block) ;
    value = results.Diagnostics.(field).lastInfo.value ;
end

function verifyAdjusted(testCase,results,model,block,expected)
    testCase.verifyEqual(diagnosticParameter(results,model,block),expected, ...
        'RelTol',1e-5) ;
end

function verifyConversion(testCase,results,expected,feedName)
    if nargin < 4, feedName = "F1" ; end
    feed = results.Streams.(char(feedName)).streamSI ;
    product = results.Streams.Product.streamSI ;
    actual = (feed.F(1)-product.F(1))/feed.F(1) ;
    testCase.verifyEqual(actual,expected,'AbsTol',1e-6) ;
    testCase.verifyEqual(results.Streams.Product.conversion,expected,'AbsTol',1e-6) ;
end

function verifyStream(testCase,actual,expected,tolerance)
    testCase.verifyEqual(actual.F,expected.F,'RelTol',tolerance) ;
    testCase.verifyEqual(actual.T,expected.T,'RelTol',tolerance) ;
    testCase.verifyEqual(actual.P,expected.P,'RelTol',tolerance) ;
    testCase.verifyEqual(actual.Q,expected.Q,'RelTol',tolerance) ;
end

function product = threeCstr(flow,reference)
    feed = reference ; feed.F = reference.F*(flow/reference.Q) ; feed.Q = flow ;
    rs = nirp.pkg.toReactionSys(nirp.pkg.examples.problem41SecondOrder()) ;
    product = feed ;
    for i = 1:3, product = nirp.units.cstr(struct('V',4.406197e-3),product,rs) ; end
end

function buildFeedPortModel(folder,name,pkg,requested)
    createModel(folder,name,pkg) ;
    add_block('simulink/Sources/Constant',[name '/Q'], ...
        'Value',num2str(requested,17),'Position',[20 100 80 130]) ;
    addSystem(name,'F1','nirp.blocks.Stream',[130 90 260 140], ...
        'Role','Feed','QSource','Input port') ;
    addSystem(name,'Product','nirp.blocks.Stream',[320 90 450 140], ...
        'Role','Product') ;
    add_line(name,'Q/1','F1/1') ; add_line(name,'F1/1','Product/1') ;
    finishModel(folder,name) ;
end

function buildInvalidThermalModel(folder,name,className,source)
    pkg = nirp.pkg.examples.firstOrderLiquid() ; createModel(folder,name,pkg) ;
    addSystem(name,'F1','nirp.blocks.Stream',[20 90 140 140],'Role','Feed') ;
    add_block('simulink/Sources/Constant',[name '/Parameter'], ...
        'Value','1','Position',[180 180 240 210]) ;
    args = {source,'Input port','HeatMode','Isothermal'} ;
    if strcmp(className,'nirp.blocks.PFR'),args=[args {'D','0.1'}];end
    addSystem(name,'Reactor',className,[300 80 440 150],args{:}) ;
    addSystem(name,'Product','nirp.blocks.Stream',[500 90 630 140],'Role','Product') ;
    add_line(name,'F1/1','Reactor/1') ; add_line(name,'Parameter/1','Reactor/2') ;
    add_line(name,'Reactor/1','Product/1') ; finishModel(folder,name) ;
end

function createModel(folder,name,pkg)
    dictionary = fullfile(folder,[name '.sldd']) ;
    nirp.pkg.writeDictionary(pkg,dictionary) ; new_system(name) ;
    save_system(name,fullfile(folder,[name '.slx'])) ;
    set_param(name,'DataDictionary',[name '.sldd']) ;
    nirp.flowsheet.addBlock(name,'Flowsheet',[20 20 140 75],50) ;
end

function finishModel(folder,name)
    nirp.flowsheet.configure(name) ;
    save_system(name,fullfile(folder,[name '.slx'])) ; close_system(name,0) ;
    Simulink.data.dictionary.closeAll('-discard') ;
end

function addSystem(model,name,className,position,varargin)
    add_block('simulink/User-Defined Functions/MATLAB System',[model '/' name], ...
        'System',className,'Position',position,varargin{:}) ;
    if ~strcmp(className,'nirp.blocks.Stream')
        nirp.flowsheet.setupUnitBlock([model '/' name]) ;
    end
end
