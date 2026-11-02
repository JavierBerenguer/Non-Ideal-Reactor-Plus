function blkStruct = slblocks
%SLBLOCKS Register the NIRP library in the Simulink Library Browser.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    blkStruct.Name = '' ;
    blkStruct.OpenFcn = '' ;
    Browser(1).Library = 'NirpLibrary' ;
    Browser(1).Name = 'Non-Ideal Reactor Plus' ;
    Browser(1).IsFlat = 0 ;
    Browser(2).Library = 'NirpTracerLibrary' ;
    Browser(2).Name = 'Non-Ideal Reactor Plus - Tracer Flowsheet' ;
    Browser(2).IsFlat = 0 ;
    blkStruct.Browser = Browser ;
end
