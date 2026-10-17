classdef NirpOpenExampleTest < matlab.unittest.TestCase
    % NirpOpenExampleTest verifies on-demand example generation.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 17, 2026. Last update: October 17, 2026
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
            root = fileparts(fileparts(mfilename('fullpath'))) ;
            testCase.SimulinkFolder = fullfile(root,'simulink') ;
            addpath(testCase.SimulinkFolder) ;
            testCase.FileGenerationConfig = Simulink.fileGenControl('getConfig') ;
            Simulink.fileGenControl('set','CacheFolder', ...
                fullfile(testCase.Folder,'cache'),'CodeGenFolder', ...
                fullfile(testCase.Folder,'codegen'),'createDir',true) ;
            testCase.addTeardown(@() cleanup(testCase)) ;
        end
    end

    methods (Test)
        function missingExampleIsGeneratedInDestination(testCase)
            destination = fullfile(testCase.Folder,'new-example') ;
            modelFile = nirp.flowsheet.openExample('ex1_cstr_isothermal', ...
                'Folder',destination,'NoWindow',true) ;

            testCase.verifyEqual(modelFile,fullfile(destination, ...
                'ex1_cstr_isothermal.slx')) ;
            testCase.verifyTrue(isfile(modelFile)) ;
            testCase.verifyTrue(isfile(fullfile(destination, ...
                'ex1_cstr_isothermal.sldd'))) ;
        end

        function restoreReplacesChangedExample(testCase)
            destination = fullfile(testCase.Folder,'restore-example') ;
            name = 'ex1_cstr_isothermal' ;
            nirp.flowsheet.openExample(name,'Folder',destination, ...
                'NoWindow',true) ;
            set_param(name,'Description','User change') ;
            save_system(name) ;

            nirp.flowsheet.openExample(name,'Folder',destination, ...
                'NoWindow',true,'PromptFcn',@restoreAnswer) ;

            testCase.verifyNotEqual(get_param(name,'Description'),'User change') ;
        end

        function openExistingPreservesChangedExample(testCase)
            destination = fullfile(testCase.Folder,'existing-example') ;
            name = 'ex1_cstr_isothermal' ;
            nirp.flowsheet.openExample(name,'Folder',destination, ...
                'NoWindow',true) ;
            set_param(name,'Description','User change') ;
            save_system(name) ;
            close_system(name,0) ;

            nirp.flowsheet.openExample(name,'Folder',destination, ...
                'NoWindow',true,'PromptFcn',@openExistingAnswer) ;

            testCase.verifyEqual(get_param(name,'Description'),'User change') ;
        end

        function requestedExamplesOpenWithoutShadowWarnings(testCase)
            names = ["ex5_recycle_cstr" "ex35_problem28_steam_jacket"] ;
            collisionFolder = fullfile(testCase.Folder,'existing-copies') ;
            build_examples(collisionFolder,names) ;
            addpath(collisionFolder) ;

            warningState = warning('error','Simulink:Engine:MdlFileShadowing') ;
            warningCleanup = onCleanup(@() warning(warningState)) ; %#ok<NASGU>
            for name = names
                destination = fullfile(testCase.Folder,char(name)) ;
                modelFile = nirp.flowsheet.openExample(name, ...
                    'Folder',destination,'NoWindow',true) ;
                testCase.verifyTrue(isfile(modelFile)) ;
                testCase.verifyTrue(isfile(fullfile(destination,name+".sldd"))) ;
                testCase.verifyEqual(numel(dir(fullfile(destination,'*.slx'))),1) ;
                sim(char(name)) ;
                close_system(char(name),0) ;
                Simulink.data.dictionary.closeAll('-discard') ;
                rmpathIfPresent(destination) ;
            end
        end
    end
end

function answer = restoreAnswer(message)
    assert(strcmp(message,['Example "Isothermal CSTR" already exists. ' ...
        'Restore the original example (your changes in it will be lost) ' ...
        'or open your copy?'])) ;
    answer = 'Restore' ;
end

function answer = openExistingAnswer(message)
    assert(contains(message,'already exists')) ;
    answer = 'Open existing' ;
end

function cleanup(testCase)
    bdclose('all') ;
    Simulink.data.dictionary.closeAll('-discard') ;
    evalin('base','clear nirpResults') ;
    Simulink.fileGenControl('setConfig','config',testCase.FileGenerationConfig) ;
    rmpathIfPresent(testCase.SimulinkFolder) ;
    rmpathIfPresent(fullfile(testCase.Folder,'existing-copies')) ;
end

function rmpathIfPresent(folder)
    if contains([path pathsep],[folder pathsep]), rmpath(folder) ; end
end
