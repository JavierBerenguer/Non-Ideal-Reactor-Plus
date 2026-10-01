function pkg = readDictionary(sldd)
%READDICTIONARY Read and validate nirpPackage from a data dictionary.
%   PKG = nirp.pkg.readDictionary(SLDD) reads the stored user-unit data.
%   Example: pkg = nirp.pkg.readDictionary("plant.sldd").
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 1, 2026
% =========================================================================

    path = char(string(sldd)) ;
    if ~isfile(path)
        error('nirp:pkg:invalid','Dictionary does not exist: %s.',path) ;
    end
    dictionary = Simulink.data.dictionary.open(path) ;
    cleanup = onCleanup(@() close(dictionary)) ;
    section = getSection(dictionary,'Design Data') ;
    if ~exist(section,'nirpPackage')
        error('nirp:pkg:invalid', ...
            'Dictionary %s has no nirpPackage entry.',path) ;
    end
    entry = getEntry(section,'nirpPackage') ;
    pkg = getValue(entry) ;
    nirp.pkg.validate(pkg) ;
end
