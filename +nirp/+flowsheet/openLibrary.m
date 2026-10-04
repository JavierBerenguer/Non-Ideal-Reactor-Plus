function libraryFile = openLibrary()
%OPENLIBRARY Set up and open the NIRP Simulink block library.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    libraryFile = nirp.setup() ;
    open_system(libraryFile) ;
end
