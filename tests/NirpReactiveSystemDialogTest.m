classdef NirpReactiveSystemDialogTest < matlab.unittest.TestCase
%NIRPPACKAGEEDITORTEST Tests for the graphical package editor.
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
            fixture=testCase.applyFixture(TemporaryFolderFixture) ;
            testCase.Folder=fixture.Folder ; addpath(testCase.Folder) ;
            testCase.FileGenerationConfig=Simulink.fileGenControl('getConfig') ;
            Simulink.fileGenControl('set','CacheFolder',fullfile(testCase.Folder,'cache'), ...
                'CodeGenFolder',fullfile(testCase.Folder,'codegen'),'createDir',true) ;
            testCase.addTeardown(@() cleanup(testCase)) ;
        end
    end

    methods (Test)
        function examplesRoundTrip(testCase)
            ed=nirp.flowsheet.ReactiveSystemDialog('Visible','off') ;
            testCase.addTeardown(@() deleteValid(ed)) ;
            examples={nirp.pkg.examples.firstOrderLiquid(), ...
                nirp.pkg.examples.problem40Gas()} ;
            for i=1:numel(examples)
                ed.setPackage(examples{i}) ; actual=ed.getPackage() ;
                nirp.pkg.validate(actual) ; testCase.verifyTrue(isequal(actual,examples{i})) ;
            end
        end

        function tablesProduceMixedUnitPackage(testCase)
            ed=nirp.flowsheet.ReactiveSystemDialog('Visible','off') ;
            testCase.addTeardown(@() deleteValid(ed)) ;
            ed.ComponentTable.Data={'A',[],'constant','100','J/(mol*K)'; ...
                'B',[],'constant','100','J/(mol*K)'} ;
            ed.ReactionTable.Data={-1,1,-50,'kJ/mol','powerlaw',0.6,0, ...
                'J/mol','1 0',[],[],'J/mol','',''} ;
            ed.ConcentrationUnitDropDown.Value='mol/L' ;
            ed.TimeUnitDropDown.Value='min' ; ed.TrefField.Value=26.85 ;
            ed.TrefUnitDropDown.Value=[char(176) 'C'] ;
            ed.FeedTable.Data={'F1','L',26.85,[char(176) 'C'],1,'atm', ...
                'molarFlows','60 0','mol/min',60,'L/min'} ;
            pkg=ed.getPackage() ; nirp.pkg.validate(pkg) ;
            feed=nirp.pkg.feedStream(pkg,"F1") ; rs=nirp.pkg.toReactionSys(pkg) ;
            rs=rs.computeRate([1000 0],300) ;
            expected=nirp.pkg.toReactionSys(nirp.pkg.examples.firstOrderLiquid()) ;
            expected=expected.computeRate([1000 0],300) ;
            testCase.verifyEqual(feed.F,[1;0],'AbsTol',1e-15) ;
            testCase.verifyEqual(feed.T,300,'AbsTol',1e-12) ;
            testCase.verifyEqual(feed.Q,1e-3,'AbsTol',1e-18) ;
            testCase.verifyEqual(rs.r_i,expected.r_i,'RelTol',1e-14) ;
        end

        function validationReturnsMessage(testCase)
            ed=nirp.flowsheet.ReactiveSystemDialog('Visible','off') ;
            testCase.addTeardown(@() deleteValid(ed)) ;
            data=ed.ComponentTable.Data ; data{1,1}='' ; ed.ComponentTable.Data=data ;
            [valid,message]=ed.validate() ;
            testCase.verifyFalse(valid) ; testCase.verifySubstring(message,'components(1).name') ;
        end

        function createsAndSimulatesFlowsheet(testCase)
            ed=nirp.flowsheet.ReactiveSystemDialog('Visible','off') ;
            testCase.addTeardown(@() deleteValid(ed)) ;
            ed.createFlowsheet('editor_model',testCase.Folder,'OpenModel',false) ;
            load_system(fullfile(testCase.Folder,'editor_model.slx')) ;
            add_block('simulink/User-Defined Functions/MATLAB System','editor_model/CSTR', ...
                'System','nirp.blocks.CSTR','Position',[210 140 310 200]) ;
            set_param('editor_model/CSTR','V','100','VUnit','L','HeatMode','Isothermal') ;
            add_block('simulink/User-Defined Functions/MATLAB System','editor_model/Product', ...
                'System','nirp.blocks.Stream','Position',[380 140 520 200], ...
                'Role','Product','ReferenceFeed','F1','KeyComponent','A') ;
            add_line('editor_model','F1/1','CSTR/1') ; add_line('editor_model','CSTR/1','Product/1') ;
            save_system('editor_model') ; sim('editor_model') ;
            result=evalin('base','nirpResults.Streams.Product') ;
            testCase.verifyEqual(result.conversion,0.5,'AbsTol',1e-8) ;
        end

        function savesModelAndRegeneratesBus(testCase)
            ed=nirp.flowsheet.ReactiveSystemDialog('Visible','off') ;
            testCase.addTeardown(@() deleteValid(ed)) ;
            ed.createFlowsheet('edit_model',testCase.Folder,'OpenModel',false) ;
            load_system(fullfile(testCase.Folder,'edit_model.slx')) ;
            pkg=nirp.pkg.examples.problem40Gas() ; ed.setPackage(pkg) ;
            changed=ed.saveToModel('edit_model') ; testCase.verifyTrue(changed) ;
            dictionary=Simulink.data.dictionary.open(fullfile(testCase.Folder,'edit_model.sldd')) ;
            section=getSection(dictionary,'Design Data') ;
            bus=getValue(getEntry(section,'NirpStream')) ;
            testCase.verifyEqual(bus.Elements(1).Dimensions,[4 1]) ; close(dictionary) ;
        end

        function maskAndAppOpenEditor(testCase)
            new_system('mask_model') ; testCase.addTeardown(@() close_system('mask_model',0)) ;
            block=nirp.flowsheet.addBlock('mask_model') ; mask=Simulink.Mask.get(block) ;
            testCase.verifyNotEmpty(mask.getDialogControl('EditPackage')) ;
            app=NonIdealReactorApp() ; testCase.addTeardown(@() deleteValid(app)) ;
            fig=findall(groot,'Type','Figure','Name','Non-Ideal Reactor Analysis') ;
            set(fig,'Visible','off') ; menu=findall(fig,'Type','uimenu','Text','New flowsheet...') ;
            feval(menu.MenuSelectedFcn,menu,[]) ;
            editor=findall(groot,'Type','Figure','Tag','NirpReactiveSystemDialog') ;
            testCase.verifyNumElements(editor,1) ; delete(editor) ;
        end
    end
end

function cleanup(testCase)
    bdclose('all') ; Simulink.data.dictionary.closeAll('-discard') ;
    figures=findall(groot,'Type','Figure') ; if ~isempty(figures),delete(figures);end
    evalin('base','clear nirpResults') ; rmpath(testCase.Folder) ;
    Simulink.fileGenControl('setConfig','config',testCase.FileGenerationConfig) ;
end
function deleteValid(value)
    try
        if isvalid(value), delete(value) ; end
    catch
    end
end
