classdef NirpUnitDialogsTest < matlab.unittest.TestCase
%NIRPUNITDIALOGSTEST Tests for structured flowsheet unit dialogs.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================
    properties
        Folder
        FileGenerationConfig
    end
    methods (TestMethodSetup)
        function setup(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture=testCase.applyFixture(TemporaryFolderFixture);testCase.Folder=fixture.Folder;addpath(testCase.Folder);
            testCase.FileGenerationConfig=Simulink.fileGenControl('getConfig');Simulink.fileGenControl('set','CacheFolder',fullfile(testCase.Folder,'cache'),'CodeGenFolder',fullfile(testCase.Folder,'codegen'),'createDir',true);
            nirp.flowsheet.new('dialog_model',nirp.pkg.examples.firstOrderLiquid(),testCase.Folder,'OpenModel',false);load_system(fullfile(testCase.Folder,'dialog_model.slx'));testCase.addTeardown(@() cleanup(testCase));
        end
    end
    methods (Test)
        function cstrAppliesHeatExchangeAndVisibility(testCase)
            addUnit('dialog_model','CSTR','nirp.blocks.CSTR',[240 120 350 190]);
            d=nirp.flowsheet.ReactorDialog('dialog_model/CSTR','Visible','off');testCase.addTeardown(@() deleteValid(d));
            d.setHeatMode('Heat exchange');d.setValues('U',2,'A',3,'UtilityTin',320);d.UUnitDropDown.Value='W/(m^2*K)';d.AUnitDropDown.Value='m^2';d.UtilityTinUnitDropDown.Value='K';
            testCase.verifyTrue(strcmp(d.UField.Visible,'on'));testCase.verifyTrue(strcmp(d.SpecifiedTField.Visible,'off'));d.apply();
            testCase.verifyEqual(str2double(get_param('dialog_model/CSTR','U')),2);testCase.verifyEqual(get_param('dialog_model/CSTR','HeatMode'),'Heat exchange');
            values=d.getValues();testCase.verifyEqual(values.U.origin,"specified");
            addStream('dialog_model','Product','Product',[430 130 540 180]);set_param('dialog_model/Product','ReferenceFeed','F1','KeyComponent','A');add_line('dialog_model','F1/1','CSTR/1');add_line('dialog_model','CSTR/1','Product/1');sim('dialog_model');fromDialog=evalin('base','nirpResults.Streams.Product.streamSI.F');
            set_param('dialog_model/CSTR','U','2','UUnit','W/(m^2*K)','A','3','AUnit','m^2','UtilityTin','320','UtilityTinUnit','K');sim('dialog_model');fromSetParam=evalin('base','nirpResults.Streams.Product.streamSI.F');testCase.verifyEqual(fromDialog,fromSetParam,'AbsTol',1e-12);
        end
        function pfrGeometryAndErgun(testCase)
            addUnit('dialog_model','PFR','nirp.blocks.PFR',[240 120 350 190]);d=nirp.flowsheet.ReactorDialog('dialog_model/PFR','Visible','off');testCase.addTeardown(@() deleteValid(d));
            d.GeometryModeDropDown.Value='Length';d.setValues('L',1,'D',0.1,'NTubes',2,'ParticleDiameter',100,'Density',1000,'Viscosity',1,'CatalystDensity',1000,'CatalystPorosity',0.4);d.CatalyticCheckBox.Value=true;d.LUnitDropDown.Value='m';d.DUnitDropDown.Value='m';d.ParticleDiameterUnitDropDown.Value='mm';d.ViscosityUnitDropDown.Value='mPa*s';select(d.PressureModeGroup,'Non constant');select(d.PressureEquationGroup,'Ergun');d.apply();
            testCase.verifyEqual(get_param('dialog_model/PFR','GeometryMode'),'Length');testCase.verifyEqual(get_param('dialog_model/PFR','PressureDropEqn'),'Ergun');testCase.verifyEqual(str2double(get_param('dialog_model/PFR','NTubes')),2);
            addStream('dialog_model','Product','Product',[430 130 540 180]);set_param('dialog_model/Product','ReferenceFeed','F1','KeyComponent','A');add_line('dialog_model','F1/1','PFR/1');add_line('dialog_model','PFR/1','Product/1');sim('dialog_model');testCase.verifyEqual(evalin('base','nirpResults.Streams.Product.streamSI.status'),1);
        end
        function heaterDutyUnitsAndOrigin(testCase)
            addUnit('dialog_model','Heater','nirp.blocks.Heater',[240 120 350 190]);d=nirp.flowsheet.HeaterDialog('dialog_model/Heater','Visible','off');testCase.addTeardown(@() deleteValid(d));d.setMode('Duty');d.setValues('Duty',0.1);d.DutyUnitDropDown.Value='kW';d.apply();testCase.verifyEqual(get_param('dialog_model/Heater','Mode'),'Duty');testCase.verifyEqual(get_param('dialog_model/Heater','DutyUnit'),'kW');testCase.verifyEqual(d.getValues().Duty.origin,"specified");testCase.verifyTrue(strcmp(d.ToutField.Visible,'off'));
            addStream('dialog_model','Product','Product',[430 130 540 180]);add_line('dialog_model','F1/1','Heater/1');add_line('dialog_model','Heater/1','Product/1');sim('dialog_model');testCase.verifyEqual(evalin('base','nirpResults.Streams.Product.streamSI.status'),1);
        end
        function modularPortsAndFractions(testCase)
            addUnit('dialog_model','Splitter','nirp.blocks.Splitter',[240 120 350 210]);addUnit('dialog_model','Mixer','nirp.blocks.Mixer',[600 120 710 210]);
            s=nirp.flowsheet.SplitterDialog('dialog_model/Splitter','Visible','off');m=nirp.flowsheet.MixerDialog('dialog_model/Mixer','Visible','off');testCase.addTeardown(@() deleteValid(s));testCase.addTeardown(@() deleteValid(m));
            s.setFractions([0.2 0.3 0.5]);s.apply();m.setNumInputs(4);m.apply();testCase.verifyEqual(str2num(get_param('dialog_model/Splitter','Fractions')),[0.2 0.3 0.5],'AbsTol',1e-15);testCase.verifyEqual(str2double(get_param('dialog_model/Mixer','NumInputs')),4);testCase.verifyEqual(s.getValues().Fractions.origin,"specified");
            m.setNumInputs(3);m.apply();for i=1:3,addStream('dialog_model',sprintf('Branch%d',i),'Intermediate',[400 30+100*i 500 75+100*i]);add_line('dialog_model',sprintf('Splitter/%d',i),sprintf('Branch%d/1',i));add_line('dialog_model',sprintf('Branch%d/1',i),sprintf('Mixer/%d',i));end;addStream('dialog_model','Product','Product',[780 140 890 190]);add_line('dialog_model','F1/1','Splitter/1');add_line('dialog_model','Mixer/1','Product/1');sim('dialog_model');feed=nirp.pkg.feedStream(nirp.pkg.examples.firstOrderLiquid(),"F1");out=evalin('base','nirpResults.Streams.Product.streamSI');testCase.verifyEqual(out.F,feed.F,'AbsTol',1e-12);
            s.setFractions(ones(1,8)/8);s.apply();testCase.verifyEqual(numel(str2num(get_param('dialog_model/Splitter','Fractions'))),8);
        end
        function connectionsUseStreamNames(testCase)
            addUnit('dialog_model','CSTR','nirp.blocks.CSTR',[260 120 370 190]);addStream('dialog_model','Middle','Intermediate',[430 130 540 180]);add_line('dialog_model','F1/1','CSTR/1');add_line('dialog_model','CSTR/1','Middle/1');
            d=nirp.flowsheet.ReactorDialog('dialog_model/CSTR','Visible','off');testCase.addTeardown(@() deleteValid(d));data=d.getConnections();testCase.verifyTrue(any(strcmp(data(:,3),'F1')));testCase.verifyTrue(any(strcmp(data(:,3),'Middle')));
        end
        function callbacksOpenStructuredDialogs(testCase)
            classes={'CSTR','PFR','Heater','Splitter','Mixer'};for i=1:numel(classes),addUnit('dialog_model',classes{i},['nirp.blocks.' classes{i}],[220 40+60*i 340 90+60*i]);testCase.verifySubstring(get_param(['dialog_model/' classes{i}],'OpenFcn'),'Dialog.open');end
            flow=find_system('dialog_model','SearchDepth',1,'BlockType','SubSystem');testCase.verifySubstring(get_param(flow{1},'OpenFcn'),'ReactiveSystemDialog');
        end
        function reactiveSystemAddsReactionAndCreatesModel(testCase)
            d=nirp.flowsheet.ReactiveSystemDialog('Mode','edit','Model','dialog_model','Visible','off');testCase.addTeardown(@() deleteValid(d));d.setCounts(2,2);data=d.ReactionTable.Data;data(2,:)=data(1,:);d.ReactionTable.Data=data;d.saveToModel('dialog_model');pkg=nirp.pkg.readDictionary(fullfile(testCase.Folder,'dialog_model.sldd'));nirp.pkg.validate(pkg);rs=nirp.pkg.toReactionSys(pkg);testCase.verifySize(rs.stochiometricMatrix,[2 2]);
            fresh=nirp.flowsheet.ReactiveSystemDialog('Visible','off');testCase.addTeardown(@() deleteValid(fresh));fresh.createFlowsheet('created_by_dialog',testCase.Folder,'OpenModel',false);load_system(fullfile(testCase.Folder,'created_by_dialog.slx'));testCase.verifyNotEmpty(find_system('created_by_dialog','SearchDepth',1,'System','nirp.blocks.Stream'));
        end
    end
end
function addUnit(model,name,className,pos),add_block('simulink/User-Defined Functions/MATLAB System',[model '/' name],'System',className,'Position',pos);nirp.flowsheet.setupUnitBlock([model '/' name]);end
function addStream(model,name,role,pos),add_block('simulink/User-Defined Functions/MATLAB System',[model '/' name],'System','nirp.blocks.Stream','Role',role,'Position',pos);nirp.flowsheet.setupStreamBlock([model '/' name]);end
function select(group,value),b=group.Children;i=find(strcmp({b.Text},value),1);group.SelectedObject=b(i);feval(group.SelectionChangedFcn,group,[]);end
function cleanup(testCase),bdclose('all');Simulink.data.dictionary.closeAll('-discard');f=findall(groot,'Type','Figure');if ~isempty(f),delete(f);end;evalin('base','clear nirpResults');rmpath(testCase.Folder);Simulink.fileGenControl('setConfig','config',testCase.FileGenerationConfig);end
function deleteValid(value),try,if isvalid(value),delete(value);end,catch,end,end
