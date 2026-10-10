classdef (SharedTestFixtures={nirptest.ExamplesFixture}) ...
        NirpPortDisplayTest < matlab.unittest.TestCase
    % NirpPortDisplayTest verifies parameter-port results and dialog cues.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 4, 2026. Last update: October 4, 2026
    % =========================================================================

    properties
        Folder
        ExamplesFolder
        Files
    end

    methods (TestClassSetup)
        function createExamples(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture) ;
            testCase.Folder = fixture.Folder ; addpath(testCase.Folder) ;
            testCase.addTeardown(@() rmpath(testCase.Folder)) ;
            examples = testCase.getSharedTestFixtures( ...
                'nirptest.ExamplesFixture') ;
            testCase.ExamplesFolder = examples.Folder ;
            testCase.Files = examples.Files ;
        end
    end

    methods (TestMethodTeardown)
        function closeArtifacts(~)
            figures = findall(groot,'Type','Figure') ;
            if ~isempty(figures), delete(figures) ; end
            bdclose('all') ; Simulink.data.dictionary.closeAll('-discard') ;
            evalin('base','clear nirpResults') ;
        end
    end

    methods (Test)
        function parameterPortTablesUseConfiguredUnits(testCase)
            tables = simulateTables(testCase.Files(31), ...
                "ex31_problem41_three_cstrs") ;
            testCase.verifyNotEmpty(tables.Units) ;
            testCase.verifyNotEmpty(tables.Adjust) ;
            testCase.verifyEqual(tables.Adjust.Parameter,1.953848, ...
                'RelTol',1e-5) ;
            testCase.verifyEqual(tables.Adjust.ParameterUnit,"L/min") ;

            tables = simulateTables(testCase.Files(34), ...
                "ex34_problem45c_cooled_tanks") ;
            expected = [0.195240;0.090622] ;
            adjusts = ismember(tables.Adjust.Block,["Adjust 2","Adjust 3"]) ;
            jackets = ismember(tables.Units.Block,["Jacket 2","Jacket 3"]) ;
            testCase.verifyNotEmpty(tables.Units) ;
            testCase.verifyNotEmpty(tables.Adjust) ;
            testCase.verifyEqual(tables.Adjust.Parameter(adjusts),expected, ...
                'RelTol',1e-5) ;
            testCase.verifyEqual(tables.Adjust.ParameterUnit(adjusts),["m^2";"m^2"]) ;
            testCase.verifyEqual(tables.Units.A(jackets),expected,'RelTol',1e-5) ;
            testCase.verifyEqual(tables.Units.AUnit(jackets),["m^2";"m^2"]) ;

            tables = simulateTables(testCase.Files(35), ...
                "ex35_problem28_steam_jacket") ;
            jacket = tables.Units.Block=="Jacket" ;
            testCase.verifyNotEmpty(tables.Units) ;
            testCase.verifyNotEmpty(tables.Adjust) ;
            testCase.verifyEqual(tables.Adjust.Parameter,401.4397,'RelTol',1e-5) ;
            testCase.verifyEqual(tables.Units.UtilityTin(jacket),401.4397, ...
                'RelTol',1e-5) ;
            testCase.verifyEqual(tables.Units.UtilityTinUnit(jacket),"K") ;
            testCase.verifyTrue(isfinite(tables.Units.ServiceFlow(jacket))) ;
            testCase.verifyEqual(tables.Units.ServiceFlowUnit(jacket),"kg/s") ;

            tables = simulateTables(testCase.Files(36), ...
                "ex36_problem36_air_cooled_cstr") ;
            jacket = tables.Units.Block=="Jacket" ;
            testCase.verifyNotEmpty(tables.Units) ;
            testCase.verifyNotEmpty(tables.Adjust) ;
            testCase.verifyEqual(tables.Adjust.Parameter,9.4288,'RelTol',1e-5) ;
            testCase.verifyEqual(tables.Units.A(jacket),9.4288,'RelTol',1e-5) ;
            testCase.verifyEqual(tables.Units.AUnit(jacket),"m^2") ;
        end

        function failedRowIsReportedWithoutClearingTables(testCase)
            load_system(char(testCase.Files(31))) ;
            sim('ex31_problem41_three_cstrs') ;
            results = evalin('base','nirpResults') ;
            field = 'ex31_problem41_three_cstrs_Adjust' ;
            results.Diagnostics.(field).lastInfo.parameterUnit = 'invalid unit' ;
            assignin('base','nirpResults',results) ; lastwarn('') ;
            tables = nirp.flowsheet.showResults( ...
                'ex31_problem41_three_cstrs','NoWindow',true) ;
            [message,identifier] = lastwarn ;
            testCase.verifyEqual(identifier,'nirp:flowsheet:unitResultRow') ;
            testCase.verifySubstring(message,'Adjust') ;
            testCase.verifyNotEmpty(tables.Units) ;
            testCase.verifyEqual(height(tables.Adjust),1) ;
            testCase.verifyNotEmpty(tables.Adjust.Message(1)) ;
        end

        function dialogsIdentifyParametersFromPorts(testCase)
            load_system(char(testCase.Files(34))) ;
            jacket = nirp.flowsheet.JacketDialog( ...
                'ex34_problem45c_cooled_tanks/Jacket 2','Visible','off') ;
            testCase.verifyEqual(string(jacket.AField.Visible),"off") ;
            testCase.verifyEqual(string(jacket.AField.Editable),"off") ;
            testCase.verifyEqual(string(jacket.APortLabel.Visible),"on") ;
            testCase.verifyEqual(string(jacket.APortLabel.Text),"From input port") ;
            jacket.setValues('ASource','Dialog') ;
            testCase.verifyEqual(string(jacket.AField.Visible),"on") ;
            testCase.verifyEqual(string(jacket.AField.Editable),"on") ;
            delete(jacket) ; close_system('ex34_problem45c_cooled_tanks',0) ;
            Simulink.data.dictionary.closeAll('-discard') ;

            load_system(char(testCase.Files(31))) ;
            stream = nirp.flowsheet.StreamDialog( ...
                'ex31_problem41_three_cstrs/F1','Visible','off') ;
            testCase.verifyEqual(string(stream.VolumetricFlowField.Visible),"off") ;
            testCase.verifyEqual(string(stream.VolumetricFlowField.Editable),"off") ;
            testCase.verifyEqual(string(stream.QPortLabel.Visible),"on") ;
            testCase.verifyEqual(string(stream.QPortLabel.Text),"From input port") ;
            stream.setValues('QSource','Dialog') ;
            testCase.verifyEqual(string(stream.VolumetricFlowField.Visible),"on") ;
            testCase.verifyEqual(string(stream.VolumetricFlowField.Editable),"on") ;
        end

        function streamPortRowsAndTotalFractionsRemainReadable(testCase)
            load_system(char(testCase.Files(31))) ;
            stream = nirp.flowsheet.StreamDialog( ...
                'ex31_problem41_three_cstrs/F1','Visible','off') ;
            testCase.addTeardown(@() deleteValid(stream)) ;
            drawnow ;
            testCase.verifyEqual(stream.QPortLabel.Layout.Row,1) ;
            testCase.verifyEqual(numel(stream.QPortLabel.Parent.RowHeight),1) ;
            delete(stream) ; close_system('ex31_problem41_three_cstrs',0) ;
            Simulink.data.dictionary.closeAll('-discard') ;

            load_system(char(testCase.Files(13))) ;
            stream = nirp.flowsheet.StreamDialog( ...
                'ex13_problem21a_isothermal_pfr/F1','Visible','off') ;
            testCase.addTeardown(@() deleteValid(stream)) ;
            drawnow ;
            testCase.verifyEqual(string(stream.TPortLabel.Visible),"on") ;
            testCase.verifyEqual(stream.TPortLabel.Layout.Row,1) ;
            testCase.verifyEqual(numel(stream.TPortLabel.Parent.RowHeight),1) ;
            testCase.verifyTrue(all(isfinite(stream.getValue('MolarFlow')))) ;
            testCase.verifyTrue(all(isfinite(stream.getValue('Concentration')))) ;
            expected = nirp.pkg.feedStream( ...
                nirp.pkg.examples.problem21Gas(),'F1') ;
            actualFlow = UnitConverterHelper.convertToSI('MolarFlow', ...
                stream.getValue('MolarFlow'),stream.MolarFlowUnitDropDown.Value) ;
            actualConcentration = UnitConverterHelper.convertToSI( ...
                'Concentration',stream.getValue('Concentration'), ...
                stream.ConcentrationUnitDropDown.Value) ;
            testCase.verifyEqual(actualFlow,expected.F,'RelTol',1e-12) ;
            testCase.verifyEqual(actualConcentration, ...
                nirp.stream.concentration(expected),'RelTol',1e-12) ;
        end
    end
end

function tables = simulateTables(file,name)
    evalin('base','clear nirpResults') ; load_system(char(file)) ;
    sim(char(name)) ;
    tables = nirp.flowsheet.showResults(char(name),'NoWindow',true) ;
    close_system(char(name),0) ; Simulink.data.dictionary.closeAll('-discard') ;
end

function deleteValid(value)
    if ~isempty(value) && isvalid(value), delete(value) ; end
end
