function grid = gridForBlock(block)
%GRIDFORBLOCK Read the SI common grid stored on a tracer block.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================
    dt = str2double(get_param(block,'Dt')) ;
    final = str2double(get_param(block,'TFinal')) ;
    grid = nirp.tracer.grid(dt,final) ;
end
