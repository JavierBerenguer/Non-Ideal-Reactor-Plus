function value = bus(grid)
%BUS Create the fixed-size NirpTracer Simulink bus for a common grid.
%   Elements are Q, C, E, sourceId, valid, and status. C and E dimensions
%   are [grid.length 1]. Status: 0 invalid, 1 valid, 2 mixed sources.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================

    grid = nirp.tracer.validateGrid(grid) ;
    names = {'Q','C','E','sourceId','valid','status'} ;
    types = {'double','double','double','uint32','boolean','uint8'} ;
    elements = repmat(Simulink.BusElement,1,numel(names)) ;
    for k = 1:numel(names)
        elements(k).Name = names{k} ;
        elements(k).DataType = types{k} ;
        elements(k).Dimensions = 1 ;
    end
    elements(2).Dimensions = [grid.length 1] ;
    elements(3).Dimensions = [grid.length 1] ;
    value = Simulink.Bus ;
    value.Elements = elements ;
end
