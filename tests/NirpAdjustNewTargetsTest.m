classdef NirpAdjustNewTargetsTest < matlab.unittest.TestCase
    % NirpAdjustNewTargetsTest verifies the new scalar Adjust destinations.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: November 4, 2026. Last update: November 4, 2026
    % =========================================================================

    properties
        Folder
    end

    methods (TestClassSetup)
        function createFolder(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture=testCase.applyFixture(TemporaryFolderFixture);
            testCase.Folder=fixture.Folder;addpath(testCase.Folder);
            testCase.addTeardown(@()rmpath(testCase.Folder));
        end
    end

    methods (TestMethodTeardown)
        function closeArtifacts(~)
            figures=findall(groot,'Type','Figure');if ~isempty(figures),delete(figures);end
            bdclose('all');Simulink.data.dictionary.closeAll('-discard');
            evalin('base','clear nirpResults');
        end
    end

    methods (Test)
        function heaterTemperatureAndDutyPortsUseSI(testCase)
            [name,pkg,feed]=modelWithFeed(testCase,'new_target_heater');
            rs=nirp.pkg.toReactionSys(pkg);
            addSystem(name,'Heater','nirp.blocks.Heater',[220 80 360 150], ...
                'Mode','Outlet T','ToutSource','Input port','PressureDrop','0');
            [out,info]=nirp.blocks.internal.evaluate([name '/Heater'],{feed}, ...
                'Signals',{345},'ReactionSystem',rs);
            expected=nirp.units.heater(struct('mode','Outlet T','Tout',345,'dP',0),feed,rs);
            verifyStream(testCase,out{1},expected);testCase.verifyEqual(out{1}.T,345,'AbsTol',1e-10);
            testCase.verifyTrue(isfinite(info.heatDuty));

            set_param([name '/Heater'],'Mode','Duty','DutySource','Input port');
            duty=250;[out,~]=nirp.blocks.internal.evaluate([name '/Heater'],{feed}, ...
                'Signals',{duty},'ReactionSystem',rs);
            expected=nirp.units.heater(struct('mode','Duty','Q',duty,'dP',0),feed,rs);
            verifyStream(testCase,out{1},expected);
        end

        function splitterPortScalesTwoAndThreeOutlets(testCase)
            [name,pkg,feed]=modelWithFeed(testCase,'new_target_splitter');
            rs=nirp.pkg.toReactionSys(pkg);
            addSystem(name,'Splitter','nirp.blocks.Splitter',[220 80 360 180], ...
                'Fractions','[0.25 0.75]','FractionSource','Input port');
            outputs=nirp.blocks.internal.evaluate([name '/Splitter'],{feed}, ...
                'Signals',{0.4},'ReactionSystem',rs);
            testCase.verifyEqual(sum(outputs{1}.F),0.4*sum(feed.F),'RelTol',1e-12);
            testCase.verifyEqual(sum(outputs{2}.F),0.6*sum(feed.F),'RelTol',1e-12);

            set_param([name '/Splitter'],'Fractions','[0.2 0.3 0.5]');
            outputs=nirp.blocks.internal.evaluate([name '/Splitter'],{feed}, ...
                'Signals',{0.4},'ReactionSystem',rs);
            fractions=cellfun(@(stream)sum(stream.F)/sum(feed.F),outputs);
            testCase.verifyEqual(fractions,[0.4 0.225 0.375],'AbsTol',1e-12);
            testCase.verifyEqual(fractions(2)/fractions(3),0.3/0.5,'RelTol',1e-12);
        end

        function jacketSpecifiedPortsUseSelectedModeOnly(testCase)
            [name,~,~]=modelWithFeed(testCase,'new_target_jacket');
            addSystem(name,'Jacket','nirp.blocks.Jacket',[220 80 360 150], ...
                'Mode','Specified T','SpecifiedTSource','Input port');
            output=nirp.blocks.internal.evaluate([name '/Jacket'],{},'Signals',{410});
            testCase.verifyEqual(output{1},[2;410;NaN;NaN;NaN]);
            set_param([name '/Jacket'],'Mode','Specified Q', ...
                'SpecifiedQSource','Input port');
            output=nirp.blocks.internal.evaluate([name '/Jacket'],{},'Signals',{-1250});
            testCase.verifyEqual(output{1},[3;-1250;NaN;NaN;NaN]);
        end

        function adjustRecognisesAllFiveDestinations(testCase)
            name='new_target_mapping';new_system(name);
            addSystem(name,'Adjust','nirp.blocks.Adjust',[20 250 180 310]);
            cases={ ...
                'Heater Tout','nirp.blocks.Heater',{'Mode','Outlet T','ToutSource','Input port'},2,"Tout","Temperature"; ...
                'Heater Duty','nirp.blocks.Heater',{'Mode','Duty','DutySource','Input port'},2,"Duty","Power"; ...
                'Splitter','nirp.blocks.Splitter',{'FractionSource','Input port'},2,"Fraction 1","Fraction"; ...
                'Jacket T','nirp.blocks.Jacket',{'Mode','Specified T','SpecifiedTSource','Input port'},1,"T","Temperature"; ...
                'Jacket Q','nirp.blocks.Jacket',{'Mode','Specified Q','SpecifiedQSource','Input port'},1,"Q","Power"};
            for i=1:size(cases,1)
                block=[name '/' cases{i,1}];addSystem(name,cases{i,1},cases{i,2}, ...
                    [350 40+75*i 500 100+75*i],cases{i,3}{:});
                add_line(name,'Adjust/1',sprintf('%s/%d',cases{i,1},cases{i,4}));
                target=nirp.flowsheet.adjustTarget([name '/Adjust']);
                testCase.verifyEqual(target.Variable,cases{i,5});
                testCase.verifyEqual(target.Category,cases{i,6});
                delete_line(name,'Adjust/1',sprintf('%s/%d',cases{i,1},cases{i,4}));
                delete_block(block);
            end
        end

        function dialogsApplySourcesAndChangePorts(testCase)
            [name,~,~]=modelWithFeed(testCase,'new_target_dialogs');
            addSystem(name,'Heater','nirp.blocks.Heater',[200 60 340 130], ...
                'Mode','Outlet T','PressureDrop','0');
            addSystem(name,'Splitter','nirp.blocks.Splitter',[200 170 340 260]);
            addSystem(name,'Jacket','nirp.blocks.Jacket',[200 300 340 370], ...
                'Mode','Specified T');

            heater=nirp.flowsheet.HeaterDialog([name '/Heater'],'Visible','off');
            testCase.addTeardown(@()deleteValid(heater));heater.setValues('ToutSource','Input port');
            testCase.verifyEqual(string(heater.ToutField.Visible),"off");testCase.verifyTrue(heater.apply());
            splitter=nirp.flowsheet.SplitterDialog([name '/Splitter'],'Visible','off');
            testCase.addTeardown(@()deleteValid(splitter));splitter.setFractionSource('Input port');testCase.verifyTrue(splitter.apply());
            jacket=nirp.flowsheet.JacketDialog([name '/Jacket'],'Visible','off');
            testCase.addTeardown(@()deleteValid(jacket));jacket.setValues('SpecifiedTSource','Input port');
            testCase.verifyEqual(string(jacket.SpecifiedTField.Visible),"off");testCase.verifyTrue(jacket.apply());
            set_param(name,'SimulationCommand','update');
            ports=get_param([name '/Heater'],'PortHandles');testCase.verifyNumElements(ports.Inport,2);
            ports=get_param([name '/Splitter'],'PortHandles');testCase.verifyNumElements(ports.Inport,2);
            ports=get_param([name '/Jacket'],'PortHandles');testCase.verifyNumElements(ports.Inport,1);
        end

        function dialogSourcesPreserveLegacyResults(testCase)
            [name,pkg,feed]=modelWithFeed(testCase,'new_target_legacy');rs=nirp.pkg.toReactionSys(pkg);
            addSystem(name,'Heater','nirp.blocks.Heater',[220 80 360 150], ...
                'Mode','Outlet T','Tout','360','PressureDrop','0');
            dialog=nirp.blocks.internal.evaluate([name '/Heater'],{feed},'ReactionSystem',rs);
            set_param([name '/Heater'],'ToutSource','Input port');
            port=nirp.blocks.internal.evaluate([name '/Heater'],{feed}, ...
                'Signals',{360},'ReactionSystem',rs);
            verifyStream(testCase,dialog{1},port{1});
        end

        function invalidFractionAndWrongAdjustUnitAreRejected(testCase)
            [name,~,feed]=modelWithFeed(testCase,'new_target_errors');
            addSystem(name,'Splitter','nirp.blocks.Splitter',[220 80 360 170], ...
                'FractionSource','Input port');
            testCase.verifyError(@()nirp.blocks.internal.evaluate( ...
                [name '/Splitter'],{feed},'Signals',{1.1}), ...
                'nirp:blocks:invalidSplitterFraction');

            addSystem(name,'Adjust','nirp.blocks.Adjust',[20 250 180 310], ...
                'ParameterUnit','m^3');
            add_line(name,'Adjust/1','Splitter/2');
            testCase.verifyError(@()nirp.flowsheet.checkTopology(name), ...
                'nirp:blocks:invalidAdjustParameterUnit');
        end
    end
end

function [name,pkg,feed]=modelWithFeed(testCase,name)
    pkg=nirp.pkg.examples.firstOrderLiquid();dictionary=fullfile(testCase.Folder,[name '.sldd']);
    nirp.pkg.writeDictionary(pkg,dictionary);new_system(name);save_system(name,fullfile(testCase.Folder,[name '.slx']));
    set_param(name,'DataDictionary',[name '.sldd']);feed=nirp.pkg.feedStream(pkg,"F1");
end
function addSystem(model,name,className,position,varargin)
    add_block('simulink/User-Defined Functions/MATLAB System',[model '/' name], ...
        'System',className,'Position',position,varargin{:});
    nirp.flowsheet.setupUnitBlock([model '/' name]);
end
function verifyStream(testCase,actual,expected)
    testCase.verifyEqual(actual.F,expected.F,'RelTol',1e-12,'AbsTol',1e-12);
    testCase.verifyEqual(actual.T,expected.T,'RelTol',1e-12);
    testCase.verifyEqual(actual.P,expected.P,'RelTol',1e-12);
end
function deleteValid(value),try,if isvalid(value),delete(value);end,catch,end,end
