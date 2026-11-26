classdef NirpOpenExampleTest < matlab.unittest.TestCase
    % NirpOpenExampleTest verifies on-demand example generation.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 17, 2026. Last update: November 4, 2026
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

        function nonIdealExamplesOpenAndMatchIndependentReferences(testCase)
            names = ["ex51_nonideal_exam_january2024"; ...
                "ex52_nonideal_second_order_series"; ...
                "ex53_nonideal_parallel_second_order"; ...
                "ex54_ideal_nonideal_side_by_side"] ;
            [catalog,descriptions] = nirp.flowsheet.exampleNames() ;
            testCase.verifyTrue(all(ismember(names,catalog))) ;
            selected = descriptions(ismember(catalog,names)) ;
            testCase.verifyTrue(all(startsWith(selected,"Non-ideal:"))) ;

            results = cell(size(names)) ;
            for i = 1:numel(names)
                destination = fullfile(testCase.Folder,char(names(i))) ;
                modelFile = nirp.flowsheet.openExample(names(i), ...
                    'Folder',destination,'NoWindow',true) ;
                testCase.verifyTrue(isfile(modelFile)) ;
                testCase.verifyTrue(isfile(fullfile(destination, ...
                    names(i)+".sldd"))) ;
                evalin('base','clear nirpResults') ;
                sim(char(names(i))) ;
                results{i} = evalin('base','nirpResults') ;
                close_system(char(names(i)),0) ;
                Simulink.data.dictionary.closeAll('-discard') ;
                rmpathIfPresent(destination) ;
            end

            expectedExam = [0.044859 0.038064 0.16512 0.24168 0.24168; ...
                0.045823 0.038935 0.18121 0.24376 0.24376] ;
            actualExam = [concentration(results{1},'Segregation product',1:5); ...
                concentration(results{1},'Maximum mixedness product',1:5)]/1000 ;
            testCase.verifyEqual(actualExam,expectedExam,'RelTol',5e-3) ;

            k = 0.05 ; tau = 2 ; initial = 10 ;
            firstSeg = cstrRtdBatchReference(initial,k,tau) ;
            secondSeg = cstrRtdBatchReference(firstSeg,k,tau) ;
            firstMm = algebraicCstrReference(initial,k,tau) ;
            secondMm = algebraicCstrReference(firstMm,k,tau) ;
            actualSeries = [concentration(results{2},'Segregation product',1); ...
                concentration(results{2},'Maximum mixedness product',1)] ;
            testCase.verifyEqual(actualSeries,[secondSeg;secondMm], ...
                'RelTol',5e-3) ;

            pfr = initial/(1+k*initial*3) ;
            cstr = algebraicCstrReference(initial,k,3) ;
            parallel = 0.25*pfr+0.75*cstr ;
            testCase.verifyEqual(concentration(results{3},'Product',1), ...
                parallel,'RelTol',5e-3) ;

            ideal = concentration(results{4},'Ideal product',1) ;
            nonIdeal = concentration(results{4},'Non-ideal product',1) ;
            testCase.verifyEqual(nonIdeal,ideal,'RelTol',1e-4) ;
        end

        function methanolExamplesOpenFromCatalog(testCase)
            names = ["ex55_methanol_exam_january2020"; ...
                "ex56_methanol_exam_january2022"] ;
            [catalog,descriptions] = nirp.flowsheet.exampleNames() ;
            testCase.verifyTrue(all(ismember(names,catalog))) ;
            selected = descriptions(ismember(catalog,names)) ;
            testCase.verifyTrue(all(startsWith(selected,"Methanol:"))) ;
            for index = 1:numel(names)
                destination = fullfile(testCase.Folder,char(names(index))) ;
                modelFile = nirp.flowsheet.openExample(names(index), ...
                    'Folder',destination,'NoWindow',true) ;
                testCase.verifyTrue(isfile(modelFile)) ;
                testCase.verifyTrue(isfile(fullfile(destination, ...
                    names(index)+".sldd"))) ;
                close_system(char(names(index)),0) ;
                Simulink.data.dictionary.closeAll('-discard') ;
                rmpathIfPresent(destination) ;
            end
        end
    end
end

function value = concentration(results,name,index)
    key = matlab.lang.makeValidName(name) ;
    stream = results.Streams.(key).streamSI ;
    values = stream.F/stream.Q ;
    value = reshape(values(index),1,[]) ;
end

function value = cstrRtdBatchReference(initial,k,tau)
    z = 1/(k*tau*initial) ;
    value = exp(z)*expint(z)/(k*tau) ;
end

function value = algebraicCstrReference(initial,k,tau)
    value = (sqrt(1+4*k*tau*initial)-1)/(2*k*tau) ;
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
