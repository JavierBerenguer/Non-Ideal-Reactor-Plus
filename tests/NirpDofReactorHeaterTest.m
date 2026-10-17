classdef NirpDofReactorHeaterTest < matlab.unittest.TestCase
%NIRPDOFREACTORHEATERTEST Reactor, Heater, and Jacket DOF catalogues/blocks.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================
    properties
        Folder
        FileGenerationConfig
    end
    methods (TestMethodSetup)
        function setup(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture=testCase.applyFixture(TemporaryFolderFixture);testCase.Folder=fixture.Folder;addpath(testCase.Folder);
            testCase.FileGenerationConfig=Simulink.fileGenControl('getConfig');
            Simulink.fileGenControl('set','CacheFolder',fullfile(testCase.Folder,'cache'),'CodeGenFolder',fullfile(testCase.Folder,'codegen'),'createDir',true);
            testCase.addTeardown(@()cleanup(testCase));
        end
    end
    methods (Test)
        function cstrCatalogueClosesBothDirections(testCase)
            model=nirp.dof.catalog.cstr(struct('catalytic',false));testCase.verifyEqual(catalogDof(model)-1,1);
            r=solveExternal(model,struct('tau',20),struct('Q0',0.01));testCase.verifyEqual(r.values.V,0.2,'AbsTol',1e-14);testCase.verifyEqual(r.values.SV,0.05,'AbsTol',1e-14);
            r=solveExternal(model,struct('V',0.2),struct('Q0',0.01));testCase.verifyEqual(r.values.tau,20,'AbsTol',1e-14);
            r=solveExternal(model,struct('SV',0.05),struct('Q0',0.01));testCase.verifyEqual(r.values.V,0.2,'AbsTol',1e-14);
            catalytic=nirp.dof.catalog.cstr(struct('catalytic',true));testCase.verifyEqual(catalogDof(catalytic)-1,3);
            r=solveExternal(catalytic,struct('W',80,'rho_cat',1000,'epsilon',0.2),struct('Q0',0.01));testCase.verifyEqual(r.values.V,0.1,'AbsTol',1e-14);
            r=solveExternal(catalytic,struct('V',0.1,'rho_cat',1000,'epsilon',0.2),struct('Q0',0.01));testCase.verifyEqual(r.values.W,80,'AbsTol',1e-14);
        end
        function pfrCatalogueClosesGeometryResidenceAndVelocity(testCase)
            model=nirp.dof.catalog.pfr(struct('catalytic',false,'pressureMode','Constant'));testCase.verifyEqual(catalogDof(model)-1,3);
            area=3*pi/4*0.2^2;r=solveExternal(model,struct('L',2,'D',0.2,'N_tubes',3),struct('Q0',0.03));
            testCase.verifyEqual(r.values.V,area*2,'RelTol',1e-13);testCase.verifyEqual(r.values.u,0.03/area,'RelTol',1e-13);testCase.verifyEqual(r.values.SV,1/r.values.tau,'RelTol',1e-13);
            r=solveExternal(model,struct('V',area*2,'D',0.2,'N_tubes',3),struct('Q0',0.03));testCase.verifyEqual(r.values.L,2,'RelTol',1e-13);
            r=solveExternal(model,struct('tau',10,'D',0.2,'N_tubes',3),struct('Q0',0.03));testCase.verifyEqual(r.values.V,0.3,'RelTol',1e-13);
            r=solveExternal(model,struct('u',0.03/area,'D',0.2,'L',2),struct('Q0',0.03));testCase.verifyEqual(r.values.N_tubes,3,'RelTol',1e-13);
            catalytic=nirp.dof.catalog.pfr(struct('catalytic',true,'pressureMode','Constant'));testCase.verifyEqual(catalogDof(catalytic)-1,5);
            pressure=nirp.dof.catalog.pfr(struct('pressureMode','Non constant','pressureDropEqn','Ergun'));testCase.verifyEqual(catalogDof(pressure)-1,6);
        end
        function heaterCatalogueClosesThermalAndPressureRelations(testCase)
            pkg=nirp.pkg.examples.firstOrderLiquid();in=nirp.pkg.feedStream(pkg,"F1");rs=nirp.pkg.toReactionSys(pkg);model=nirp.dof.catalog.heater(struct('inlet',in,'RS',rs));
            testCase.verifyEqual(catalogDof(model)-2,2);
            r=solveExternal(model,struct('T_out',in.T+25,'dP',1000),struct('T_in',in.T,'P_in',in.P));testCase.verifyEqual(r.values.dT,25,'AbsTol',1e-12);testCase.verifyEqual(r.values.P_out,in.P-1000,'AbsTol',1e-12);
            duty=r.values.Q;r2=solveExternal(model,struct('Q',duty,'P_out',in.P-1000),struct('T_in',in.T,'P_in',in.P));testCase.verifyEqual(r2.values.T_out,in.T+25,'AbsTol',1e-10);testCase.verifyEqual(r2.values.dP,1000,'AbsTol',1e-10);
            r3=solveExternal(model,struct('dT',25,'dP',1000),struct('T_in',in.T,'P_in',in.P));testCase.verifyEqual(r3.values.Q,duty,'RelTol',1e-12);
        end
        function jacketCataloguesCloseConductanceAndServiceFlow(testCase)
            utility=nirp.dof.catalog.jacket(struct('mode','Utility','condenses',false));empty=solveExternal(utility,struct(),struct('Q',NaN));testCase.verifyEqual(empty.missingCount,3);
            r=solveExternal(utility,struct('U',200,'A',5,'T_in_s',300,'T_out_s',320,'Cp_s',4000),struct('Q',-8e4));testCase.verifyEqual(r.values.UA,1000,'AbsTol',1e-12);testCase.verifyEqual(r.values.mdot_s,1,'AbsTol',1e-12);
            r=solveExternal(utility,struct('UA',1000,'A',5,'T_in_s',300),struct('Q',NaN));testCase.verifyEqual(r.values.U,200,'AbsTol',1e-12);
            condensing=nirp.dof.catalog.jacket(struct('mode','Utility','condenses',true));r=solveExternal(condensing,struct('U',200,'A',5,'T_in_s',300,'lambda',2e6),struct('Q',-1e6));testCase.verifyEqual(r.values.mdot_s,0.5,'AbsTol',1e-12);
            specifiedT=nirp.dof.catalog.jacket(struct('mode','Specified T'));specifiedQ=nirp.dof.catalog.jacket(struct('mode','Specified Q'));testCase.verifyEqual(numel(specifiedT.variables),1);testCase.verifyEqual(numel(specifiedQ.variables),1);
        end
        function specifiedTauTracksRecycleInletAndMatchesFixedVolume(testCase)
            tau=100;buildRecycle(testCase,'tau_loop',struct('tau',spec(tau,'s')));sim('tau_loop');results=evalin('base','nirpResults');mixed=results.Streams.Mixed.streamSI;info=results.Diagnostics.tau_loop_CSTR.lastInfo;
            testCase.verifyEqual(info.V/mixed.Q,tau,'RelTol',1e-10);
            actual=results.Streams.Product.streamSI;close_system('tau_loop',0);Simulink.data.dictionary.closeAll('-discard');
            buildRecycle(testCase,'fixed_loop',struct('V',spec(info.V,'m^3')));sim('fixed_loop');expected=evalin('base','nirpResults.Streams.Product.streamSI');verifyStream(testCase,actual,expected,1e-8);
        end
        function heaterDeltaTTracksMixerInRecycle(testCase)
            buildHeaterRecycle(testCase,'heater_loop',10);sim('heater_loop');results=evalin('base','nirpResults');mixed=results.Streams.Mixed.streamSI;heated=results.Streams.Heated.streamSI;
            testCase.verifyEqual(heated.T-mixed.T,10,'AbsTol',1e-10);
        end
        function dutySpecificationMatchesLegacyAndPfrSpecsMatchLength(testCase)
            buildSimpleHeater(testCase,'new_duty',true);sim('new_duty');newResult=evalin('base','nirpResults.Streams.Product.streamSI');close_system('new_duty',0);Simulink.data.dictionary.closeAll('-discard');
            buildSimpleHeater(testCase,'old_duty',false);sim('old_duty');oldResult=evalin('base','nirpResults.Streams.Product.streamSI');verifyStream(testCase,newResult,oldResult,1e-12);close_system('old_duty',0);Simulink.data.dictionary.closeAll('-discard');
            buildSimplePfr(testCase,'new_pfr',true);sim('new_pfr');newResult=evalin('base','nirpResults.Streams.Product.streamSI');close_system('new_pfr',0);Simulink.data.dictionary.closeAll('-discard');
            buildSimplePfr(testCase,'old_pfr',false);sim('old_pfr');oldResult=evalin('base','nirpResults.Streams.Product.streamSI');verifyStream(testCase,newResult,oldResult,1e-10);
        end
        function volumePortConflictsWithTauSpecification(testCase)
            createModel(testCase,'port_conflict');add_block('simulink/Sources/Constant','port_conflict/Constant','Position',[20 180 100 210],'Value','0.1');
            addSystem('port_conflict','CSTR','nirp.blocks.CSTR',[200 80 320 150],'VSource','Input port','Specifications',nirp.dof.writeSpecs(struct('tau',spec(100,'s'))));addSystem('port_conflict','Product','nirp.blocks.Stream',[400 80 500 130],'Role','Product');add_line('port_conflict','F1/1','CSTR/1');add_line('port_conflict','Constant/1','CSTR/2');add_line('port_conflict','CSTR/1','Product/1');nirp.flowsheet.configure('port_conflict');
            testCase.verifyError(@()sim('port_conflict'),?MException);
        end
        function dialogsPersistOnlyUserSpecifications(testCase)
            createModel(testCase,'dialog_specs');addSystem('dialog_specs','CSTR','nirp.blocks.CSTR',[200 40 320 110]);addSystem('dialog_specs','Heater','nirp.blocks.Heater',[200 150 320 220]);addSystem('dialog_specs','Jacket','nirp.blocks.Jacket',[200 260 320 330]);
            reactor=nirp.flowsheet.ReactorDialog('dialog_specs/CSTR','Visible','off');heater=nirp.flowsheet.HeaterDialog('dialog_specs/Heater','Visible','off');jacket=nirp.flowsheet.JacketDialog('dialog_specs/Jacket','Visible','off');testCase.addTeardown(@()deleteDialogs({reactor,heater,jacket}));
            testCase.verifyEqual(string(heater.ToutField.Visible),"on");testCase.verifyEqual(string(heater.DutyField.Visible),"on");
            reactor.setValues('V',NaN,'tau',100);testCase.verifyTrue(reactor.apply());specs=nirp.dof.readSpecs(get_param('dialog_specs/CSTR','Specifications'));testCase.verifyEqual(fieldnames(specs),{'tau'});
            heater.setValues('Tout',NaN,'dT',10,'dP',0);testCase.verifyEqual(string(heater.DutyField.Visible),"on");testCase.verifyTrue(heater.apply());specs=nirp.dof.readSpecs(get_param('dialog_specs/Heater','Specifications'));testCase.verifyEqual(sort(fieldnames(specs)),sort({'dP';'dT'}));
            jacket.setValues('U',NaN,'UA',1000,'A',5,'UtilityTin',300);testCase.verifyTrue(jacket.apply());specs=nirp.dof.readSpecs(get_param('dialog_specs/Jacket','Specifications'));testCase.verifyEqual(sort(fieldnames(specs)),sort({'A';'T_in_s';'UA'}));
        end
        function cstrWithoutKnownInletShowsWaitingFieldsAndCombinedStatus(testCase)
            createModel(testCase,'waiting_cstr');addSystem('waiting_cstr','CSTR','nirp.blocks.CSTR',[200 80 320 150]);
            dialog=nirp.flowsheet.ReactorDialog('waiting_cstr/CSTR','Visible','off');testCase.addTeardown(@()deleteDialogs({dialog}));
            dialog.setHeatMode('Isothermal');dialog.setValues('V',1e-5);
            testCase.verifyEqual(dialog.TauField.BackgroundColor,[0.88 0.88 0.88],'AbsTol',1e-12);
            testCase.verifyEqual(dialog.SpaceVelocityField.BackgroundColor,[0.88 0.88 0.88],'AbsTol',1e-12);
            testCase.verifyEqual(string(dialog.TauField.Tooltip),"needs a run or a defined feed");
            testCase.verifySubstring(string(dialog.StatusLabel.Text),"Fully specified");
            testCase.verifySubstring(string(dialog.StatusLabel.Text),"Not calculated yet");
            testCase.verifyEqual(string(dialog.VField.ValueDisplayFormat),"%.6g");
        end
    end
end

function result=solveExternal(model,specified,external),values=specified;origins=struct();names=fieldnames(specified);for i=1:numel(names),origins.(names{i})='specified';end;names=fieldnames(external);for i=1:numel(names),values.(names{i})=external.(names{i});origins.(names{i})='external';end;result=nirp.dof.solve(model,values,origins);end
function value=catalogDof(model),value=numel(model.variables)-sum(~[model.relations.redundant]);end
function value=spec(si,unit),value=struct('si',si,'unit',unit);end
function createModel(testCase,name),nirp.flowsheet.new(name,nirp.pkg.examples.firstOrderLiquid(),testCase.Folder,'OpenModel',false);load_system(fullfile(testCase.Folder,[name '.slx']));end
function addSystem(model,name,className,position,varargin),add_block('simulink/User-Defined Functions/MATLAB System',[model '/' name],'System',className,'Position',position,varargin{:});if startsWith(className,'nirp.blocks.'),if strcmp(className,'nirp.blocks.Stream'),nirp.flowsheet.setupStreamBlock([model '/' name]);else,nirp.flowsheet.setupUnitBlock([model '/' name]);end,end,end
function buildRecycle(testCase,name,specs)
    createModel(testCase,name);set_param([name '/F1'],'Position',[20 140 100 190]);addSystem(name,'Mixer','nirp.blocks.Mixer',[150 120 250 200]);addSystem(name,'Mixed','nirp.blocks.Stream',[275 135 355 185],'Role','Intermediate');addSystem(name,'CSTR','nirp.blocks.CSTR',[390 120 500 200],'Specifications',nirp.dof.writeSpecs(specs));addSystem(name,'Splitter','nirp.blocks.Splitter',[540 115 650 205],'Fractions','[0.5 0.5]');addSystem(name,'Recycle','nirp.blocks.Recycle',[430 270 570 330],'Method','Wegstein');addSystem(name,'Product','nirp.blocks.Stream',[710 130 810 180],'Role','Product');
    add_line(name,'F1/1','Mixer/1');add_line(name,'Recycle/1','Mixer/2');add_line(name,'Mixer/1','Mixed/1');add_line(name,'Mixed/1','CSTR/1');add_line(name,'CSTR/1','Splitter/1');add_line(name,'Splitter/1','Product/1');add_line(name,'Splitter/2','Recycle/1');nirp.flowsheet.configure(name);
end
function buildHeaterRecycle(testCase,name,deltaT)
    createModel(testCase,name);set_param([name '/F1'],'Position',[20 140 100 190]);addSystem(name,'Mixer','nirp.blocks.Mixer',[150 120 250 200]);addSystem(name,'Mixed','nirp.blocks.Stream',[275 135 355 185],'Role','Intermediate');specs=struct('dT',spec(deltaT,'K'),'dP',spec(0,'Pa'));addSystem(name,'Heater','nirp.blocks.Heater',[390 120 500 200],'Specifications',nirp.dof.writeSpecs(specs));addSystem(name,'Heated','nirp.blocks.Stream',[520 135 600 185],'Role','Intermediate');addSystem(name,'Splitter','nirp.blocks.Splitter',[630 115 740 205],'Fractions','[0.5 0.5]');addSystem(name,'Recycle','nirp.blocks.Recycle',[470 270 610 330],'Method','Wegstein');addSystem(name,'Product','nirp.blocks.Stream',[790 130 890 180],'Role','Product');
    add_line(name,'F1/1','Mixer/1');add_line(name,'Recycle/1','Mixer/2');add_line(name,'Mixer/1','Mixed/1');add_line(name,'Mixed/1','Heater/1');add_line(name,'Heater/1','Heated/1');add_line(name,'Heated/1','Splitter/1');add_line(name,'Splitter/1','Product/1');add_line(name,'Splitter/2','Recycle/1');nirp.flowsheet.configure(name);
end
function buildSimpleHeater(testCase,name,useSpecs),createModel(testCase,name);set_param([name '/F1'],'Position',[20 100 120 150]);args={'Mode','Duty','Duty','1000','PressureDrop','0'};if useSpecs,args=[args {'Specifications',nirp.dof.writeSpecs(struct('Q',spec(1000,'W'),'dP',spec(0,'Pa')))}];end;addSystem(name,'Heater','nirp.blocks.Heater',[200 90 320 160],args{:});addSystem(name,'Product','nirp.blocks.Stream',[400 100 500 150],'Role','Product');add_line(name,'F1/1','Heater/1');add_line(name,'Heater/1','Product/1');nirp.flowsheet.configure(name);end
function buildSimplePfr(testCase,name,useSpecs),createModel(testCase,name);set_param([name '/F1'],'Position',[20 100 120 150]);args={'GeometryMode','Length','L','2','D','0.1','NTubes','2'};if useSpecs,args=[args {'Specifications',nirp.dof.writeSpecs(struct('L',spec(2,'m'),'D',spec(0.1,'m'),'N_tubes',spec(2,'1')))}];end;addSystem(name,'PFR','nirp.blocks.PFR',[200 90 320 160],args{:});addSystem(name,'Product','nirp.blocks.Stream',[400 100 500 150],'Role','Product');add_line(name,'F1/1','PFR/1');add_line(name,'PFR/1','Product/1');nirp.flowsheet.configure(name);end
function verifyStream(testCase,actual,expected,tolerance),testCase.verifyEqual(actual.F,expected.F,'RelTol',tolerance,'AbsTol',1e-13);testCase.verifyEqual(actual.T,expected.T,'RelTol',tolerance,'AbsTol',1e-12);testCase.verifyEqual(actual.P,expected.P,'RelTol',tolerance,'AbsTol',1e-9);testCase.verifyEqual(actual.Q,expected.Q,'RelTol',tolerance,'AbsTol',1e-13);end
function cleanup(testCase),bdclose('all');Simulink.data.dictionary.closeAll('-discard');evalin('base','clear nirpResults');if contains([path pathsep],[testCase.Folder pathsep]),rmpath(testCase.Folder);end;Simulink.fileGenControl('setConfig','config',testCase.FileGenerationConfig);figures=findall(groot,'Type','Figure');if ~isempty(figures),delete(figures);end,end
function deleteDialogs(dialogs),for i=1:numel(dialogs),try,if isvalid(dialogs{i}),delete(dialogs{i});end,catch,end,end,end
