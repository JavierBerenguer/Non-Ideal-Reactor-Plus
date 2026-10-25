function value = bus(grid,nComp)
%BUS Create the fixed-size NirpTracer Simulink bus for a common grid.
%   BUS(GRID,NCOMP) adds stationary reactive compositions C0, Cseg, and
%   Cmm, each [nComp 1] in mol/m^3. REACTIVEMODE is 0 None, 1
%   Segregation, 2 Max mixedness, or 3 Both. RTDTRUNCATED is accumulated
%   along the path. The default NCOMP=1 preserves inert tracer models.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 25, 2026
% =========================================================================

    grid = nirp.tracer.validateGrid(grid) ;
    if nargin < 2, nComp = 1 ; end
    validateattributes(nComp,{'numeric'},{'real','scalar','integer','positive','finite'}) ;
    names = {'Q','C','E','sourceId','valid','status', ...
        'C0','Cseg','Cmm','reactiveMode','rtdTruncated'} ;
    types = {'double','double','double','uint32','boolean','uint8', ...
        'double','double','double','uint8','boolean'} ;
    elements = repmat(Simulink.BusElement,1,numel(names)) ;
    for k = 1:numel(names)
        elements(k).Name = names{k} ;
        elements(k).DataType = types{k} ;
        elements(k).Dimensions = 1 ;
    end
    elements(2).Dimensions = [grid.length 1] ;
    elements(3).Dimensions = [grid.length 1] ;
    elements(7).Dimensions = [nComp 1] ;
    elements(8).Dimensions = [nComp 1] ;
    elements(9).Dimensions = [nComp 1] ;
    value = Simulink.Bus ;
    value.Elements = elements ;
end
