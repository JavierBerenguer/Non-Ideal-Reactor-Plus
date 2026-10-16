classdef NirpConnectedStreamSpecificationsTest < matlab.unittest.TestCase
%NIRPCONNECTEDSTREAMSPECIFICATIONSTEST Output Stream DOF integration (T-155).
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 16, 2026
% =========================================================================
    properties
        Folder
    end
    methods (TestClassSetup)
        function buildExamples(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture=testCase.applyFixture(TemporaryFolderFixture);testCase.Folder=fixture.Folder;
            repo=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(repo,'simulink'));addpath(testCase.Folder);
            build_examples(testCase.Folder,["ex5_recycle_cstr" "ex49_reactor_separator_recycle"]);
            testCase.addTeardown(@()cleanup(testCase.Folder));
        end
    end
    methods (TestMethodTeardown)
        function closeModels(~),bdclose('all');Simulink.data.dictionary.closeAll('-discard');evalin('base','clear nirpResults');end
    end
    methods (Test)
        function purgeFlowSpecificationMatchesEx5Fraction(testCase)
            load_system(fullfile(testCase.Folder,'ex5_recycle_cstr.slx'));sim('ex5_recycle_cstr');baseline=evalin('base','nirpResults');
            target=sum(baseline.Streams.Product.streamSI.F);expected=baseline.Streams.Product.streamSI.F;
            set_param('ex5_recycle_cstr/Splitter','Specifications','{}');
            nirp.dof.writeSpecs('ex5_recycle_cstr/Product',struct('F',spec(target,'mol/s')));
            sim('ex5_recycle_cstr');actual=evalin('base','nirpResults');
            testCase.verifyEqual(sum(actual.Streams.Product.streamSI.F),target,'RelTol',1e-10,'AbsTol',1e-12);
            testCase.verifyEqual(actual.Streams.Product.streamSI.F,expected,'RelTol',1e-10,'AbsTol',1e-12);
        end

        function separatorTopComponentSpecificationMatchesEx49(testCase)
            load_system(fullfile(testCase.Folder,'ex49_reactor_separator_recycle.slx'));sim('ex49_reactor_separator_recycle');baseline=evalin('base','nirpResults');
            top=baseline.Streams.(matlab.lang.makeValidName('Separator top')).streamSI;product=baseline.Streams.Product.streamSI;
            nirp.dof.writeSpecs('ex49_reactor_separator_recycle/Separator',struct('r2',spec(0.02,'1')));
            nirp.dof.writeSpecs('ex49_reactor_separator_recycle/Separator top',struct('F1',spec(top.F(1),'mol/s')));
            dialog=nirp.flowsheet.StreamDialog('ex49_reactor_separator_recycle/Separator top','Visible','off');testCase.addTeardown(@()deleteValid(dialog)); % a saved component F reloads (E-014)
            testCase.verifyEqual(dialog.getSpecifications().F1.si,top.F(1),'RelTol',1e-12);
            sim('ex49_reactor_separator_recycle');actual=evalin('base','nirpResults');actualTop=actual.Streams.(matlab.lang.makeValidName('Separator top')).streamSI;
            testCase.verifyEqual(actualTop.F(1),top.F(1),'RelTol',1e-10,'AbsTol',1e-12);
            testCase.verifyEqual(actual.Streams.Product.streamSI.F,product.F,'RelTol',5e-8,'AbsTol',1e-12);
        end

        function heaterOutputTemperatureEqualsDirectSpecification(testCase)
            createHeaterModel(testCase.Folder,'heater_stream_spec');
            direct=struct('T_out',spec(340,'K'),'dP',spec(1000,'Pa'));nirp.dof.writeSpecs('heater_stream_spec/Heater',direct);sim('heater_stream_spec');baseline=evalin('base','nirpResults');
            nirp.dof.writeSpecs('heater_stream_spec/Heater',struct('dP',spec(1000,'Pa')));nirp.dof.writeSpecs('heater_stream_spec/Product',struct('T',spec(340,'K')));sim('heater_stream_spec');actual=evalin('base','nirpResults');
            testCase.verifyEqual(actual.Streams.Product.streamSI.T,baseline.Streams.Product.streamSI.T,'AbsTol',1e-12);
            testCase.verifyEqual(actual.Streams.Product.streamSI.P,baseline.Streams.Product.streamSI.P,'AbsTol',1e-12);
            nirp.dof.writeSpecs('heater_stream_spec/Heater',struct('Q',spec(1000,'W'),'dP',spec(1000,'Pa')));
            state=nirp.dof.producerState('heater_stream_spec/Heater');testCase.verifyEqual(state.Result.status,'conflict');
            testCase.verifySubstring(strjoin(state.Result.messages,' '),'Heater');testCase.verifySubstring(strjoin(state.Result.messages,' '),'Product');
        end

        function conflictsAppearInStreamProducerAndSimulation(testCase)
            createSplitterModel(testCase.Folder,'stream_conflict');
            dialog=nirp.flowsheet.StreamDialog('stream_conflict/Out 1','Visible','off');testCase.addTeardown(@()deleteValid(dialog));
            dialog.setSpecification('F',0.4,'mol/s');testCase.verifyWarning(@()dialog.apply(),'nirp:flowsheet:streamSpecificationNotSaved');
            testCase.verifyEmpty(get_param('stream_conflict/Out 1','Specifications'));testCase.verifySubstring(dialog.StatusLabel.Text,'Splitter');testCase.verifySubstring(dialog.StatusLabel.Text,'Out 1');
            nirp.dof.writeSpecs('stream_conflict/Out 1',struct('F',spec(0.4,'mol/s')));
            producer=nirp.flowsheet.SplitterDialog('stream_conflict/Splitter','Visible','off');testCase.addTeardown(@()deleteValid(producer));
            testCase.verifySubstring(producer.StatusLabel.Text,'Conflict');testCase.verifySubstring(producer.StatusLabel.Text,'Out 1');
            exception=runFailure(@()sim('stream_conflict'));report=getReport(exception,'extended','hyperlinks','off');testCase.verifySubstring(report,'Splitter');testCase.verifySubstring(report,'Out 1');
        end

        function impossibleFlowAndUnsupportedProducerAreNotSaved(testCase)
            createSplitterModel(testCase.Folder,'impossible_flow');set_param('impossible_flow/Splitter','Fractions','[NaN NaN]','Specifications','{}');
            dialog=nirp.flowsheet.StreamDialog('impossible_flow/Out 1','Visible','off');testCase.addTeardown(@()deleteValid(dialog));
            dialog.setSpecification('F',2,'mol/s');testCase.verifyWarning(@()dialog.apply(),'nirp:flowsheet:streamSpecificationNotSaved');testCase.verifySubstring(dialog.StatusLabel.Text,'outside its allowed range');
            testCase.verifyEmpty(get_param('impossible_flow/Out 1','Specifications'));
            createUnsupportedModel(testCase.Folder,'unsupported_stream');unsupported=nirp.flowsheet.StreamDialog('unsupported_stream/Product','Visible','off');testCase.addTeardown(@()deleteValid(unsupported));
            unsupported.setSpecification('F',0.2,'mol/s');testCase.verifyWarning(@()unsupported.apply(),'nirp:flowsheet:streamSpecificationNotSaved');
            testCase.verifySubstring(unsupported.StatusLabel.Text,'No block can meet this specification directly; use an Adjust');testCase.verifyEmpty(get_param('unsupported_stream/Product','Specifications'));
        end

        function sumOfSpecifiedOutletFlowsCannotExceedInlet(testCase)
            createSplitterModel(testCase.Folder,'sum_conflict');set_param('sum_conflict/Splitter','Fractions','[NaN NaN]','Specifications','{}');
            nirp.dof.writeSpecs('sum_conflict/Out 1',struct('F',spec(0.7,'mol/s')));nirp.dof.writeSpecs('sum_conflict/Out 2',struct('F',spec(0.7,'mol/s')));
            state=nirp.dof.producerState('sum_conflict/Splitter');testCase.verifyEqual(state.Result.status,'conflict');
            testCase.verifyTrue(any(contains(state.Result.messages,'inconsistent'))||any(contains(state.Result.messages,'Over-specified')));
            testCase.verifyTrue(all(ismember(["F_out1" "F_out2"],state.Result.conflicts)));
        end

        function streamMaskHidesSerializedSpecifications(testCase)
            createSplitterModel(testCase.Folder,'hidden_stream_specs');nirp.flowsheet.setupStreamBlock('hidden_stream_specs/Out 1');
            parameter=Simulink.Mask.get('hidden_stream_specs/Out 1').getParameter('Specifications');testCase.verifyEqual(parameter.Visible,'off');
        end
        function emptyOptionalStreamSpecificationsStayNeutral(testCase)
            createSplitterModel(testCase.Folder,'neutral_stream_specs');dialog=nirp.flowsheet.StreamDialog('neutral_stream_specs/Out 1','Visible','off');testCase.addTeardown(@()deleteValid(dialog));
            testCase.verifyEqual(dialog.SpecificationTotalFlowField.BackgroundColor,[1 1 1],'AbsTol',1e-12);
            testCase.verifyEqual(dialog.SpecificationTemperatureField.BackgroundColor,[1 1 1],'AbsTol',1e-12);
            testCase.verifyEqual(dialog.SpecificationPressureField.BackgroundColor,[1 1 1],'AbsTol',1e-12);
        end

        function separatorSpecificationsStayEditableWithoutKnownInlet(testCase)
            createModel(testCase.Folder,'separator_without_inlet');
            addSystem('separator_without_inlet','Separator','nirp.blocks.Separator',[160 80 270 170]);
            nirp.flowsheet.setupUnitBlock('separator_without_inlet/Separator');
            dialog=nirp.flowsheet.SeparatorDialog('separator_without_inlet/Separator','Visible','off');testCase.addTeardown(@()deleteValid(dialog));
            testCase.verifyEqual(dialog.RecoveryTable.ColumnEditable,[false true true true true true]);
        end
    end
end

function createSplitterModel(folder,name)
    createModel(folder,name);addSystem(name,'F1','nirp.blocks.Stream',[20 100 100 150],'Role','Feed');addSystem(name,'Splitter','nirp.blocks.Splitter',[160 80 270 170],'Fractions','[0.4 0.6]');addSystem(name,'Out 1','nirp.blocks.Stream',[340 50 430 100],'Role','Product');addSystem(name,'Out 2','nirp.blocks.Stream',[340 150 430 200],'Role','Product');
    add_line(name,'F1/1','Splitter/1');add_line(name,'Splitter/1','Out 1/1');add_line(name,'Splitter/2','Out 2/1');nirp.flowsheet.configure(name);
end
function createHeaterModel(folder,name)
    createModel(folder,name);addSystem(name,'F1','nirp.blocks.Stream',[20 100 100 150],'Role','Feed');addSystem(name,'Heater','nirp.blocks.Heater',[170 85 290 165]);addSystem(name,'Product','nirp.blocks.Stream',[360 100 450 150],'Role','Product');add_line(name,'F1/1','Heater/1');add_line(name,'Heater/1','Product/1');nirp.flowsheet.configure(name);
end
function createUnsupportedModel(folder,name)
    createModel(folder,name);addSystem(name,'F1','nirp.blocks.Stream',[20 100 100 150],'Role','Feed');addSystem(name,'CSTR','nirp.blocks.CSTR',[170 85 290 165],'V','0.1','HeatMode','Isothermal');addSystem(name,'Product','nirp.blocks.Stream',[360 100 450 150],'Role','Product');add_line(name,'F1/1','CSTR/1');add_line(name,'CSTR/1','Product/1');nirp.flowsheet.configure(name);
end
function createModel(folder,name)
    pkg=nirp.pkg.examples.firstOrderLiquid();nirp.pkg.writeDictionary(pkg,fullfile(folder,[name '.sldd']));new_system(name);save_system(name,fullfile(folder,[name '.slx']));set_param(name,'DataDictionary',[name '.sldd']);
end
function addSystem(model,name,className,position,varargin),add_block('simulink/User-Defined Functions/MATLAB System',[model '/' name],'System',className,'Position',position,varargin{:});end
function value=spec(si,unit),value=struct('si',si,'unit',unit);end
function exception=runFailure(action),try,action();error('nirp:test:expectedFailure','Expected simulation to fail.');catch exception,if strcmp(exception.identifier,'nirp:test:expectedFailure'),rethrow(exception);end,end,end
function deleteValid(value),try,if isvalid(value),delete(value);end,catch,end,end
function cleanup(folder),bdclose('all');Simulink.data.dictionary.closeAll('-discard');evalin('base','clear nirpResults');if contains([path pathsep],[folder pathsep]),rmpath(folder);end,end
