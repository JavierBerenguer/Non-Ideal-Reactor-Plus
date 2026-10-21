function factor = timeFactor(unit)
%TIMEFACTOR Convert a supported display time unit to seconds.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================
    switch lower(strtrim(char(string(unit))))
        case {'s','sec','second','seconds'}, factor = 1 ;
        case {'min','minute','minutes'}, factor = 60 ;
        case {'h','hr','hour','hours'}, factor = 3600 ;
        otherwise, error('nirp:tracerflowsheet:InvalidTimeUnit','Time unit must be s, min, or h.') ;
    end
end
