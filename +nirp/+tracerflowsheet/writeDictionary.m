function writeDictionary(path,grid)
%WRITEDICTIONARY Store the independent NirpTracer bus in a dictionary.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================
    if isfile(path), dictionary=Simulink.data.dictionary.open(path) ;
    else, dictionary=Simulink.data.dictionary.create(path) ; end
    cleanup=onCleanup(@()close(dictionary)) ;
    section=getSection(dictionary,'Design Data') ;
    if exist(section,'NirpTracer'), setValue(getEntry(section,'NirpTracer'),nirp.tracer.bus(grid)) ;
    else, addEntry(section,'NirpTracer',nirp.tracer.bus(grid)) ; end
    saveChanges(dictionary) ;
end
