function E = rtdSession(grid,filePath)
%RTDSESSION Load an RTD from a NonIdealReactorApp MAT session.
%   FILEPATH must contain sessionData.shared.rtd as an RTD or serialized
%   RTD structure. Session time and E values use SI units.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================

    grid = nirp.tracer.validateGrid(grid) ;
    if ~(ischar(filePath) || (isstring(filePath) && isscalar(filePath)))
        error('nirp:tracer:InvalidSession','Session path must be text.') ;
    end
    if ~isfile(filePath)
        error('nirp:tracer:InvalidSession','Session file does not exist.') ;
    end
    loaded = load(char(filePath),'sessionData') ;
    if ~isfield(loaded,'sessionData') || ~isstruct(loaded.sessionData) || ...
            ~isfield(loaded.sessionData,'shared') || ...
            ~isfield(loaded.sessionData.shared,'rtd')
        error('nirp:tracer:InvalidSession', ...
            'MAT file does not contain a NonIdealReactorApp session RTD.') ;
    end
    value = loaded.sessionData.shared.rtd ;
    if isa(value,'RTD')
        t = value.t ;
        Et = value.Et ;
    elseif isstruct(value) && all(isfield(value,{'t','Et'}))
        t = value.t ;
        Et = value.Et ;
    else
        error('nirp:tracer:InvalidSession','Session does not contain a usable RTD.') ;
    end
    if isempty(t) || isempty(Et)
        error('nirp:tracer:InvalidSession','Session RTD is empty.') ;
    end
    E = nirp.tracer.rtdData(grid,t,Et) ;
end
