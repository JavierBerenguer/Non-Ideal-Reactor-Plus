classdef NirpUnitResultsTest < matlab.unittest.TestCase
    % NirpUnitResultsTest verifies unit-operation result presentation.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 3, 2026. Last update: October 3, 2026
    % =========================================================================

    properties
        Folder
        SimulinkFolder
        FileGenerationConfig
    end

    methods (TestMethodSetup)
        function createTemporaryWorkspace(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture) ;
            testCase.Folder = fixture.Folder ;
            testCase.SimulinkFolder = fullfile( ...
                fileparts(fileparts(mfilename('fullpath'))),'simulink') ;
            addpath(testCase.SimulinkFolder) ; addpath(testCase.Folder) ;
            testCase.FileGenerationConfig = Simulink.fileGenControl('getConfig') ;
            Simulink.fileGenControl('set', ...
                'CacheFolder',fullfile(testCase.Folder,'cache'), ...
                'CodeGenFolder',fullfile(testCase.Folder,'codegen'), ...
                'createDir',true) ;
            testCase.addTeardown(@() Simulink.fileGenControl( ...
                'setConfig','config',testCase.FileGenerationConfig)) ;
            testCase.addTeardown(@() removePath(testCase.SimulinkFolder)) ;
            testCase.addTeardown(@() removePath(testCase.Folder)) ;
            testCase.addTeardown(@() closeModels()) ;
        end
    end

    methods (Test)
        function unitTablesContainAdjustedVolumesAndHeatDuty(testCase)
            files = build_examples(testCase.Folder) ;

            load_system(char(files(6))) ; sim('ex6_adjust_volume') ;
            results = evalin('base','nirpResults') ;
            tables = nirp.flowsheet.showResults( ...
                'ex6_adjust_volume','NoWindow',true) ;
            cstr = tables.Units.Block == "CSTR" ;
            adjust = tables.Units.Block == "Adjust" ;
            expectedV = results.Diagnostics.ex6_adjust_volume_CSTR.lastInfo.V ;
            testCase.verifyEqual(tables.Units.V(cstr),expectedV,'RelTol',1e-10) ;
            testCase.verifyEqual(tables.Units.VUnit(cstr),"m^3") ;
            testCase.verifyTrue(logical(tables.Units.Converged(adjust))) ;
            testCase.verifyEqual(tables.Units.Parameter(adjust),expectedV, ...
                'RelTol',1e-10) ;
            testCase.verifyEqual(tables.Units.TargetVariable(adjust),"Conversion") ;
            testCase.verifyEqual(tables.Units.Target(adjust),0.8,'AbsTol',1e-10) ;
            testCase.verifyEqual(tables.Units.Measured(adjust),0.8,'AbsTol',1e-8) ;
            close_system('ex6_adjust_volume',0) ;
            Simulink.data.dictionary.closeAll('-discard') ;

            evalin('base','clear nirpResults') ;
            load_system(char(files(18))) ; sim('ex18_problem44a_volumes') ;
            tables = nirp.flowsheet.showResults( ...
                'ex18_problem44a_volumes','NoWindow',true) ;
            pfr = tables.Units.Block == "PFR" ;
            cstr = tables.Units.Block == "CSTR" ;
            testCase.verifyEqual(tables.Units.V(pfr),30.509470,'RelTol',1e-5) ;
            testCase.verifyEqual(tables.Units.V(cstr),17.592665,'RelTol',1e-5) ;
            testCase.verifyEqual(tables.Units.VUnit(pfr | cstr),["L";"L"]) ;
            nirp.flowsheet.showResults( ...
                'ex18_problem44a_volumes','Visible','off') ;
            figureHandle = findall(groot,'Type','Figure', ...
                'Name','NIRP results - ex18_problem44a_volumes') ;
            testCase.assertNotEmpty(figureHandle) ;
            tabGroup = findall(figureHandle(1),'Type','uitabgroup') ;
            testCase.verifyEqual(string(tabGroup.Children(1).Title),"Units") ;
            delete(figureHandle) ; close_system('ex18_problem44a_volumes',0) ;
            Simulink.data.dictionary.closeAll('-discard') ;

            evalin('base','clear nirpResults') ;
            load_system(char(files(2))) ; sim('ex2_cstr_adiabatic_cooler') ;
            results = evalin('base','nirpResults') ;
            tables = nirp.flowsheet.showResults( ...
                'ex2_cstr_adiabatic_cooler','NoWindow',true) ;
            cooler = tables.Units.Block == "Cooler" ;
            expectedQ = results.Diagnostics.ex2_cstr_adiabatic_cooler_Cooler.lastInfo.heatDuty ;
            unit = string(get_param('ex2_cstr_adiabatic_cooler/Cooler','DutyUnit')) ;
            expectedQ = UnitConverterHelper.convertFromSI('Power',expectedQ,char(unit)) ;
            testCase.verifyEqual(tables.Units.HeatDuty(cooler),expectedQ, ...
                'RelTol',1e-10) ;
            testCase.verifyEqual(tables.Units.QUnit(cooler),unit) ;
        end
    end
end

function closeModels()
    figures = findall(groot,'Type','Figure') ;
    if ~isempty(figures), delete(figures) ; end
    bdclose('all') ; Simulink.data.dictionary.closeAll('-discard') ;
    evalin('base','clear nirpResults') ;
end

function removePath(folder)
    if contains([path pathsep],[folder pathsep]), rmpath(folder) ; end
end
