classdef NirpSeparatorTest < matlab.unittest.TestCase
%NIRPSEPARATORTEST Verifies the component Separator (T-141).
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
        function coreConservesEveryComponent(testCase)
            pkg=nirp.pkg.examples.problem36AirCooled();rs=nirp.pkg.toReactionSys(pkg);in=nirp.pkg.feedStream(pkg,pkg.feeds(1).name);
            recovery=linspace(0,1,rs.nComponents);
            [out,info]=nirp.units.separator(struct('recovery',recovery),in,rs);
            testCase.verifyEqual(out{1}.F+out{2}.F,in.F,'AbsTol',1e-14);
            testCase.verifyEqual(out{1}.F,in.F.*reshape(recovery,size(in.F)),'AbsTol',1e-14);
            testCase.verifyEqual([out{1}.T out{2}.T out{1}.P out{2}.P],[in.T in.T in.P in.P]);
            testCase.verifyEqual(info.heatDuty,0);
            all=nirp.units.separator(struct('recovery',1),in,rs);testCase.verifyEqual(all{1}.F,in.F,'AbsTol',1e-14);testCase.verifyEqual(sum(all{2}.F),0);
            testCase.verifyError(@() nirp.units.separator(struct('recovery',[0.5 0.5]),in,rs),'nirp:units:invalidRecovery');
            testCase.verifyError(@() nirp.units.separator(struct('recovery',1.2),in,rs),'nirp:units:invalidRecovery');
        end
        function blockMatchesCoreAndDialogSavesRecovery(testCase)
            pkg=nirp.pkg.examples.problem36AirCooled();name='separator_model';feed=char(pkg.feeds(1).name);
            nirp.pkg.writeDictionary(pkg,fullfile(testCase.Folder,[name '.sldd']));new_system(name);
            save_system(name,fullfile(testCase.Folder,[name '.slx']));set_param(name,'DataDictionary',[name '.sldd']);
            addSystem(name,feed,'nirp.blocks.Stream',[20 100 140 150],'Role','Feed');
            addSystem(name,'Separator','nirp.blocks.Separator',[220 90 340 170]);
            addSystem(name,'Top','nirp.blocks.Stream',[430 60 550 110],'Role','Product');
            addSystem(name,'Bottom','nirp.blocks.Stream',[430 160 550 210],'Role','Product');
            add_line(name,[feed '/1'],'Separator/1');add_line(name,'Separator/1','Top/1');add_line(name,'Separator/2','Bottom/1');
            nirp.flowsheet.configure(name);
            nComp=numel(pkg.components);recovery=linspace(0.1,0.9,nComp);
            dialog=nirp.flowsheet.SeparatorDialog([name '/Separator'],'Visible','off');testCase.addTeardown(@() deleteValid(dialog));
            testCase.verifyEqual(string(dialog.Figure.WindowStyle),"alwaysontop");
            dialog.setRecovery(recovery);testCase.verifyTrue(dialog.apply());
            testCase.verifyEqual(str2num(get_param([name '/Separator'],'Recovery')),recovery,'AbsTol',1e-15); %#ok<ST2NM>
            sim(name);results=evalin('base','nirpResults');
            expected=nirp.units.separator(struct('recovery',recovery),nirp.pkg.feedStream(pkg,feed),nirp.pkg.toReactionSys(pkg));
            testCase.verifyEqual(results.Streams.Top.streamSI.F,expected{1}.F,'RelTol',1e-12,'AbsTol',1e-14);
            testCase.verifyEqual(results.Streams.Bottom.streamSI.F,expected{2}.F,'RelTol',1e-12,'AbsTol',1e-14);
            set_param([name '/Top'],'Role','Auto');testCase.verifyEqual(nirp.flowsheet.streamRole([name '/Top']),"Product");
        end
    end
end
function addSystem(model,name,className,position,varargin),add_block('simulink/User-Defined Functions/MATLAB System',[model '/' name],'System',className,'Position',position,varargin{:});if ~strcmp(className,'nirp.blocks.Stream'),nirp.flowsheet.setupUnitBlock([model '/' name]);end,end
function cleanup(testCase),bdclose('all');Simulink.data.dictionary.closeAll('-discard');evalin('base','clear nirpResults');if contains([path pathsep],[testCase.Folder pathsep]),rmpath(testCase.Folder);end,end
function deleteValid(value),try,if isvalid(value),delete(value);end,catch,end,end
