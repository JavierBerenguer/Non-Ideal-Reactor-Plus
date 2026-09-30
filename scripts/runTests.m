% runTests - Run the project test suite from any working folder.
%
% Usage (from the repository root):
%   matlab -batch "run('scripts/runTests.m')"
%
% Adds only the repository root to the path (never genpath: the C__ folder
% would shadow MATLAB's userpath) and fails with a non-zero exit code if any
% test fails, so it can be used by Claude and Codex as the verification step.
% =========================================================================
% Javier Berenguer Sabater
% Created: September 30, 2026. Last update: September 30, 2026
% =========================================================================

repoRoot = fileparts(fileparts(mfilename('fullpath'))) ;
addpath(repoRoot) ;

testsDir = fullfile(repoRoot, 'tests') ;
if ~isfolder(testsDir)
    error('runTests:noTests', 'Tests folder not found: %s', testsDir) ;
end

results = runtests(testsDir, 'IncludeSubfolders', true) ;
disp(table(results)) ;
assertSuccess(results) ;
