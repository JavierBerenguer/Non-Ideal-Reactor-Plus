classdef NirpReactionSelectionTest < matlab.unittest.TestCase
%NIRPREACTIONSELECTIONTEST Verifies reactions per reactor (T-147).
% =========================================================================
% Javier Berenguer Sabater
% Created: October 10, 2026. Last update: October 10, 2026
% =========================================================================
    properties
        Folder
    end
    methods (TestMethodSetup)
        function setup(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture=testCase.applyFixture(TemporaryFolderFixture);testCase.Folder=fixture.Folder;addpath(testCase.Folder);
            testCase.addTeardown(@() cleanup(testCase));
        end
    end
    methods (Test)
        function subsetKeepsSelectedReactions(testCase)
            pkg=nirp.pkg.examples.problem36AirCooled();
            sub=nirp.pkg.selectReactions(pkg,'[2]');
            testCase.verifyEqual(sub.reactions.stoich,pkg.reactions.stoich(2,:));
            testCase.verifyEqual(sub.reactions.DH.value,pkg.reactions.DH.value(2));
            testCase.verifyEqual(nirp.pkg.selectReactions(pkg,''),pkg);
            testCase.verifyError(@() nirp.pkg.selectReactions(pkg,'[0]'),'nirp:pkg:invalidReactionSelection');
            testCase.verifyError(@() nirp.pkg.selectReactions(pkg,[1 1]),'nirp:pkg:invalidReactionSelection');
        end
        function cstrUsesOnlySelectedReactionsAndDialogSavesThem(testCase)
            pkg=parallelPackage();name='reaction_subset';
            nirp.pkg.writeDictionary(pkg,fullfile(testCase.Folder,[name '.sldd']));new_system(name);
            save_system(name,fullfile(testCase.Folder,[name '.slx']));set_param(name,'DataDictionary',[name '.sldd']);
            feedName=char(pkg.feeds(1).name);
            addSystem(name,feedName,'nirp.blocks.Stream',[20 100 140 150],'Role','Feed');
            addSystem(name,'CSTR','nirp.blocks.CSTR',[220 90 360 160],'V','0.2','VUnit','m^3','HeatMode','Isothermal');
            addSystem(name,'Product','nirp.blocks.Stream',[430 100 550 150],'Role','Product');
            add_line(name,[feedName '/1'],'CSTR/1');add_line(name,'CSTR/1','Product/1');nirp.flowsheet.configure(name);
            dialog=nirp.flowsheet.ReactorDialog([name '/CSTR'],'Visible','off');testCase.addTeardown(@() deleteValid(dialog));
            testCase.verifyEqual(cell2mat(dialog.ReactionsTable.Data(:,1))',[true true]);
            dialog.setValues('Reactions','[2]');testCase.verifyTrue(dialog.apply());
            testCase.verifyEqual(get_param([name '/CSTR'],'Reactions'),'[2]');
            sim(name);results=evalin('base','nirpResults');actual=results.Streams.Product.streamSI;
            feed=nirp.pkg.feedStream(pkg,feedName);params=struct('V',0.2,'heatMode','Isothermal');
            expected=nirp.units.cstr(params,feed,nirp.pkg.toReactionSys(nirp.pkg.selectReactions(pkg,2)));
            all=nirp.units.cstr(params,feed,nirp.pkg.toReactionSys(pkg));
            testCase.verifyEqual(actual.F,expected.F,'RelTol',1e-10,'AbsTol',1e-14);
            testCase.verifyGreaterThan(max(abs(actual.F-all.F)),1e-9);
        end
    end
end
function pkg=parallelPackage()
    % A -> B and A -> C, both first order, so each reaction changes the outlet.
    pkg=nirp.pkg.examples.firstOrderLiquid();pkg.meta.name="Parallel A";
    pkg.components(3)=pkg.components(2);pkg.components(3).name="C";
    pkg.reactions.stoich=[-1 1 0;-1 0 1];pkg.reactions.DH.value=[-50 -50];
    kinetic=pkg.reactions.kinetics;kinetic.orders=[1 0 0];second=kinetic;second.k0=0.3;
    pkg.reactions.kinetics=[kinetic second];pkg.feeds.values=[60 0 0];nirp.pkg.validate(pkg);
end
function addSystem(model,name,className,position,varargin),add_block('simulink/User-Defined Functions/MATLAB System',[model '/' name],'System',className,'Position',position,varargin{:});if ~strcmp(className,'nirp.blocks.Stream'),nirp.flowsheet.setupUnitBlock([model '/' name]);end,end
function cleanup(testCase),bdclose('all');Simulink.data.dictionary.closeAll('-discard');evalin('base','clear nirpResults');if contains([path pathsep],[testCase.Folder pathsep]),rmpath(testCase.Folder);end,end
function deleteValid(value),try,if isvalid(value),delete(value);end,catch,end,end
