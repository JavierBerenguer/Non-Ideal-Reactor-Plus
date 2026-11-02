function data = readTwoColumnFile(path, description)
% readTwoColumnFile reads the first two columns of tracer input data.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 23, 2026. Last update: October 23, 2026
% =========================================================================
if nargin < 2
    description = 'Tracer';
end
data = readmatrix(path) ;
if size(data, 2) < 2
    error('nirp:tracerflowsheet:InvalidImport', ...
        '%s data needs two columns.', description) ;
end
data = data(:, 1:2) ;
end
