function blkStruct = slblocks
%SLBLOCKS Register the NIRP library in the Simulink Library Browser.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    blkStruct.Name = '' ;
    blkStruct.OpenFcn = '' ;
    Browser.Library = 'NirpLibrary' ;
    Browser.Name = 'Non-Ideal Reactor Plus' ;
    Browser.IsFlat = 0 ;
    blkStruct.Browser = Browser ;
end
