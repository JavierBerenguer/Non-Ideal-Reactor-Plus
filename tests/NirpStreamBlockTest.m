classdef NirpStreamBlockTest < matlab.unittest.TestCase
    % NirpStreamBlockTest verifies named Stream blocks and their dialog.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 9, 2026
    % =========================================================================

    properties
        Folder
        SimulinkFolder
        FileGenerationConfig
    end

    methods (TestMethodSetup)
        function setup(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture=testCase.applyFixture(TemporaryFolderFixture) ;
            testCase.Folder=fixture.Folder ;
            testCase.SimulinkFolder=fullfile(fileparts(fileparts( ...
                mfilename('fullpath'))),'simulink') ;
            addpath(testCase.Folder) ; addpath(testCase.SimulinkFolder) ;
            testCase.FileGenerationConfig=Simulink.fileGenControl('getConfig') ;
            Simulink.fileGenControl('set','CacheFolder',fullfile(testCase.Folder,'cache'), ...
                'CodeGenFolder',fullfile(testCase.Folder,'codegen'),'createDir',true) ;
            testCase.addTeardown(@() cleanup(testCase)) ;
            evalin('base','clear nirpResults') ;
        end
    end

    methods (Test)
        function feedDialogSavesMixedUnits(testCase)
            [~,dictionary]=nirp.flowsheet.new('stream_feed', ...
                nirp.pkg.examples.firstOrderLiquid(),testCase.Folder,'OpenModel',false) ;
            dialog=nirp.flowsheet.StreamDialog('stream_feed/F1','Visible','off') ;
            testCase.addTeardown(@() deleteValid(dialog)) ;
            dialog.setUnits('MolarFlow','mol/min','T',[char(176) 'C'], ...
                'P','atm','Q','L/min') ;
            dialog.setValues('MolarFlow',[60;0],'T',26.85,'P',1, ...
                'Q',60,'Phase','L') ;
            dialog.save() ;
            pkg=nirp.pkg.readDictionary(dictionary) ;
            testCase.verifyEqual(pkg.feeds(1).valuesUnit,'mol/min') ;
            testCase.verifyEqual(pkg.feeds(1).T.unit,[char(176) 'C']) ;
            testCase.verifyEqual(pkg.feeds(1).P.unit,'atm') ;
            testCase.verifyEqual(pkg.feeds(1).Q.unit,'L/min') ;
            stream=nirp.pkg.feedStream(pkg,'F1') ;
            testCase.verifyEqual(stream.F,[1;0],'AbsTol',1e-14) ;
            testCase.verifyEqual(stream.T,300,'AbsTol',1e-12) ;
            testCase.verifyEqual(stream.Q,1e-3,'AbsTol',1e-16) ;
            testCase.verifyEqual(dialog.getValues().T.origin,'specified') ;
        end

        function densityAndViscosityAreEmptyAndReadOnlyForFeed(testCase)
            nirp.flowsheet.new('optional_feed', ...
                nirp.pkg.examples.firstOrderLiquid(),testCase.Folder,'OpenModel',false) ;
            emptyDialog=nirp.flowsheet.StreamDialog('optional_feed/F1','Visible','off') ;
            testCase.addTeardown(@() deleteValid(emptyDialog)) ;
            testCase.verifyEmpty(emptyDialog.getValue('Density')) ;
            testCase.verifyEmpty(emptyDialog.getValue('Viscosity')) ;
            testCase.verifyEqual(string(emptyDialog.DensityField.Editable),"off") ;
            testCase.verifyEqual(string(emptyDialog.ViscosityField.Editable),"off") ;
            % T-131: the tips box was removed at the user's request.
            testCase.verifyEmpty(findall(emptyDialog.Figure,'Type','uitextarea')) ;
        end

        function resultDialogConvertsAndReportsState(testCase)
            files=build_examples(testCase.Folder) ;
            load_system(char(files(2))) ;
            before=nirp.flowsheet.StreamDialog( ...
                'ex2_cstr_adiabatic_cooler/CSTR outlet','Visible','off') ;
            testCase.verifyEqual(before.getValue('Status'),"Not calculated yet") ;
            delete(before) ; sim('ex2_cstr_adiabatic_cooler') ;
            middle=nirp.flowsheet.StreamDialog( ...
                'ex2_cstr_adiabatic_cooler/CSTR outlet','Visible','off') ;
            testCase.addTeardown(@() deleteValid(middle)) ;
            testCase.verifyEqual(middle.getValue('T'),550,'AbsTol',1e-6) ;
            flow=middle.getValue('MolarFlow') ;
            testCase.verifyEqual(flow(1),0.5,'AbsTol',1e-9) ;
            middle.setUnits('T',[char(176) 'C'],'MolarFlow','mol/min') ;
            testCase.verifyEqual(middle.getValue('T'),276.85,'AbsTol',1e-6) ;
            flow=middle.getValue('MolarFlow') ;
            testCase.verifyEqual(flow(1),30,'AbsTol',1e-8) ;
            testCase.verifyEqual(middle.getValues().T.origin,'calculated') ;
            testCase.verifyEmpty(middle.getValue('Density')) ;
            testCase.verifyEmpty(middle.getValue('Viscosity')) ;
            testCase.verifyEqual(string(middle.DensityField.Editable),"off") ;
            testCase.verifyEqual(string(middle.ViscosityField.Editable),"off") ;
            testCase.verifyEmpty(findall(middle.Figure,'Type','uitextarea')) ;
            product=nirp.flowsheet.StreamDialog( ...
                'ex2_cstr_adiabatic_cooler/Product','Visible','off') ;
            testCase.addTeardown(@() deleteValid(product)) ;
            testCase.verifyEqual(product.getValue('T'),300,'AbsTol',1e-8) ;
            testCase.verifyEqual(product.getValue('Conversion'),0.5,'AbsTol',1e-9) ;
            testCase.verifyEmpty(product.getValue('Density')) ;
            testCase.verifyEmpty(product.getValue('Viscosity')) ;
            testCase.verifyEqual(string(product.DensityField.Editable),"off") ;
            testCase.verifyEqual(string(product.ViscosityField.Editable),"off") ;
            results=evalin('base','nirpResults') ;
            results.Streams.CSTROutlet.status=-1 ;
            results.Streams.CSTROutlet.streamSI.status=-1 ;
            assignin('base','nirpResults',results) ; delete(middle) ;
            failed=nirp.flowsheet.StreamDialog( ...
                'ex2_cstr_adiabatic_cooler/CSTR outlet','Visible','off') ;
            testCase.addTeardown(@() deleteValid(failed)) ;
            % T-132: a failed stream in a converged run is an error (A1).
            testCase.verifyEqual(failed.getValue('Status'), ...
                "Error: Stream calculation failed.") ;
        end

        function directFunctionalConnectionWarns(testCase)
            NirpStreamBlockTest.createModel(testCase.Folder,'missing_stream') ;
            addSystem('missing_stream','CSTR','nirp.blocks.CSTR',[100 100 220 160]) ;
            addSystem('missing_stream','Cooler','nirp.blocks.Heater',[300 100 420 160]) ;
            add_line('missing_stream','CSTR/1','Cooler/1') ;
            testCase.verifyWarning(@() nirp.flowsheet.configure( ...
                'missing_stream'),'nirp:flowsheet:missingStream') ;
        end

        function topologySupportsArbitraryPortCounts(testCase)
            NirpStreamBlockTest.createModel(testCase.Folder,'ports_model') ;
            addSystem('ports_model','Splitter','nirp.blocks.Splitter',[100 150 210 250], ...
                'Fractions','[0.2 0.3 0.5]') ;
            addSystem('ports_model','Mixer','nirp.blocks.Mixer',[500 150 610 250], ...
                'NumInputs','3') ;
            for i=1:3
                name=sprintf('Branch %d',i) ;
                addSystem('ports_model',name,'nirp.blocks.Stream', ...
                    [300 70+100*i 420 115+100*i],'Role','Intermediate') ;
                add_line('ports_model',sprintf('Splitter/%d',i),[name '/1']) ;
                add_line('ports_model',[name '/1'],sprintf('Mixer/%d',i)) ;
            end
            graph=nirp.flowsheet.topology('ports_model') ;
            testCase.verifyNumElements(graph.Units.Splitter.Outputs,3) ;
            testCase.verifyNumElements(graph.Units.Mixer.Inputs,3) ;
            testCase.verifyEqual(string(graph.Units.Splitter.Outputs{3}),"Branch 3") ;
            testCase.verifyEqual(string(graph.Units.Mixer.Inputs{2}),"Branch 2") ;
        end

        function exampleTopologyAndRenameAreConsistent(testCase)
            files=build_examples(testCase.Folder) ; load_system(char(files(4))) ;
            graph=nirp.flowsheet.topology('ex4_problem40b_parallel') ;
            testCase.verifyNumElements(graph.Units.Splitter.Outputs,2) ;
            testCase.verifyNumElements(graph.Units.Mixer.Inputs,2) ;
            testCase.verifyEqual(string(graph.Units.CSTR1.Inputs{1}),"Branch 1") ;
            testCase.verifyEqual(string(graph.Units.CSTR1.Outputs{1}),"CSTR 1 outlet") ;
            close_system('ex4_problem40b_parallel',0) ;
            [~,dictionary]=nirp.flowsheet.new('rename_stream', ...
                nirp.pkg.examples.firstOrderLiquid(),testCase.Folder,'OpenModel',false) ;
            set_param('rename_stream/F1','Name','Fresh feed') ;
            pkg=nirp.pkg.readDictionary(dictionary) ;
            testCase.verifyEqual(string(pkg.feeds(1).name),"Fresh feed") ;
        end

        function streamSpecsRoundTripAndExamplesFollowConvention(testCase)
            pkg=nirp.pkg.examples.firstOrderLiquid() ; pkg.streamSpecs=struct() ;
            nirp.pkg.validate(pkg) ;
            pkg.streamSpecs.Product.T=struct('value',300,'unit','K', ...
                'origin','specified') ;
            nirp.pkg.validate(pkg) ; dictionary=fullfile(testCase.Folder,'specs.sldd') ;
            nirp.pkg.writeDictionary(pkg,dictionary) ; actual=nirp.pkg.readDictionary(dictionary) ;
            testCase.verifyEqual(actual.streamSpecs,pkg.streamSpecs) ;
            files=build_examples(testCase.Folder) ;
            for i=1:numel(files)
                [~,name]=fileparts(char(files(i))) ; load_system(char(files(i))) ;
                graph=nirp.flowsheet.topology(name) ;
                testCase.verifyEmpty(graph.MissingStreamConnections,name) ;
                close_system(name,0) ;
            end
        end
    end

    methods (Static,Access=private)
        function createModel(folder,name)
            pkg=nirp.pkg.examples.firstOrderLiquid() ;
            nirp.pkg.writeDictionary(pkg,fullfile(folder,[name '.sldd'])) ;
            new_system(name) ; save_system(name,fullfile(folder,[name '.slx'])) ;
            set_param(name,'DataDictionary',[name '.sldd']) ;
        end
    end
end

function addSystem(model,name,className,position,varargin)
    add_block('simulink/User-Defined Functions/MATLAB System',[model '/' name], ...
        'System',className,'Position',position,varargin{:}) ;
end
function cleanup(testCase)
    bdclose('all') ; Simulink.data.dictionary.closeAll('-discard') ;
    figures=findall(groot,'Type','Figure');if ~isempty(figures),delete(figures);end
    evalin('base','clear nirpResults') ;
    Simulink.fileGenControl('setConfig','config',testCase.FileGenerationConfig) ;
    removePath(testCase.Folder) ; removePath(testCase.SimulinkFolder) ;
end
function removePath(folder),if contains([path pathsep],[folder pathsep]),rmpath(folder);end,end
function deleteValid(value),try,if isvalid(value),delete(value);end;catch,end,end
