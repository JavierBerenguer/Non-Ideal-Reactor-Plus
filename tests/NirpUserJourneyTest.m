classdef NirpUserJourneyTest < matlab.uitest.TestCase
%NIRPUSERJOURNEYTEST User-level journeys from empty library blocks.
%   Visible edit fields, selectors, and buttons use matlab.uitest. UITable
%   cells use their real CellEditCallback with the payload a real uitable
%   commits: text when the cell already shows text (E-015). The gas feed
%   journeys type into the cells with matlab.uitest.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 15, 2026. Last update: October 16, 2026
% =========================================================================
    properties
        Folder
        LibraryFile
        FileGenerationConfig
    end

    methods (TestClassSetup)
        function buildLibrary(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture=testCase.applyFixture(TemporaryFolderFixture);testCase.Folder=fixture.Folder;
            repository=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(repository,'simulink'));addpath(testCase.Folder);
            testCase.FileGenerationConfig=Simulink.fileGenControl('getConfig');
            Simulink.fileGenControl('set','CacheFolder',fullfile(testCase.Folder,'cache'), ...
                'CodeGenFolder',fullfile(testCase.Folder,'codegen'),'createDir',true);
            testCase.LibraryFile=build_library(testCase.Folder);
            testCase.addTeardown(@()cleanupClass(testCase,repository));
        end
    end

    methods (TestMethodTeardown)
        function closeModels(~)
            bdclose('all');Simulink.data.dictionary.closeAll('-discard');
            evalin('base','clear nirpResults');
            figures=findall(groot,'Type','Figure');if ~isempty(figures),delete(figures);end
        end
    end

    methods (Test)
        function j1CreatesReactiveSystemAndFlowsheetFromControls(testCase)
            dialog=nirp.flowsheet.ReactiveSystemDialog('Visible','on');
            testCase.addTeardown(@()deleteValid(dialog));drawnow;
            tabs=findall(dialog.Figure,'Type','uitabgroup');
            tabs.SelectedTab=findTab(dialog.Figure,'General');drawnow;
            typeValue(testCase,dialog.ComponentCountSpinner,2);
            editCell(dialog.GeneralComponentTable,1,1,'A');editCell(dialog.GeneralComponentTable,1,2,18);
            editCell(dialog.GeneralComponentTable,2,1,'B');editCell(dialog.GeneralComponentTable,2,2,28);
            editCell(dialog.StoichTable,1,1,-1);editCell(dialog.StoichTable,1,2,1);

            tabs.SelectedTab=findTab(dialog.Figure,'Kinetics');drawnow;
            testCase.choose(dialog.KineticTypeDropDown,'powerlaw');
            typeValue(testCase,dialog.K0Field,0.1);typeValue(testCase,dialog.EaField,0);
            editCell(dialog.OrdersField,1,2,1);editCell(dialog.OrdersField,2,2,0);

            tabs.SelectedTab=findTab(dialog.Figure,'Thermodynamics');drawnow;
            editCell(dialog.ThermoComponentTable,1,2,'constant');editCell(dialog.ThermoComponentTable,1,3,'75');
            editCell(dialog.ThermoComponentTable,2,2,'constant');editCell(dialog.ThermoComponentTable,2,3,'80');
            editCell(dialog.ThermoReactionTable,1,2,0);typeValue(testCase,dialog.TrefField,298.15);

            tabs.SelectedTab=findTab(dialog.Figure,'Initial feed');drawnow;
            feed={'F1','L',300,'K',101325,'Pa','molarFlows','1 0','mol/s',0.001,'m^3/s'};
            for column=1:numel(feed),editCell(dialog.FeedTable,1,column,feed{column});end
            modelFile=fullfile(testCase.Folder,'journey_new.slx');
            dialog.FileChooser=@(~,~,~)deal('journey_new.slx',testCase.Folder);
            button=findall(dialog.Figure,'Type','uibutton','Text','Create flowsheet...');
            testCase.press(button);drawnow;
            testCase.verifyTrue(isfile(modelFile));
            testCase.verifyTrue(isfile(fullfile(testCase.Folder,'journey_new.sldd')));
            saved=nirp.flowsheet.ReactiveSystemDialog('Mode','edit','Model','journey_new','Visible','on');drawnow;
            savedTabs=findall(saved.Figure,'Type','uitabgroup');savedTabs.SelectedTab=findTab(saved.Figure,'Initial feed');drawnow;
            capture(saved.Figure,'j1_reactive_system');delete(saved);
        end

        function j2NewUnconnectedGasFeedPersistsValuesAndOrigins(testCase)
            package=threeComponentPackage();createBaseModel(testCase,'journey_gas',package);
            addLibraryBlock(testCase,'Stream','journey_gas/New Gas',[220 100 330 160]);
            dialog=nirp.flowsheet.StreamDialog('journey_gas/New Gas','Visible','on');drawnow;
            testCase.choose(dialog.RoleDropDown,'Feed');testCase.choose(dialog.PhaseDropDown,'G');
            testCase.type(dialog.ComponentTable,[1 4],'0.6');drawnow;testCase.type(dialog.ComponentTable,[3 4],'0.4');drawnow;
            typeValue(testCase,dialog.PressureField,2.5e6);typeValue(testCase,dialog.TemperatureField,623.15);
            typeValue(testCase,dialog.VolumetricFlowField,0.01);
            testCase.verifySubstring(dialog.StatusLabel.Text,'Fully specified');capture(dialog.Figure,'j2_gas_feed');
            figureHandle=dialog.Figure;testCase.press(dialog.ApplyButton);testCase.press(dialog.OKButton);drawnow;
            testCase.verifyFalse(isvalid(figureHandle));

            reopened=nirp.flowsheet.StreamDialog('journey_gas/New Gas','Visible','off');
            testCase.addTeardown(@()deleteValid(reopened));
            specs=nirp.dof.readSpecs('journey_gas/New Gas');
            testCase.verifyEqual(sort(string(fieldnames(specs))),sort(["P";"Q";"T";"x1";"x3"]));
            origins=string(cellstr(reopened.DataModel.MoleFraction.origin));
            testCase.verifyEqual(origins,["specified";"calculated";"specified"]);
            stored=nirp.pkg.readDictionary(nirp.flowsheet.modelDictionary('journey_gas'));
            testCase.verifyTrue(any(string({stored.feeds.name})=="New Gas"));
        end

        function j2bTypedFractionsAfterPTQWithoutMolecularWeights(testCase)
            % Example 25, F2 (E-015): P, T and Q first, then the fractions typed into text cells
            package=nirp.pkg.examples.problem38ParallelGas();createBaseModel(testCase,'journey_f2',package);
            addLibraryBlock(testCase,'Stream','journey_f2/F2',[220 100 330 160]);
            dialog=nirp.flowsheet.StreamDialog('journey_f2/F2','Visible','on');drawnow;
            testCase.choose(dialog.RoleDropDown,'Feed');testCase.choose(dialog.PhaseDropDown,'G');
            testCase.verifyEqual(size(dialog.ComponentTable.Data,2),4);
            testCase.choose(dialog.PressureUnitDropDown,'atm');testCase.choose(dialog.TemperatureUnitDropDown,[char(176) 'C']);
            testCase.choose(dialog.VolumetricFlowUnitDropDown,'L/h');
            typeValue(testCase,dialog.PressureField,25);typeValue(testCase,dialog.TemperatureField,350);
            typeValue(testCase,dialog.VolumetricFlowField,320000);
            testCase.verifyTrue(ischar(dialog.ComponentTable.Data{1,4}));
            testCase.type(dialog.ComponentTable,[1 4],'0.5');drawnow;testCase.type(dialog.ComponentTable,[1 4],'0.6');drawnow;
            testCase.type(dialog.ComponentTable,[3 4],'0.4');drawnow;
            testCase.verifySubstring(dialog.StatusLabel.Text,'Fully specified');
            values=dialog.getValues();testCase.verifyEqual(values.MoleFraction.value(:),[0.6;0;0.4],'AbsTol',1e-12);
            total=25*101325*(320/3600)/(8.314*623.15);
            testCase.verifyEqual(sum(values.MolarFlow.value(:)),UnitConverterHelper.convertFromSI('MolarFlow',total,values.MolarFlow.unit),'RelTol',1e-3);
            testCase.press(dialog.OKButton);drawnow;
            reopened=nirp.flowsheet.StreamDialog('journey_f2/F2','Visible','off');
            testCase.addTeardown(@()deleteValid(reopened));
            testCase.verifySubstring(reopened.StatusLabel.Text,'Fully specified');
            testCase.verifyEqual(reopened.DataModel.MoleFraction.value(:),[0.6;0;0.4],'AbsTol',1e-12);
        end

        function j3LiquidConcentrationAndMassBasesAreEnteredInCells(testCase)
            package=threeComponentPackage();createBaseModel(testCase,'journey_liquid',package);
            addLibraryBlock(testCase,'Stream','journey_liquid/Concentration Feed',[220 70 350 130]);
            addLibraryBlock(testCase,'Stream','journey_liquid/Mass Feed',[220 190 350 250]);
            configureLiquidByConcentration(testCase,'journey_liquid/Concentration Feed');
            configureLiquidByMass(testCase,'journey_liquid/Mass Feed');
            stored=nirp.pkg.readDictionary(nirp.flowsheet.modelDictionary('journey_liquid'));
            testCase.verifyTrue(all(ismember(["Concentration Feed" "Mass Feed"],string({stored.feeds.name}))));
        end

        function j4FeedCstrProductRunsFromEmptyBlocks(testCase)
            createBaseModel(testCase,'journey_cstr',nirp.pkg.examples.firstOrderLiquid());
            set_param('journey_cstr/F1','Position',[20 100 120 160]);
            addLibraryBlock(testCase,'CSTR','journey_cstr/CSTR',[220 90 340 170]);
            addLibraryBlock(testCase,'Stream','journey_cstr/Product',[430 100 540 160]);
            add_line('journey_cstr','F1/1','CSTR/1');add_line('journey_cstr','CSTR/1','Product/1');
            product=nirp.flowsheet.StreamDialog('journey_cstr/Product','Visible','on');drawnow;
            testCase.choose(product.RoleDropDown,'Product');testCase.press(product.ApplyButton);delete(product);
            reactor=nirp.flowsheet.ReactorDialog('journey_cstr/CSTR','Visible','on');drawnow;
            isothermal=findall(reactor.Figure,'Type','uiradiobutton','Text','Isothermal');testCase.press(isothermal);
            typeValue(testCase,reactor.TauField,100);testCase.verifySubstring(reactor.StatusLabel.Text,'Fully specified');
            capture(reactor.Figure,'j4_cstr');pressButton(testCase,reactor.Figure,'Apply');delete(reactor);
            nirp.flowsheet.configure('journey_cstr');sim('journey_cstr');
            results=evalin('base','nirpResults');testCase.verifyGreaterThan(sum(results.Streams.Product.streamSI.F),0);
            testCase.verifyGreaterThanOrEqual(results.Streams.Product.conversion,0);
            testCase.verifyLessThanOrEqual(results.Streams.Product.conversion,1);
        end

        function j5SplitterFractionsOutputFlowAndConflicts(testCase)
            createBaseModel(testCase,'journey_splitter',nirp.pkg.examples.firstOrderLiquid());
            addLibraryBlock(testCase,'Splitter','journey_splitter/Splitter',[190 90 310 190]);
            splitter=nirp.flowsheet.SplitterDialog('journey_splitter/Splitter','Visible','on');drawnow;
            pressButton(testCase,splitter.Figure,'Add outlet');
            editCell(splitter.FractionTable,1,2,0.2);editCell(splitter.FractionTable,2,2,0.3);
            testCase.verifyEqual(str2double(splitter.FractionTable.Data{3,2}),0.5,'AbsTol',1e-12);
            pressButton(testCase,splitter.Figure,'Apply');delete(splitter);
            addLibraryBlock(testCase,'Stream','journey_splitter/Out 1',[390 20 500 80]);
            addLibraryBlock(testCase,'Stream','journey_splitter/Out 2',[390 115 500 175]);
            addLibraryBlock(testCase,'Stream','journey_splitter/Out 3',[390 215 500 275]);
            set_param('journey_splitter/Out 1','Role','Product');set_param('journey_splitter/Out 2','Role','Product');set_param('journey_splitter/Out 3','Role','Product');
            add_line('journey_splitter','F1/1','Splitter/1');add_line('journey_splitter','Splitter/1','Out 1/1');
            add_line('journey_splitter','Splitter/2','Out 2/1');add_line('journey_splitter','Splitter/3','Out 3/1');
            splitter=nirp.flowsheet.SplitterDialog('journey_splitter/Splitter','Visible','on');drawnow;
            capture(splitter.Figure,'j5_splitter');
            editCell(splitter.FractionTable,1,2,[]);
            pressButton(testCase,splitter.Figure,'Apply');
            testCase.verifyTrue(isvalid(splitter));
            testCase.verifySubstring(splitter.StatusLabel.Text,'1 specification missing');
            storedFractions=str2num(get_param( ...
                'journey_splitter/Splitter','Fractions')); %#ok<ST2NM>
            testCase.verifyTrue(isnan(storedFractions(1)));
            testCase.verifyEqual(storedFractions(2),0.3,'AbsTol',1e-12);
            testCase.verifyTrue(isnan(storedFractions(3)));
            delete(splitter);
            feed=nirp.pkg.feedStream(nirp.pkg.examples.firstOrderLiquid(),"F1");
            stream=nirp.flowsheet.StreamDialog('journey_splitter/Out 1','Visible','on');drawnow;
            typeValue(testCase,stream.SpecificationTotalFlowField,0.2*sum(feed.F));
            testCase.verifySubstring(stream.StatusLabel.Text,'Fully specified');
            testCase.press(stream.OKButton);testCase.verifyFalse(isvalid(stream));
            producer=nirp.flowsheet.SplitterDialog('journey_splitter/Splitter','Visible','on');drawnow;
            testCase.verifyEqual(producer.DataModel.Fractions.value(1),0.2,'RelTol',1e-12);
            testCase.verifyEqual(producer.DataModel.Fractions.origin(1),"calculated");
            testCase.verifyEqual(producer.DataModel.Fractions.value(3),0.5,'RelTol',1e-12);
            testCase.verifySubstring(producer.StatusLabel.Text,'Fully specified');
            delete(producer);
        end

        function j6SeparatorMixesRecoveryAndTopFlowSpecifications(testCase)
            package=nirp.pkg.examples.firstOrderLiquid();package.feeds(1).basis="molarFlows";package.feeds(1).values=[1 1];package.feeds(1).valuesUnit="mol/s";nirp.pkg.validate(package);
            createBaseModel(testCase,'journey_separator',package);
            addLibraryBlock(testCase,'Separator','journey_separator/Separator',[200 90 330 190]);
            addLibraryBlock(testCase,'Stream','journey_separator/Top',[410 50 520 110]);
            addLibraryBlock(testCase,'Stream','journey_separator/Bottom',[410 180 520 240]);
            set_param('journey_separator/Top','Role','Product');set_param('journey_separator/Bottom','Role','Product');
            add_line('journey_separator','F1/1','Separator/1');add_line('journey_separator','Separator/1','Top/1');add_line('journey_separator','Separator/2','Bottom/1');
            dialog=nirp.flowsheet.SeparatorDialog('journey_separator/Separator','Visible','on');drawnow;
            editCell(dialog.RecoveryTable,1,2,0.4);editCell(dialog.RecoveryTable,2,3,0.3);
            testCase.verifySubstring(dialog.StatusLabel.Text,'Fully specified');capture(dialog.Figure,'j6_separator');pressButton(testCase,dialog.Figure,'OK');
            nirp.flowsheet.configure('journey_separator');sim('journey_separator');results=evalin('base','nirpResults');
            testCase.verifyEqual(results.Streams.Top.streamSI.F,[0.4;0.3],'AbsTol',1e-12);
        end

        function j7HeaterJacketAndHeatExchangeReactorRun(testCase)
            createBaseModel(testCase,'journey_heat',nirp.pkg.examples.firstOrderLiquid());
            addLibraryBlock(testCase,'Heater','journey_heat/Heater',[170 80 290 150]);
            addLibraryBlock(testCase,'Stream','journey_heat/Heated',[330 90 430 145]);set_param('journey_heat/Heated','Role','Intermediate');
            addLibraryBlock(testCase,'CSTR','journey_heat/CSTR',[480 75 600 155]);
            addLibraryBlock(testCase,'Stream','journey_heat/Product',[680 90 790 150]);set_param('journey_heat/Product','Role','Product');
            addLibraryBlock(testCase,'Jacket','journey_heat/Jacket',[455 230 585 300]);
            add_line('journey_heat','F1/1','Heater/1');add_line('journey_heat','Heater/1','Heated/1');add_line('journey_heat','Heated/1','CSTR/1');add_line('journey_heat','CSTR/1','Product/1');
            heater=nirp.flowsheet.HeaterDialog('journey_heat/Heater','Visible','on');drawnow;
            typeValue(testCase,heater.TemperatureChangeField,10);typeValue(testCase,heater.PressureDropField,0);
            testCase.verifySubstring(heater.StatusLabel.Text,'Fully specified');capture(heater.Figure,'j7_heater');pressButton(testCase,heater.Figure,'OK');
            reactor=nirp.flowsheet.ReactorDialog('journey_heat/CSTR','Visible','on');drawnow;
            heat=findall(reactor.Figure,'Type','uiradiobutton','Text','Heat exchange');testCase.press(heat);typeValue(testCase,reactor.TauField,100);
            testCase.verifySubstring(reactor.StatusLabel.Text,'Fully specified');pressButton(testCase,reactor.Figure,'Apply');delete(reactor);
            add_line('journey_heat','Jacket/1','CSTR/2');
            jacket=nirp.flowsheet.JacketDialog('journey_heat/Jacket','Visible','on');drawnow;testCase.choose(jacket.ModeDropDown,'Utility (U*A)');
            typeValue(testCase,jacket.UAField,1000);typeValue(testCase,jacket.AField,5);typeValue(testCase,jacket.UtilityTinField,290);
            testCase.verifySubstring(jacket.StatusLabel.Text,'Fully specified');capture(jacket.Figure,'j7_jacket');pressButton(testCase,jacket.Figure,'OK');
            nirp.flowsheet.configure('journey_heat');sim('journey_heat');results=evalin('base','nirpResults');
            testCase.verifyEqual(results.Streams.Heated.streamSI.T-results.Streams.F1.streamSI.T,10,'AbsTol',1e-10);
        end

        function j8RecycleWegsteinAndNestedAdjustRun(testCase)
            buildAdjustRecycleFromLibrary(testCase,'journey_recycle');
            recycle=nirp.flowsheet.RecycleDialog('journey_recycle/Recycle','Visible','on');drawnow;
            testCase.choose(recycle.MethodDropDown,'Wegstein');typeValue(testCase,recycle.ToleranceField,1e-8);
            typeValue(testCase,recycle.QMinField,-1000);typeValue(testCase,recycle.QMaxField,0);typeValue(testCase,recycle.AccelerationField,5);
            testCase.choose(recycle.InitialGuessDropDown,'Feed');testCase.choose(recycle.FeedDropDown,'F1');
            testCase.verifySubstring(recycle.StatusLabel.Text,'Fully specified');capture(recycle.Figure,'j8_recycle');pressButton(testCase,recycle.Figure,'OK');
            adjust=nirp.flowsheet.AdjustDialog('journey_recycle/Adjust','Visible','on');drawnow;
            testCase.choose(adjust.TargetVariableDropDown,'Conversion');typeValue(testCase,adjust.KeyComponentField,'A');typeValue(testCase,adjust.ReferenceFeedField,'F1');
            testCase.choose(adjust.TargetUnitDropDown,'as entered');testCase.choose(adjust.ParameterUnitDropDown,'m^3');
            typeValue(testCase,adjust.TargetValueField,0.5);typeValue(testCase,adjust.InitialValueField,0.1);typeValue(testCase,adjust.MinValueField,0.001);typeValue(testCase,adjust.MaxValueField,1);
            typeValue(testCase,adjust.ToleranceField,1e-6);typeValue(testCase,adjust.DampingField,0.5);testCase.choose(adjust.StrategyDropDown,'Nested');
            testCase.verifySubstring(adjust.StatusLabel.Text,'Fully specified');capture(adjust.Figure,'j8_adjust');pressButton(testCase,adjust.Figure,'OK');
            nirp.flowsheet.configure('journey_recycle');sim('journey_recycle');
            tables=nirp.flowsheet.showResults('journey_recycle','NoWindow',true);
            testCase.verifyEqual(tables.Recycles.Converged,1);testCase.verifyEqual(tables.Adjust.Converged,1);
            testCase.verifyEqual(string(get_param('journey_recycle/Adjust','Strategy')),"Nested");
        end

        function j9SavedExamplesPersistKineticsAndRun(testCase)
            names=["ex1_cstr_isothermal" "ex23_problem23_butane_isomerization"];
            files=build_examples(testCase.Folder,names);
            for i=1:numel(files)
                [~,model]=fileparts(files(i));load_system(files(i));dialog=nirp.flowsheet.ReactiveSystemDialog('Mode','edit','Model',model,'Visible','on');drawnow;
                tabs=findall(dialog.Figure,'Type','uitabgroup');tabs.SelectedTab=findTab(dialog.Figure,'Kinetics');drawnow;
                old=str2double(dialog.K0Field.Value);typeValue(testCase,dialog.K0Field,old*1.001);capture(dialog.Figure,['j9_' char(names(i))]);
                figureHandle=dialog.Figure;pressButton(testCase,figureHandle,'OK');testCase.verifyFalse(isvalid(figureHandle));
                reopened=nirp.flowsheet.ReactiveSystemDialog('Mode','edit','Model',model,'Visible','off');
                testCase.verifyEqual(str2double(reopened.K0Field.Value),old*1.001,'RelTol',1e-12);delete(reopened);sim(model);
                close_system(model,0);Simulink.data.dictionary.closeAll('-discard');
            end
        end

        function j9bPropagationUpdatesAndStopsAtIncompleteBlock(testCase)
            createBaseModel(testCase,'journey_propagation',nirp.pkg.examples.firstOrderLiquid());
            addLibraryBlock(testCase,'Splitter','journey_propagation/Splitter',[190 80 300 170]);
            addLibraryBlock(testCase,'Stream','journey_propagation/Out 1',[360 35 470 95]);
            addLibraryBlock(testCase,'Stream','journey_propagation/Out 2',[360 150 470 210]);
            addLibraryBlock(testCase,'Heater','journey_propagation/Incomplete Heater',[520 140 650 215]);
            addLibraryBlock(testCase,'Stream','journey_propagation/Waiting Product',[710 150 830 210]);
            set_param('journey_propagation/Out 1','Role','Product');set_param('journey_propagation/Out 2','Role','Intermediate');
            set_param('journey_propagation/Waiting Product','Role','Product');
            add_line('journey_propagation','F1/1','Splitter/1');add_line('journey_propagation','Splitter/1','Out 1/1');
            add_line('journey_propagation','Splitter/2','Out 2/1');add_line('journey_propagation','Out 2/1','Incomplete Heater/1');
            add_line('journey_propagation','Incomplete Heater/1','Waiting Product/1');
            set_param('journey_propagation/Splitter','Fractions','[0.4 0.6]');
            first=nirp.flowsheet.propagate('journey_propagation');
            testCase.verifyEqual(first.Streams.Out1.status,'calculated');testCase.verifyEqual(first.Streams.Out2.status,'calculated');
            testCase.verifyEqual(first.Streams.WaitingProduct.status,'waiting');
            testCase.verifySubstring(first.Streams.WaitingProduct.reason,'waiting for');
            initial=first.Streams.Out1.streamSI.T;feed=nirp.flowsheet.StreamDialog('journey_propagation/F1','Visible','on');drawnow;
            typeValue(testCase,feed.TemperatureField,feed.TemperatureField.Value+10);testCase.press(feed.ApplyButton);delete(feed);
            second=nirp.flowsheet.preview('get','journey_propagation');
            testCase.verifyEqual(second.Streams.Out1.streamSI.T,initial+10,'AbsTol',1e-12);
            updated=nirp.flowsheet.StreamDialog('journey_propagation/Out 1','Visible','on');drawnow;
            capture(updated.Figure,'j9b_updated_output');delete(updated);
            waiting=nirp.flowsheet.StreamDialog('journey_propagation/Waiting Product','Visible','on');drawnow;
            testCase.verifySubstring(waiting.StatusLabel.Text,'Waiting for:');testCase.verifySubstring(waiting.StatusLabel.Text,'Outlet temperature');
            testCase.verifyFalse(contains(waiting.StatusLabel.Text,'T_out'));testCase.verifyFalse(contains(waiting.StatusLabel.Text,'dT'));
            capture(waiting.Figure,'j9b_waiting_output');delete(waiting);
        end

        function j10CancelConflictAndApplySemantics(testCase)
            createBaseModel(testCase,'journey_semantics',nirp.pkg.examples.firstOrderLiquid());
            addLibraryBlock(testCase,'Splitter','journey_semantics/Splitter',[220 90 340 180]);
            original=get_param('journey_semantics/Splitter','Fractions');
            cancelled=nirp.flowsheet.SplitterDialog('journey_semantics/Splitter','Visible','on');drawnow;
            editCell(cancelled.FractionTable,1,2,0.8);pressButton(testCase,cancelled.Figure,'Cancel');
            testCase.verifyEqual(get_param('journey_semantics/Splitter','Fractions'),original);
            conflict=nirp.flowsheet.SplitterDialog('journey_semantics/Splitter','Visible','on');drawnow;
            editCell(conflict.FractionTable,1,2,0.8);editCell(conflict.FractionTable,2,2,0.8);
            figureHandle=conflict.Figure;pressButton(testCase,figureHandle,'OK');drawnow;
            testCase.verifyTrue(isvalid(figureHandle));testCase.verifySubstring(conflict.StatusLabel.Text,'Conflict');
            capture(conflict.Figure,'j10_conflict');
            figureHandle.Visible='off';drawnow;
            editCell(conflict.FractionTable,2,2,0.2);apply=findall(figureHandle,'Type','uibutton','Text','Apply');feval(apply.ButtonPushedFcn,apply,[]);drawnow;
            testCase.verifyTrue(isvalid(figureHandle));testCase.verifyEqual(evalin('base','exist(''nirpResults'',''var'')'),0);
            delete(conflict);
        end
    end
end

function configureLiquidByConcentration(testCase,path)
    dialog=nirp.flowsheet.StreamDialog(path,'Visible','on');drawnow;testCase.choose(dialog.RoleDropDown,'Feed');
    for i=1:3,editCell(dialog.ComponentTable,i,3,100*i);end
    typeValue(testCase,dialog.VolumetricFlowField,0.001);typeValue(testCase,dialog.TemperatureField,300);typeValue(testCase,dialog.PressureField,101325);
    testCase.verifySubstring(dialog.StatusLabel.Text,'Fully specified');capture(dialog.Figure,'j3_concentration_feed');testCase.press(dialog.OKButton);drawnow;
end

function configureLiquidByMass(testCase,path)
    dialog=nirp.flowsheet.StreamDialog(path,'Visible','on');drawnow;testCase.choose(dialog.RoleDropDown,'Feed');
    editCell(dialog.ComponentTable,1,6,0.2);editCell(dialog.ComponentTable,3,6,0.3);
    typeValue(testCase,dialog.TotalMassFlowField,0.1);typeValue(testCase,dialog.VolumetricFlowField,0.001);
    typeValue(testCase,dialog.TemperatureField,300);typeValue(testCase,dialog.PressureField,101325);
    testCase.verifySubstring(dialog.StatusLabel.Text,'Fully specified');capture(dialog.Figure,'j3_mass_feed');testCase.press(dialog.OKButton);drawnow;
end

function createBaseModel(testCase,name,package)
    nirp.flowsheet.new(name,package,testCase.Folder,'OpenModel',false);load_system(fullfile(testCase.Folder,[name '.slx']));
end

function addLibraryBlock(testCase,source,destination,position)
    if ~bdIsLoaded('NirpLibrary'),load_system(testCase.LibraryFile);end
    add_block(['NirpLibrary/' source],destination,'Position',position);
end

function package=threeComponentPackage()
    package=nirp.pkg.examples.firstOrderLiquid();package.components(1).Mw=18;package.components(2).Mw=28;extra=package.components(end);extra.name="Inert";extra.Mw=40;
    package.components(end+1)=extra;package.reactions.stoich(:,end+1)=0;
    for i=1:numel(package.reactions.kinetics),package.reactions.kinetics(i).orders(end+1)=0;if ~isempty(package.reactions.kinetics(i).reverse),package.reactions.kinetics(i).reverse.orders(end+1)=0;end,end
    for i=1:numel(package.feeds),package.feeds(i).values=[1 1 1];package.feeds(i).basis="molarFlows";package.feeds(i).valuesUnit="mol/s";end
    nirp.pkg.validate(package);
end

function buildAdjustRecycleFromLibrary(testCase,name)
    createBaseModel(testCase,name,nirp.pkg.examples.firstOrderLiquid());set_param([name '/F1'],'Position',[20 140 100 195]);
    addLibraryBlock(testCase,'Mixer',[name '/Mixer'],[140 120 240 205]);
    addLibraryBlock(testCase,'Stream',[name '/Mixed'],[265 135 350 190]);set_param([name '/Mixed'],'Role','Intermediate');
    addLibraryBlock(testCase,'CSTR',[name '/CSTR'],[390 120 500 200]);set_param([name '/CSTR'],'HeatMode','Isothermal','VSource','Input port');
    addLibraryBlock(testCase,'Stream',[name '/Reactor Out'],[520 135 610 190]);set_param([name '/Reactor Out'],'Role','Intermediate');
    addLibraryBlock(testCase,'Separator',[name '/Separator'],[650 110 760 205]);set_param([name '/Separator'],'Recovery','[1 1]');
    addLibraryBlock(testCase,'Stream',[name '/Separator Top'],[790 100 890 155]);set_param([name '/Separator Top'],'Role','Intermediate');
    addLibraryBlock(testCase,'Splitter',[name '/Splitter'],[930 85 1040 185]);set_param([name '/Splitter'],'Fractions','[0.5 0.5]');
    addLibraryBlock(testCase,'Stream',[name '/Purge'],[1080 45 1170 100]);set_param([name '/Purge'],'Role','Intermediate');
    addLibraryBlock(testCase,'Adjust',[name '/Adjust'],[1210 45 1330 105]);
    addLibraryBlock(testCase,'Stream',[name '/Recycle Stream'],[850 220 960 275]);set_param([name '/Recycle Stream'],'Role','Intermediate');
    addLibraryBlock(testCase,'Recycle',[name '/Recycle'],[650 250 780 315]);
    addLibraryBlock(testCase,'Stream',[name '/Recycle Out'],[440 260 550 315]);set_param([name '/Recycle Out'],'Role','Intermediate');
    addLibraryBlock(testCase,'Stream',[name '/Bottom'],[790 330 900 385]);set_param([name '/Bottom'],'Role','Product');
    add_line(name,'F1/1','Mixer/1');add_line(name,'Recycle Out/1','Mixer/2');add_line(name,'Mixer/1','Mixed/1');add_line(name,'Mixed/1','CSTR/1');
    add_line(name,'CSTR/1','Reactor Out/1');add_line(name,'Reactor Out/1','Separator/1');add_line(name,'Separator/1','Separator Top/1');add_line(name,'Separator Top/1','Splitter/1');add_line(name,'Separator/2','Bottom/1');
    add_line(name,'Splitter/1','Purge/1');add_line(name,'Purge/1','Adjust/1');add_line(name,'Adjust/1','CSTR/2');add_line(name,'Splitter/2','Recycle Stream/1');
    add_line(name,'Recycle Stream/1','Recycle/1');add_line(name,'Recycle/1','Recycle Out/1');
end

function tab=findTab(figureHandle,title)
    tab=findall(figureHandle,'Type','uitab','Title',title);tab=tab(1);
end

function editCell(tableHandle,row,column,value)
    % A real uitable returns typed text when the cell already holds text (E-015)
    data=tableHandle.Data;previous=data{row,column};editData=value;if isnumeric(value),editData=num2str(value,17);end
    if (ischar(previous)||isstring(previous))&&isnumeric(value),value=editData;end
    data{row,column}=value;tableHandle.Data=data;
    event=struct('Indices',[row column],'PreviousData',previous,'NewData',value,'EditData',editData);
    feval(tableHandle.CellEditCallback,tableHandle,event);drawnow;
end

function typeValue(ui,control,value)
    if isprop(control,'Value')&&isnumeric(control.Value),ui.type(control,double(value));else,ui.type(control,char(string(value)));end
    drawnow;
end

function pressButton(ui,figureHandle,text)
    button=findall(figureHandle,'Type','uibutton','Text',text);ui.press(button(1));drawnow;
end

function capture(figureHandle,name)
    folder=getenv('NIRP_T158_CAPTURE_DIR');if isempty(folder),return,end
    if ~isfolder(folder),mkdir(folder);end;drawnow;exportapp(figureHandle,fullfile(folder,['t158_' name '.png']));
end

function cleanupClass(testCase,repository)
    bdclose('all');Simulink.data.dictionary.closeAll('-discard');
    Simulink.fileGenControl('setConfig','config',testCase.FileGenerationConfig);
    if contains([path pathsep],[testCase.Folder pathsep]),rmpath(testCase.Folder);end
    folder=fullfile(repository,'simulink');if contains([path pathsep],[folder pathsep]),rmpath(folder);end
end

function deleteValid(value)
    try,if isvalid(value),delete(value);end,catch,end
end
