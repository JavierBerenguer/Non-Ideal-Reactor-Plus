classdef NirpDofClosureTest < matlab.unittest.TestCase
%NIRPDOFCLOSURETEST Tests simple Splitter degree-of-freedom closure.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 3, 2026. Last update: October 3, 2026
% =========================================================================
    properties
        Folder
        FileGenerationConfig
    end

    methods (TestMethodSetup)
        function setup(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture=testCase.applyFixture(TemporaryFolderFixture);
            testCase.Folder=fixture.Folder;
            addpath(testCase.Folder);
            testCase.FileGenerationConfig=Simulink.fileGenControl('getConfig');
            Simulink.fileGenControl('set', ...
                'CacheFolder',fullfile(testCase.Folder,'cache'), ...
                'CodeGenFolder',fullfile(testCase.Folder,'codegen'), ...
                'createDir',true);
            testCase.addTeardown(@() cleanup(testCase));
        end
    end

    methods (Test)
        function closeSumCompletesOneMissingFraction(testCase)
            [values,origin,message]=nirp.flowsheet.closeSum( ...
                [0.5 0.25 NaN],1);
            testCase.verifyEqual(values,[0.5 0.25 0.25],'AbsTol',1e-15);
            testCase.verifyEqual(origin, ...
                ["specified" "specified" "calculated"]);
            testCase.verifyEqual(message,"");
        end

        function closeSumReportsInvalidSpecifications(testCase)
            input=[0.5 NaN NaN];
            [actual,~,message]=nirp.flowsheet.closeSum(input,1);
            testCase.verifyTrue(isequaln(actual,input));
            testCase.verifyEqual(message, ...
                "2 fractions are missing; specify at least 1 more.");

            [~,~,message]=nirp.flowsheet.closeSum([0.7 0.5 NaN],1);
            testCase.verifyEqual(message, ...
                "Known fractions add up to 1.2 (> 1).");
            [~,~,message]=nirp.flowsheet.closeSum([0.5 0.4],1);
            testCase.verifyEqual(message, ...
                "Fractions add up to 0.9; they must add up to 1.");
            [~,~,message]=nirp.flowsheet.closeSum([-0.1 1.1],1);
            testCase.verifyEqual(message,"Fractions cannot be negative.");
            [~,~,message]=nirp.flowsheet.closeSum([0.2 1.1],1);
            testCase.verifyEqual(message,"Fractions cannot exceed 1.");
        end

        function splitterDialogCompletesAndRejectsMissingFractions(testCase)
            createModel(testCase,'dialog_dof');
            addSystem('dialog_dof','Splitter','nirp.blocks.Splitter', ...
                [180 80 300 170]);
            dialog=nirp.flowsheet.SplitterDialog( ...
                'dialog_dof/Splitter','Visible','off');
            testCase.addTeardown(@() deleteValid(dialog));

            dialog.setFractions([0.5 0.25 NaN]);
            values=dialog.getValues();
            testCase.verifyEqual(values.Fractions.value, ...
                [0.5 0.25 0.25],'AbsTol',1e-15);
            testCase.verifyEqual(values.Fractions.origin, ...
                ["specified" "specified" "calculated"]);
            data=dialog.FractionTable.Data;
            data{3,2}=0.25;
            dialog.FractionTable.Data=data;
            event=struct('Indices',[3 2]);
            feval(dialog.FractionTable.CellEditCallback, ...
                dialog.FractionTable,event);
            testCase.verifyEqual(dialog.getValues().Fractions.origin, ...
                repmat("specified",1,3));
            dialog.setFractions([0.5 0.25 NaN]);
            dialog.accept();
            testCase.verifyFalse(isvalid(dialog));
            testCase.verifyEqual( ...
                str2num(get_param('dialog_dof/Splitter','Fractions')), ... %#ok<ST2NM>
                [0.5 0.25 0.25],'AbsTol',1e-15);

            dialog=nirp.flowsheet.SplitterDialog( ...
                'dialog_dof/Splitter','Visible','off');
            testCase.addTeardown(@() deleteValid(dialog));
            dialog.setFractions([0.5 NaN NaN]);
            dialog.accept();
            testCase.verifyTrue(isvalid(dialog));
            testCase.verifyEqual(dialog.StatusLabel.Text, ...
                '2 fractions are missing; specify at least 1 more.');
            testCase.verifyEqual( ...
                str2num(get_param('dialog_dof/Splitter','Fractions')), ... %#ok<ST2NM>
                [0.5 0.25 0.25],'AbsTol',1e-15);
        end

        function splitterBlockClosesNaNAndConservesFlow(testCase)
            createModel(testCase,'block_dof');
            addSystem('block_dof','Splitter','nirp.blocks.Splitter', ...
                [180 120 300 220],'Fractions','[0.5 0.25 NaN]');
            fractions=[0.5 0.25 0.25];
            for i=1:3
                name=sprintf('Product%d',i);
                addSystem('block_dof',name,'nirp.blocks.Stream', ...
                    [390 40+100*i 500 85+100*i],'Role','Product');
                add_line('block_dof',sprintf('Splitter/%d',i), ...
                    sprintf('%s/1',name));
            end
            add_line('block_dof','F1/1','Splitter/1');
            sim('block_dof');
            feed=nirp.pkg.feedStream(nirp.pkg.examples.firstOrderLiquid(),"F1");
            total=zeros(size(feed.F));
            for i=1:3
                result=evalin('base',sprintf( ...
                    'nirpResults.Streams.Product%d.streamSI',i));
                testCase.verifyEqual(result.F,feed.F*fractions(i), ...
                    'AbsTol',1e-12);
                total=total+result.F;
            end
            testCase.verifyEqual(total,feed.F,'AbsTol',1e-12);
        end
    end
end

function createModel(testCase,name)
    nirp.flowsheet.new(name,nirp.pkg.examples.firstOrderLiquid(), ...
        testCase.Folder,'OpenModel',false);
    load_system(fullfile(testCase.Folder,[name '.slx']));
end

function addSystem(model,name,className,position,varargin)
    add_block('simulink/User-Defined Functions/MATLAB System', ...
        [model '/' name],'System',className,'Position',position,varargin{:});
    if strcmp(className,'nirp.blocks.Stream')
        nirp.flowsheet.setupStreamBlock([model '/' name]);
    else
        nirp.flowsheet.setupUnitBlock([model '/' name]);
    end
end

function cleanup(testCase)
    bdclose('all');
    Simulink.data.dictionary.closeAll('-discard');
    figures=findall(groot,'Type','Figure');
    if ~isempty(figures)
        delete(figures);
    end
    evalin('base','clear nirpResults');
    rmpath(testCase.Folder);
    Simulink.fileGenControl('setConfig','config', ...
        testCase.FileGenerationConfig);
end

function deleteValid(value)
    try
        if isvalid(value)
            delete(value);
        end
    catch
    end
end
