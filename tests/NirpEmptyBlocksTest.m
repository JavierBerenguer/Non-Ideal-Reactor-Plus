classdef NirpEmptyBlocksTest < matlab.unittest.TestCase
%NIRPEMPTYBLOCKSTEST Verifies that newly inserted library blocks are empty.
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
            fixture=testCase.applyFixture(TemporaryFolderFixture);testCase.Folder=fixture.Folder;
            testCase.FileGenerationConfig=Simulink.fileGenControl('getConfig');
            Simulink.fileGenControl('set','CacheFolder',fullfile(testCase.Folder,'cache'), ...
                'CodeGenFolder',fullfile(testCase.Folder,'codegen'),'createDir',true);
            testCase.addTeardown(@() cleanup(testCase));
        end
    end
    methods (Test)
        function libraryProcessValuesAreEmpty(testCase)
            simulinkFolder=fullfile(fileparts(fileparts(mfilename('fullpath'))),'simulink');addpath(simulinkFolder);
            testCase.addTeardown(@() rmpath(simulinkFolder));file=build_library(testCase.Folder);load_system(file);
            testCase.verifyEqual(get_param('NirpLibrary/Stream','Role'),'Select...');
            testCase.verifyTrue(isnan(str2double(get_param('NirpLibrary/CSTR','V'))));
            testCase.verifyEqual(get_param('NirpLibrary/CSTR','HeatMode'),'Select...');
            testCase.verifyTrue(all(isnan(str2num(get_param('NirpLibrary/Splitter','Fractions'))))); %#ok<ST2NM>
            testCase.verifyTrue(isnan(str2double(get_param('NirpLibrary/Separator','Recovery'))));
            testCase.verifyEqual(get_param('NirpLibrary/Heater','Mode'),'Select...');
            testCase.verifyTrue(isnan(str2double(get_param('NirpLibrary/Heater','Tout'))));
            testCase.verifyEqual(get_param('NirpLibrary/Jacket','Mode'),'Select...');
            testCase.verifyEqual(get_param('NirpLibrary/Recycle','Method'),'Select...');
            testCase.verifyEqual(get_param('NirpLibrary/Adjust','TargetVariable'),'Select...');
            mask=Simulink.Mask.get('NirpLibrary/Splitter');parameter=mask.getParameter('Specifications');
            testCase.verifyNotEmpty(parameter);
            testCase.verifyEqual(parameter.Visible,'off');
        end

        function incompleteCstrNamesItsMissingSpecification(testCase)
            nirp.flowsheet.new('empty_cstr',nirp.pkg.examples.firstOrderLiquid(),testCase.Folder,'OpenModel',false);
            load_system(fullfile(testCase.Folder,'empty_cstr.slx'));
            add_block('simulink/User-Defined Functions/MATLAB System','empty_cstr/R1', ...
                'System','nirp.blocks.CSTR','V','NaN','HeatMode','Isothermal','Position',[220 120 330 180]);
            add_block('simulink/User-Defined Functions/MATLAB System','empty_cstr/Product', ...
                'System','nirp.blocks.Stream','Role','Product','Position',[420 120 540 180]);
            add_line('empty_cstr','F1/1','R1/1');add_line('empty_cstr','R1/1','Product/1');
            try
                sim('empty_cstr');testCase.assertFail('The incomplete CSTR simulated.');
            catch exception
                messages=string(exception.message);for i=1:numel(exception.cause),messages(end+1)=string(exception.cause{i}.message);end
                testCase.verifyTrue(any(contains(messages,'CSTR "R1": 1 specification missing: V')));
            end
        end
    end
end

function cleanup(testCase)
    bdclose('all');Simulink.data.dictionary.closeAll('-discard');
    figures=findall(groot,'Type','Figure');if ~isempty(figures),delete(figures);end
    evalin('base','clear nirpResults');Simulink.fileGenControl('setConfig','config',testCase.FileGenerationConfig);
end
