classdef NirpRecycleDialogTest < matlab.unittest.TestCase
%NIRPRECYCLEDIALOGTEST Verifies the Recycle dialog and results (T-142).
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
        function dialogSavesAndResultsReportConvergence(testCase)
            name='recycle_dialog';buildLoop(testCase.Folder,name,200);
            dialog=nirp.flowsheet.RecycleDialog([name '/Recycle'],'Visible','off');testCase.addTeardown(@() deleteValid(dialog));
            testCase.verifyEqual(string(dialog.Figure.WindowStyle),"alwaysontop");
            testCase.verifyEqual(dialog.MethodDropDown.Value,'Wegstein');
            testCase.verifyEqual(dialog.TearInLabel.Text,'Recycled');testCase.verifyEqual(dialog.TearOutLabel.Text,'Mixer');
            dialog.setValues('Tolerance',1e-9);testCase.verifyTrue(dialog.apply());
            testCase.verifyEqual(str2double(get_param([name '/Recycle'],'Tolerance')),1e-9);
            sim(name);tables=nirp.flowsheet.showResults(name,'NoWindow',true);row=tables.Recycles;
            testCase.verifyEqual(height(row),1);testCase.verifyEqual(row.Converged,1);
            testCase.verifyGreaterThan(row.Iterations,0);testCase.verifyLessThanOrEqual(row.FinalError,1e-9);
            testCase.verifyEqual(row.TearStream,"Recycled -> Mixer");
        end
        function notConvergedShowsFinalError(testCase)
            name='recycle_short';buildLoop(testCase.Folder,name,3);
            set_param([name '/Recycle'],'Method','Direct','Tolerance','1e-14');
            warning('off','all');testCase.addTeardown(@() warning('on','all'));sim(name);
            tables=nirp.flowsheet.showResults(name,'NoWindow',true);
            testCase.verifyEqual(tables.Recycles.Converged,0);
            testCase.verifyTrue(any(contains(tables.Messages{:,end},"Final relative error")));
        end
    end
end
function buildLoop(folder,name,maxIterations)
    nirp.flowsheet.new(name,nirp.pkg.examples.firstOrderLiquid(),folder,'OpenModel',false);load_system(fullfile(folder,[name '.slx']));
    flowsheets=find_system(name,'SearchDepth',1,'BlockType','SubSystem','Mask','on');
    for i=1:numel(flowsheets),if any(strcmp(get_param(flowsheets{i},'MaskNames'),'MaxIterations')),set_param(flowsheets{i},'MaxIterations',num2str(maxIterations));end,end
    delete_line(find_system(name,'FindAll','on','SearchDepth',1,'Type','line'));
    starters=find_system(name,'SearchDepth',1,'BlockType','MATLABSystem');for i=1:numel(starters),delete_block(starters{i});end
    add(name,'F1','nirp.blocks.Stream',[20 150 100 200],'Role','Feed');
    add(name,'Mixer','nirp.blocks.Mixer',[150 130 250 210]);
    add(name,'Mixed','nirp.blocks.Stream',[280 150 340 190],'Role','Intermediate');
    add(name,'CSTR','nirp.blocks.CSTR',[370 135 470 205],'V','0.1');
    add(name,'Out','nirp.blocks.Stream',[500 150 560 190],'Role','Intermediate');
    add(name,'Splitter','nirp.blocks.Splitter',[590 125 690 215],'Fractions','[0.5 0.5]');
    add(name,'Product','nirp.blocks.Stream',[740 130 820 170],'Role','Product');
    add(name,'Recycled','nirp.blocks.Stream',[740 260 820 300],'Role','Intermediate');
    add(name,'Recycle','nirp.blocks.Recycle',[450 270 590 330],'Method','Wegstein','QMin','-1000');
    add_line(name,'F1/1','Mixer/1');add_line(name,'Recycle/1','Mixer/2');add_line(name,'Mixer/1','Mixed/1');add_line(name,'Mixed/1','CSTR/1');
    add_line(name,'CSTR/1','Out/1');add_line(name,'Out/1','Splitter/1');add_line(name,'Splitter/1','Product/1');
    add_line(name,'Splitter/2','Recycled/1');add_line(name,'Recycled/1','Recycle/1');
    nirp.flowsheet.configure(name);
end
function add(model,name,className,position,varargin),add_block('simulink/User-Defined Functions/MATLAB System',[model '/' name],'System',className,'Position',position,varargin{:});if ~strcmp(className,'nirp.blocks.Stream'),nirp.flowsheet.setupUnitBlock([model '/' name]);end,end
function cleanup(testCase),bdclose('all');Simulink.data.dictionary.closeAll('-discard');evalin('base','clear nirpResults');if contains([path pathsep],[testCase.Folder pathsep]),rmpath(testCase.Folder);end,end
function deleteValid(value),try,if isvalid(value),delete(value);end,catch,end,end
