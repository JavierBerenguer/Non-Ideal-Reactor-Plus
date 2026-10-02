classdef NirpUiAccessTest < matlab.unittest.TestCase
    % NirpUiAccessTest verifies no-code access to the NIRP Simulink UI.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 2, 2026
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
            Simulink.fileGenControl('set','CacheFolder',fullfile(testCase.Folder,'cache'), ...
                'CodeGenFolder',fullfile(testCase.Folder,'codegen'),'createDir',true) ;
            testCase.addTeardown(@() Simulink.fileGenControl( ...
                'setConfig','config',testCase.FileGenerationConfig)) ;
            testCase.addTeardown(@() closeAllUi()) ;
            testCase.addTeardown(@() rmpathIfPresent(fullfile( ...
                testCase.SimulinkFolder,'examples'))) ;
            testCase.addTeardown(@() rmpathIfPresent(testCase.SimulinkFolder)) ;
            testCase.addTeardown(@() rmpathIfPresent(testCase.Folder)) ;
            evalin('base','clear nirpResults') ;
        end
    end

    methods (Test)
        function libraryIsRegisteredAndSetup(testCase)
            info = slblocks() ;
            testCase.verifyEqual(info.Browser.Library,'NirpLibrary') ;
            testCase.verifyEqual(info.Browser.Name,'Non-Ideal Reactor Plus') ;
            libraryFile = nirp.setup() ;
            testCase.verifyTrue(contains([path pathsep], ...
                [testCase.SimulinkFolder pathsep])) ;
            testCase.verifyTrue(isfile(libraryFile)) ;
            load_system(libraryFile) ;
            testCase.verifyEqual(get_param('NirpLibrary','EnableLBRepository'),'on') ;
        end

        function openExampleGeneratesAndLoadsHeadlessly(testCase)
            modelFile = nirp.flowsheet.openExample('ex1_cstr_isothermal', ...
                'Folder',testCase.Folder,'NoWindow',true) ;
            testCase.verifyTrue(isfile(modelFile)) ;
            testCase.verifyTrue(bdIsLoaded('ex1_cstr_isothermal')) ;
        end

        function showResultsReturnsProductUnits(testCase)
            nirp.flowsheet.openExample('ex1_cstr_isothermal', ...
                'Folder',testCase.Folder,'NoWindow',true) ;
            sim('ex1_cstr_isothermal') ;
            resultTables = nirp.flowsheet.showResults( ...
                'ex1_cstr_isothermal','NoWindow',true) ;
            result = resultTables.Product ;
            testCase.verifyEqual(result.Component,["A";"B"]) ;
            testCase.verifyEqual(result.FUnit,repmat("mol/s",2,1)) ;
            testCase.verifyEqual(result.CUnit,repmat("mol/m^3",2,1)) ;
            testCase.verifyEqual(result.TUnit,repmat("K",2,1)) ;
            testCase.verifyEqual(result.PUnit,repmat("Pa",2,1)) ;
            testCase.verifyEqual(result.Conversion,repmat(0.5,2,1), ...
                'AbsTol',1e-9) ;
        end

        function appContainsFlowsheetMenu(testCase)
            app = NonIdealReactorApp() ;
            figureHandle = findall(groot,'Type','Figure', ...
                'Name','Non-Ideal Reactor Analysis') ;
            set(figureHandle,'Visible','off') ;
            testCase.addTeardown(@() deleteIfValid(app)) ;
            menu = findall(figureHandle(1),'Type','uimenu', ...
                'Text','Flowsheet (Simulink)') ;
            testCase.verifyNumElements(menu,1) ;
            children = menu.Children ;
            testCase.verifyEqual(sort(string({children.Text})), ...
                sort(["New flowsheet...","Open block library","Open example..."])) ;
        end

        function missingFeedMessageListsValidFeeds(testCase)
            build_examples(testCase.Folder) ;
            load_system(fullfile(testCase.Folder,'ex1_cstr_isothermal.slx')) ;
            set_param('ex1_cstr_isothermal/F1','NameChangeFcn','') ;
            set_param('ex1_cstr_isothermal/F1','Name','missing') ;
            try
                sim('ex1_cstr_isothermal') ;
                testCase.assertFail('Expected simulation to fail.') ;
            catch exception
                messages = string(exception.message) ;
                causes = exception.cause ;
                if ~isempty(causes), messages(end+1) = string(causes{1}.message) ; end
                testCase.verifyTrue(any(contains(messages,'Open this block')), ...
                    strjoin(cellstr(messages),newline)) ;
            end
        end
    end
end

function closeAllUi()
    bdclose('all') ;
    Simulink.data.dictionary.closeAll('-discard') ;
    figures = findall(groot,'Type','Figure') ;
    if ~isempty(figures), delete(figures) ; end
    evalin('base','clear nirpResults') ;
end

function deleteIfValid(value)
    try
        if isvalid(value), delete(value) ; end
    catch
    end
end

function rmpathIfPresent(folder)
    if contains([path pathsep],[folder pathsep]), rmpath(folder) ; end
end
