classdef NirpJacketTest < matlab.unittest.TestCase
%NIRPJACKETTEST Verifies the reactor Jacket signal contract.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 8, 2026. Last update: October 8, 2026
% =========================================================================
    properties
        Folder
        SimulinkFolder
        FileGenerationConfig
    end
    methods (TestMethodSetup)
        function setup(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture=testCase.applyFixture(TemporaryFolderFixture);testCase.Folder=fixture.Folder;addpath(testCase.Folder);
            testCase.SimulinkFolder=fullfile(fileparts(fileparts(mfilename('fullpath'))),'simulink');addpath(testCase.SimulinkFolder);
            testCase.FileGenerationConfig=Simulink.fileGenControl('getConfig');
            Simulink.fileGenControl('set','CacheFolder',fullfile(testCase.Folder,'cache'), ...
                'CodeGenFolder',fullfile(testCase.Folder,'codegen'),'createDir',true);
            testCase.addTeardown(@() cleanup(testCase));
        end
    end
    methods (Test)
        function cstrAndPfrMatchCoreOtherMode(testCase)
            for type=["CSTR","PFR"]
                for utilityTout=[NaN 300]
                    name=lower(type)+"_"+string(isfinite(utilityTout));
                    buildModel(testCase.Folder,char(name),char(type),utilityTout);
                    load_system(fullfile(testCase.Folder,name+".slx"));sim(char(name));
                    results=evalin('base','nirpResults');actual=results.Streams.Product.streamSI;
                    pkg=nirp.pkg.examples.problem27Jacketed();rs=nirp.pkg.toReactionSys(pkg);feed=nirp.pkg.feedStream(pkg,"F1");
                    params=struct('V',0.2,'heatMode','Other','U',300,'A',9,'utilityTin',273);
                    if isfinite(utilityTout),params.utilityTout=utilityTout;end
                    if type=="CSTR",expected=nirp.units.cstr(params,feed,rs);else,params.D=0.1;expected=nirp.units.pfr(params,feed,rs);end
                    verifyStream(testCase,actual,expected);close_system(char(name),0);Simulink.data.dictionary.closeAll('-discard');
                end
            end
        end
        function resultTableReportsJacketDutyAndParameters(testCase)
            buildModel(testCase.Folder,'jacket_results','CSTR',300);
            load_system(fullfile(testCase.Folder,'jacket_results.slx'));set_param('jacket_results/Jacket','UtilityCp','4184');sim('jacket_results');
            tables=nirp.flowsheet.showResults('jacket_results','NoWindow',true);
            jacket=tables.Units(tables.Units.Type=="Jacket",:);reactor=tables.Units(tables.Units.Type=="CSTR",:);
            testCase.verifyEqual(height(jacket),1);testCase.verifyEqual(jacket.U,300,'RelTol',1e-12);
            testCase.verifyEqual(jacket.A,9,'RelTol',1e-12);testCase.verifyEqual(jacket.UtilityTin,273,'AbsTol',1e-12);
            testCase.verifyEqual(jacket.UtilityTout,300,'AbsTol',1e-12);testCase.verifyEqual(jacket.HeatDuty,reactor.HeatDuty,'AbsTol',1e-12);
            testCase.verifyEqual(jacket.ServiceFlow,abs(jacket.HeatDuty)/(4184*27),'RelTol',1e-12);testCase.verifyEqual(jacket.ServiceFlowUnit,"kg/s");
        end
        function resultTableOmitsUnitsForMissingValues(testCase)
            buildModel(testCase.Folder,'jacket_constant_temperature','CSTR',NaN);
            load_system(fullfile(testCase.Folder,'jacket_constant_temperature.slx'));sim('jacket_constant_temperature');
            tables=nirp.flowsheet.showResults('jacket_constant_temperature','NoWindow',true);
            jacket=tables.Units(tables.Units.Type=="Jacket",:);
            testCase.verifyTrue(isnan(jacket.UtilityTout));
            testCase.verifyEqual(jacket.UtilityToutUnit,"");
            testCase.verifyTrue(isnan(jacket.ServiceFlow));
            testCase.verifyEqual(jacket.ServiceFlowUnit,"");
        end
        function oldHeatExchangeDialogGuidesMigration(testCase)
            createModel(testCase.Folder,'legacy_dialog',nirp.pkg.examples.problem27Jacketed());
            addSystem('legacy_dialog','CSTR','nirp.blocks.CSTR',[220 90 360 160],'HeatMode','Heat exchange');
            dialog=nirp.flowsheet.ReactorDialog('legacy_dialog/CSTR','Visible','off');testCase.addTeardown(@() deleteValid(dialog));
            testCase.verifyEqual(dialog.HeatModeGroup.SelectedObject.Text,'Isothermal');
            testCase.verifyEqual(dialog.StatusLabel.Text, ...
                'Heat exchange is obsolete: add a Jacket block, tick "Show Jacket input port" and connect it');
            dialog.setHeatMode('Adiabatic');
            testCase.verifyTrue(dialog.apply());
            testCase.verifyEqual(get_param('legacy_dialog/CSTR','HeatMode'),'Adiabatic');
        end
        function oldHeatExchangeModeExplainsMigration(testCase)
            createModel(testCase.Folder,'legacy',nirp.pkg.examples.problem27Jacketed());
            addSystem('legacy','F1','nirp.blocks.Stream',[20 100 140 150],'Role','Feed');
            addSystem('legacy','CSTR','nirp.blocks.CSTR',[220 90 360 160],'HeatMode','Heat exchange');
            addSystem('legacy','Product','nirp.blocks.Stream',[430 100 550 150],'Role','Product');
            add_line('legacy','F1/1','CSTR/1');add_line('legacy','CSTR/1','Product/1');
            nirp.flowsheet.configure('legacy');
            try,sim('legacy');testCase.assertFail('Expected obsolete mode to fail.');
            catch exception,testCase.verifySubstring(getReport(exception,'basic','hyperlinks','off'),'Add a Jacket block');end
        end
        function topologyTreatsJacketAsSignal(testCase)
            buildModel(testCase.Folder,'jacket_topology','CSTR',NaN);load_system(fullfile(testCase.Folder,'jacket_topology.slx'));
            graph=testCase.verifyWarningFree(@() nirp.flowsheet.checkTopology('jacket_topology'));
            testCase.verifyFalse(isfield(graph.Units,'Jacket'));
            dialog=nirp.flowsheet.ReactorDialog('jacket_topology/CSTR','Visible','off');testCase.addTeardown(@() deleteValid(dialog));
            testCase.verifyEqual(dialog.JacketStatusLabel.Text,'Heat exchange: Jacket');
        end
        function generatedLibraryContainsJacket(testCase)
            file=build_library(testCase.Folder);load_system(file);
            blocks=find_system('NirpLibrary','SearchDepth',1,'System','nirp.blocks.Jacket');
            testCase.verifyEqual(numel(blocks),1);testCase.verifySubstring(get_param(blocks{1},'OpenFcn'),'JacketDialog.open');
        end
    end
end
function buildModel(folder,name,type,utilityTout)
    createModel(folder,name,nirp.pkg.examples.problem27Jacketed());
    addSystem(name,'F1','nirp.blocks.Stream',[20 100 140 150],'Role','Feed');
    args={'V','0.2','VUnit','m^3','HeatMode','Isothermal','ShowJacketPort','on'};if strcmp(type,'PFR'),args=[args {'D','0.1','DUnit','m'}];end
    addSystem(name,type,['nirp.blocks.' type],[300 90 440 170],args{:});
    addSystem(name,'Jacket','nirp.blocks.Jacket',[300 5 440 65],'U','300','A','9','UtilityTin','273','UtilityTout',num2str(utilityTout,17));
    addSystem(name,'Product','nirp.blocks.Stream',[510 100 630 150],'Role','Product');
    add_line(name,'F1/1',[type '/1']);add_line(name,'Jacket/1',[type '/2']);add_line(name,[type '/1'],'Product/1');
    nirp.flowsheet.configure(name);save_system(name,fullfile(folder,[name '.slx']));close_system(name,0);Simulink.data.dictionary.closeAll('-discard');
end
function createModel(folder,name,pkg),nirp.pkg.writeDictionary(pkg,fullfile(folder,[name '.sldd']));new_system(name);save_system(name,fullfile(folder,[name '.slx']));set_param(name,'DataDictionary',[name '.sldd']);end
function addSystem(model,name,className,position,varargin),add_block('simulink/User-Defined Functions/MATLAB System',[model '/' name],'System',className,'Position',position,varargin{:});if ~strcmp(className,'nirp.blocks.Stream'),nirp.flowsheet.setupUnitBlock([model '/' name]);end,end
function verifyStream(testCase,actual,expected),testCase.verifyEqual(actual.F,expected.F,'RelTol',1e-12,'AbsTol',1e-14);testCase.verifyEqual(actual.T,expected.T,'RelTol',1e-12);testCase.verifyEqual(actual.P,expected.P,'RelTol',1e-12);testCase.verifyEqual(actual.Q,expected.Q,'RelTol',1e-12);end
function cleanup(testCase),bdclose('all');Simulink.data.dictionary.closeAll('-discard');evalin('base','clear nirpResults');removePath(testCase.Folder);removePath(testCase.SimulinkFolder);Simulink.fileGenControl('setConfig','config',testCase.FileGenerationConfig);end
function deleteValid(value),try,if isvalid(value),delete(value);end,catch,end,end
function removePath(folder),if contains([path pathsep],[folder pathsep]),rmpath(folder);end,end
