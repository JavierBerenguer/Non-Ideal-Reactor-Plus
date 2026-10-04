function s = refresh(s)
%REFRESH Validate a NIRP stream and refresh its gas flow in m^3/s.
%   Liquid volumetric flow is left unchanged.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 1, 2026
% =========================================================================

    expected = {'F';'T';'P';'phase';'Q';'status'} ;
    if ~isstruct(s) || ~isscalar(s) || ~isequal(fieldnames(s),expected)
        error('nirp:stream:invalid', ...
            'Stream must have fields F, T, P, phase, Q, status in that order.') ;
    end
    if isnumeric(s.phase) && isscalar(s.phase) && s.phase == 1 && ...
            isnumeric(s.F) && isnumeric(s.T) && isnumeric(s.P) && ...
            isscalar(s.T) && isscalar(s.P)
        s.Q = sum(s.F)*8.314*s.T/s.P ;
    end
    nirp.stream.validate(s) ;
end
