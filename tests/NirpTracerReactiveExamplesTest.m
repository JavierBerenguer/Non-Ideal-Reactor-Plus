classdef NirpTracerReactiveExamplesTest < matlab.unittest.TestCase
    % Regression tests for the tracer-only example catalogue.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 25, 2026. Last update: November 3, 2026
    % =========================================================================
    properties,Folder;end
    methods (TestMethodSetup)
        function setup(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);testCase.Folder=fixture.Folder;
            addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'simulink'));
            testCase.addTeardown(@()cleanup());
        end
    end
    methods (Test)
        function catalogueContainsOnlyNetworkRtdExamples(testCase)
            [names,descriptions]=nirp.tracerflowsheet.exampleNames();
            testCase.verifyEqual(names,["tracer_two_cstr";"tracer_pfr_cstr_parallel";"tracer_sec01_series"]);
            testCase.verifyNumElements(descriptions,3);testCase.verifyFalse(any(contains(lower(descriptions),'react')));
        end
        function validationRetainsEmptySecondOutput(testCase)
            [tracer,reactive]=run_tracer_validation(testCase.Folder);
            testCase.verifySize(tracer,[3 5]);testCase.verifyLessThanOrEqual(tracer.maxAbsError,5e-3);
            expected=[0.00495029044116332 3.98003170645992 7.99987146580811; ...
                2.77555756156289e-17 2.99246004405519 6.74806141059418; ...
                4.31010524493125e-09 8.47510311034014 7.74933760397484];
            testCase.verifyEqual([tracer.maxAbsError tracer.tau tracer.sigma2],expected,'AbsTol',1e-12);
            testCase.verifyEmpty(reactive);testCase.verifyNumElements(build_tracer_examples(testCase.Folder),3);
        end
    end
end
function cleanup(),bdclose('all');Simulink.data.dictionary.closeAll('-discard');evalin('base','clear nirpTracerResults');end
