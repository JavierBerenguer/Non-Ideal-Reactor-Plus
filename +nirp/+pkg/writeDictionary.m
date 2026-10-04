function writeDictionary(pkg,sldd)
%WRITEDICTIONARY Store NirpStream and nirpPackage in a data dictionary.
%   nirp.pkg.writeDictionary(PKG,SLDD) creates or updates SLDD after
%   validating PKG. Example: nirp.pkg.writeDictionary(pkg,"plant.sldd").
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 1, 2026
% =========================================================================

    nirp.pkg.validate(pkg) ;
    path = char(string(sldd)) ;
    if isfile(path)
        dictionary = Simulink.data.dictionary.open(path) ;
    else
        dictionary = Simulink.data.dictionary.create(path) ;
    end
    cleanup = onCleanup(@() close(dictionary)) ;
    section = getSection(dictionary,'Design Data') ;
    setEntry(section,'NirpStream',nirp.pkg.streamBus(pkg)) ;
    setEntry(section,'nirpPackage',pkg) ;
    saveChanges(dictionary) ;
end

function setEntry(section,name,value)
    if exist(section,name)
        entry = getEntry(section,name) ;
        setValue(entry,value) ;
    else
        addEntry(section,name,value) ;
    end
end
