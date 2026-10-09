classdef NirpStreamRoleTest < matlab.unittest.TestCase
    % NirpStreamRoleTest verifies connectivity-based Stream roles.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 9, 2026. Last update: October 9, 2026
    % =========================================================================

    properties
        Folder
        SimulinkFolder
        FileGenerationConfig
    end

    methods (TestMethodSetup)
        function setup(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture) ;
            testCase.Folder = fixture.Folder ;
            testCase.SimulinkFolder = fullfile(fileparts(fileparts( ...
                mfilename('fullpath'))),'simulink') ;
            addpath(testCase.Folder) ; addpath(testCase.SimulinkFolder) ;
            testCase.FileGenerationConfig = Simulink.fileGenControl('getConfig') ;
            Simulink.fileGenControl('set','CacheFolder', ...
                fullfile(testCase.Folder,'cache'),'CodeGenFolder', ...
                fullfile(testCase.Folder,'codegen'),'createDir',true) ;
            testCase.addTeardown(@() cleanup(testCase)) ;
            evalin('base','clear nirpResults') ;
        end
    end

    methods (Test)
        function autoRolesMatchExplicitRolesInSimulation(testCase)
            createSeriesModel(testCase.Folder,'auto_series') ;
            nirp.flowsheet.configure('auto_series') ;
            graph = nirp.flowsheet.topology('auto_series') ;
            testCase.verifyEqual(graph.Streams.F1.Role,"Feed") ;
            testCase.verifyEqual(graph.Streams.Middle.Role,"Intermediate") ;
            testCase.verifyEqual(graph.Streams.Product.Role,"Product") ;
            testCase.verifyEqual(graph.Streams.F1.DeclaredRole,"Auto") ;
            sim('auto_series') ;
            autoResult = evalin('base','nirpResults.Streams.Product.streamSI') ;

            set_param('auto_series/F1','Role','Feed') ;
            set_param('auto_series/Middle','Role','Intermediate') ;
            set_param('auto_series/Product','Role','Product') ;
            nirp.flowsheet.configure('auto_series') ;
            sim('auto_series') ;
            explicitResult = evalin('base','nirpResults.Streams.Product.streamSI') ;
            testCase.verifyEqual(autoResult.F,explicitResult.F,'RelTol',1e-12) ;
            testCase.verifyEqual(autoResult.T,explicitResult.T,'RelTol',1e-12) ;
            testCase.verifyEqual(autoResult.P,explicitResult.P,'RelTol',1e-12) ;
            testCase.verifyEqual(autoResult.Q,explicitResult.Q,'RelTol',1e-12) ;
        end

        function reconnectingChangesAutoRole(testCase)
            createSeriesModel(testCase.Folder,'role_reconnect') ;
            nirp.flowsheet.configure('role_reconnect') ;
            testCase.verifyEqual( ...
                nirp.flowsheet.streamRole('role_reconnect/Middle'),"Intermediate") ;
            delete_line('role_reconnect','Middle/1','CSTR 2/1') ;
            nirp.flowsheet.configure('role_reconnect') ;
            testCase.verifyEqual( ...
                nirp.flowsheet.streamRole('role_reconnect/Middle'),"Product") ;
            add_line('role_reconnect','Middle/1','CSTR 2/1') ;
            delete_line('role_reconnect','CSTR 1/1','Middle/1') ;
            nirp.flowsheet.configure('role_reconnect') ;
            testCase.verifyEqual( ...
                nirp.flowsheet.streamRole('role_reconnect/Middle'),"Feed") ;
        end

        function manualRoleOverridesConnectionsAndSignalsDoNotCount(testCase)
            createBareModel(testCase.Folder,'role_manual') ;
            addSystem('role_manual','Manual','nirp.blocks.Stream', ...
                [250 100 370 150],'Role','Feed') ;
            testCase.verifyEqual( ...
                nirp.flowsheet.streamRole('role_manual/Manual'),"Feed") ;
            addSystem('role_manual','Signal only','nirp.blocks.Stream', ...
                [250 220 370 270],'Role','Auto') ;
            add_block('simulink/Sources/Constant','role_manual/Signal', ...
                'Position',[50 225 100 255]) ;
            add_line('role_manual','Signal/1','Signal only/1') ;
            testCase.verifyEqual( ...
                nirp.flowsheet.streamRole('role_manual/Signal only'),"Unconnected") ;
            [status,message] = nirp.flowsheet.blockStatus( ...
                'role_manual/Signal only') ;
            testCase.verifyEqual(status,"warning") ;
            testCase.verifyEqual(message,"Stream is unconnected.") ;
            addSystem('role_manual','Hot reactor','nirp.blocks.CSTR', ...
                [50 330 170 390],'ShowHeatPort','on') ;
            addSystem('role_manual','Heat signal only','nirp.blocks.Stream', ...
                [250 335 370 385],'Role','Auto') ;
            add_line('role_manual','Hot reactor/2','Heat signal only/1') ;
            testCase.verifyEqual(nirp.flowsheet.streamRole( ...
                'role_manual/Heat signal only'),"Unconnected") ;
        end

        function inferredFeedWithoutDataHasClearDialogStatus(testCase)
            createBareModel(testCase.Folder,'missing_auto_feed') ;
            addSystem('missing_auto_feed','Fresh','nirp.blocks.Stream', ...
                [50 100 170 150],'Role','Auto') ;
            addSystem('missing_auto_feed','CSTR','nirp.blocks.CSTR', ...
                [250 90 370 160]) ;
            add_line('missing_auto_feed','Fresh/1','CSTR/1') ;
            dialog = nirp.flowsheet.StreamDialog( ...
                'missing_auto_feed/Fresh','Visible','off') ;
            testCase.addTeardown(@() deleteValid(dialog)) ;
            testCase.verifyEqual(dialog.getValue('Role'),"Feed") ;
            testCase.verifyEqual(string(dialog.RoleDropDown.Items{1}),"Feed (auto)") ;
            testCase.verifySubstring(dialog.getValue('Status'), ...
                "Feed data are not defined") ;
            dialog.RoleDropDown.Value = 'Product' ;
            feval(dialog.RoleDropDown.ValueChangedFcn,dialog.RoleDropDown,[]) ;
            testCase.verifyEqual(string(get_param( ...
                'missing_auto_feed/Fresh','Role')),"Product") ;
            testCase.verifyEqual(dialog.getValue('Role'),"Product") ;
        end

        function libraryContainsOneVisibleAutoStream(testCase)
            libraryFile = build_library(testCase.Folder) ;
            load_system(libraryFile) ;
            streams = find_system('NirpLibrary','SearchDepth',1, ...
                'BlockType','MATLABSystem','System','nirp.blocks.Stream') ;
            testCase.verifyNumElements(streams,1) ;
            testCase.verifyEqual(string(get_param(streams{1},'Name')),"Stream") ;
            testCase.verifyEqual(string(get_param(streams{1},'Role')),"Auto") ;
        end
    end
end

function createSeriesModel(folder,name)
    createBareModel(folder,name) ;
    addSystem(name,'F1','nirp.blocks.Stream',[20 100 140 150],'Role','Auto') ;
    addSystem(name,'CSTR 1','nirp.blocks.CSTR',[190 90 310 160], ...
        'V','100','VUnit','L') ;
    addSystem(name,'Middle','nirp.blocks.Stream',[360 100 480 150], ...
        'Role','Auto') ;
    addSystem(name,'CSTR 2','nirp.blocks.CSTR',[530 90 650 160], ...
        'V','100','VUnit','L') ;
    addSystem(name,'Product','nirp.blocks.Stream',[700 100 820 150], ...
        'Role','Auto') ;
    add_line(name,'F1/1','CSTR 1/1') ;
    add_line(name,'CSTR 1/1','Middle/1') ;
    add_line(name,'Middle/1','CSTR 2/1') ;
    add_line(name,'CSTR 2/1','Product/1') ;
end

function createBareModel(folder,name)
    pkg = nirp.pkg.examples.firstOrderLiquid() ;
    nirp.pkg.writeDictionary(pkg,fullfile(folder,[name '.sldd'])) ;
    new_system(name) ;
    save_system(name,fullfile(folder,[name '.slx'])) ;
    set_param(name,'DataDictionary',[name '.sldd']) ;
end

function addSystem(model,name,className,position,varargin)
    block = [model '/' name] ;
    add_block('simulink/User-Defined Functions/MATLAB System',block, ...
        'System',className,'Position',position,varargin{:}) ;
    if strcmp(className,'nirp.blocks.Stream')
        nirp.flowsheet.setupStreamBlock(block) ;
    else
        nirp.flowsheet.setupUnitBlock(block) ;
    end
end

function cleanup(testCase)
    bdclose('all') ; Simulink.data.dictionary.closeAll('-discard') ;
    figures = findall(groot,'Type','Figure') ;
    if ~isempty(figures), delete(figures) ; end
    evalin('base','clear nirpResults') ;
    Simulink.fileGenControl('setConfig','config',testCase.FileGenerationConfig) ;
    removePath(testCase.Folder) ; removePath(testCase.SimulinkFolder) ;
end

function removePath(folder)
    if contains([path pathsep],[folder pathsep]), rmpath(folder) ; end
end

function deleteValid(value)
    try
        if isvalid(value), delete(value) ; end
    catch
    end
end
