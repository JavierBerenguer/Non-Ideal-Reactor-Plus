function info = baseInfo(status)
%BASEINFO Create the common unit-operation information structure.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 1, 2026
% =========================================================================

    info = struct('heatDuty',0,'status',status,'message','', ...
        'warnings',{{}}) ;
end
