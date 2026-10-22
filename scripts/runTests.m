% runTests - Run the project test suite from any working folder.
%
% Usage (from the repository root):
%   matlab -batch "run('scripts/runTests.m')"
% Set NIRP_SKIP_INTERACTIVE=1 to omit tests that require visible windows or
% matlab.uitest gestures. By default, the complete suite is selected.
%
% Adds only the repository root to the path (never genpath: the C__ folder
% would shadow MATLAB's userpath) and fails with a non-zero exit code if any
% test fails, so it can be used by Claude and Codex as the verification step.
% =========================================================================
% Javier Berenguer Sabater
% Created: September 30, 2026. Last update: October 22, 2026
% =========================================================================

repoRoot = fileparts(fileparts(mfilename('fullpath'))) ;
addpath(repoRoot) ;

testsDir = fullfile(repoRoot, 'tests') ;
if ~isfolder(testsDir)
    error('runTests:noTests', 'Tests folder not found: %s', testsDir) ;
end

suite = testsuite(testsDir, 'IncludeSubfolders', true) ;
if strcmp(getenv('NIRP_SKIP_INTERACTIVE'), '1')
    suite = suite.selectIf( ...
        ~matlab.unittest.selectors.HasTag('Interactive')) ;
end
suite = sortByFixtures(suite) ;
usesExamples = arrayfun(@(test) any(arrayfun(@(fixture) ...
    isa(fixture,'nirptest.ExamplesFixture'),test.SharedTestFixtures)),suite) ;
suite = suite([find(usesExamples) find(~usesExamples)]) ;
results = run(suite) ;
disp(table(results)) ;
assertSuccess(results) ;
