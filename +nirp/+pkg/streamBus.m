function bus = streamBus(pkg)
%STREAMBUS Create the NirpStream Simulink bus for this component count.
%   BUS = nirp.pkg.streamBus(PKG) returns elements F, T, P, phase, Q,
%   status in that order; F has dimensions [nComp 1].
%   Example: bus = nirp.pkg.streamBus(pkg).
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 1, 2026
% =========================================================================

    nirp.pkg.validate(pkg) ;
    elementNames = {'F','T','P','phase','Q','status'} ;
    elements = repmat(Simulink.BusElement,1,numel(elementNames)) ;
    for i = 1:numel(elementNames)
        elements(i).Name = elementNames{i} ;
        elements(i).DataType = 'double' ;
        elements(i).Dimensions = 1 ;
    end
    elements(1).Dimensions = [numel(pkg.components) 1] ;
    bus = Simulink.Bus ;
    bus.Elements = elements ;
end
