function openLibrary()
%OPENLIBRARY Open the separate tracer block library.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================
    root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
    file=fullfile(root,'simulink','NirpTracerLibrary.slx');
    if ~isfile(file),addpath(fullfile(root,'simulink'));build_tracer_library(fullfile(root,'simulink'));end
    load_system(file);open_system('NirpTracerLibrary');
end
