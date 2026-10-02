classdef NirpToolboxTest < matlab.unittest.TestCase
    % NirpToolboxTest verifies packaging and installed-example behaviour.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 2, 2026
    % =========================================================================

    properties
        Folder
        ScriptsFolder
        SimulinkFolder
        FileGenerationConfig
    end

    methods (TestMethodSetup)
        function createTemporaryWorkspace(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture) ;
            testCase.Folder = fixture.Folder ;
            root = fileparts(fileparts(mfilename('fullpath'))) ;
            testCase.ScriptsFolder = fullfile(root,'scripts') ;
            testCase.SimulinkFolder = fullfile(root,'simulink') ;
            addpath(testCase.ScriptsFolder) ;
            addpath(testCase.SimulinkFolder) ;
            testCase.FileGenerationConfig = Simulink.fileGenControl('getConfig') ;
            Simulink.fileGenControl('set','CacheFolder',fullfile(testCase.Folder,'cache'), ...
                'CodeGenFolder',fullfile(testCase.Folder,'codegen'),'createDir',true) ;
            testCase.addTeardown(@() cleanup(testCase)) ;
        end
    end

    methods (Test)
        function packageContainsApplicationAndGeneratedModels(testCase)
            toolboxFile = package_toolbox(fullfile(testCase.Folder,'release')) ;
            testCase.verifyTrue(isfile(toolboxFile)) ;
            unpacked = fullfile(testCase.Folder,'unpacked') ;
            unzip(toolboxFile,unpacked) ;
            names = archiveNames(unpacked) ;
            testCase.verifyTrue(any(endsWith(names,'NonIdealReactorApp.m'))) ;
            testCase.verifyTrue(any(contains(names,'/+nirp/'))) ;
            testCase.verifyTrue(any(endsWith(names,'/simulink/NirpLibrary.slx'))) ;
            testCase.verifyTrue(any(endsWith(names,'/simulink/slblocks.m'))) ;
            [examples,~] = nirp.flowsheet.exampleNames() ;
            for i = 1:numel(examples)
                testCase.verifyTrue(any(endsWith(names, ...
                    "/simulink/examples/"+examples(i)+".slx"))) ;
                testCase.verifyTrue(any(endsWith(names, ...
                    "/simulink/examples/"+examples(i)+".sldd"))) ;
            end
            forbidden = ["/tests/","/C__/","/.git","/slprj/"] ;
            for item = forbidden
                testCase.verifyFalse(any(contains(names,item))) ;
            end
        end

        function packageHasRequiredMetadata(testCase)
            toolboxFile = package_toolbox(fullfile(testCase.Folder,'metadata')) ;
            testCase.verifyEqual(string(matlab.addons.toolbox.toolboxVersion( ...
                toolboxFile)),"0.1.0") ;
            unpacked = fullfile(testCase.Folder,'metadata-unpacked') ;
            unzip(toolboxFile,unpacked) ;
            manifests = dir(fullfile(unpacked,'**','*.xml')) ;
            text = "" ;
            for i = 1:numel(manifests)
                text = text+newline+string(fileread(fullfile( ...
                    manifests(i).folder,manifests(i).name))) ;
            end
            testCase.verifyTrue(contains(text,'Non-Ideal Reactor Plus')) ;
            testCase.verifyTrue(contains(text,'Javier Berenguer Sabater')) ;
            testCase.verifyTrue(contains(text,'R2025b')) ;
        end

        function openExampleCopiesDictionaryAndSimulates(testCase)
            destination = fullfile(testCase.Folder,'writable-example') ;
            testCase.addTeardown(@() rmpathIfPresent(destination)) ;
            modelFile = nirp.flowsheet.openExample('ex1_cstr_isothermal', ...
                'Folder',destination,'NoWindow',true) ;
            testCase.verifyTrue(isfile(modelFile)) ;
            testCase.verifyTrue(isfile(fullfile(destination, ...
                'ex1_cstr_isothermal.sldd'))) ;
            sim('ex1_cstr_isothermal') ;
            tables = nirp.flowsheet.showResults( ...
                'ex1_cstr_isothermal','NoWindow',true) ;
            testCase.verifyEqual(tables.Product.Conversion, ...
                repmat(0.5,2,1),'AbsTol',1e-9) ;
        end

        function chooserIsAtLeastTwoAndHalfTimesWider(testCase)
            root = fileparts(fileparts(mfilename('fullpath'))) ;
            source = fileread(fullfile(root,'+nirp','+flowsheet','chooseExample.m')) ;
            token = regexp(source,"'ListSize',\s*\[(\d+)\s+(\d+)\]", ...
                'tokens','once') ;
            testCase.assertNotEmpty(token) ;
            testCase.verifyGreaterThanOrEqual(str2double(token{1}),400) ;
            testCase.verifyGreaterThanOrEqual(str2double(token{2}),210) ;
        end
    end
end

function names = archiveNames(folder)
    entries = dir(fullfile(folder,'**','*')) ;
    entries = entries(~[entries.isdir]) ;
    names = "/"+replace(string(fullfile({entries.folder},{entries.name})), ...
        string(folder)+filesep,"") ;
    names = replace(names,'\','/') ;
end

function cleanup(testCase)
    bdclose('all') ;
    Simulink.data.dictionary.closeAll('-discard') ;
    evalin('base','clear nirpResults') ;
    Simulink.fileGenControl('setConfig','config',testCase.FileGenerationConfig) ;
    rmpathIfPresent(testCase.ScriptsFolder) ;
    rmpathIfPresent(testCase.SimulinkFolder) ;
end

function rmpathIfPresent(folder)
    if contains([path pathsep],[folder pathsep]), rmpath(folder) ; end
end
