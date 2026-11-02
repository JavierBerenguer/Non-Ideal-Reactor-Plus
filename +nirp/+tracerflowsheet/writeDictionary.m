function writeDictionary(path,grid,nComp)
%WRITEDICTIONARY Store the independent NirpTracer bus in a dictionary.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 25, 2026
% =========================================================================
    if nargin < 3, nComp = 1 ; end
    if isfile(path), dictionary=Simulink.data.dictionary.open(path) ;
    else, dictionary=Simulink.data.dictionary.create(path) ; end
    cleanup=onCleanup(@()close(dictionary)) ;
    section=getSection(dictionary,'Design Data') ;
    if exist(section,'NirpTracer'), setValue(getEntry(section,'NirpTracer'),nirp.tracer.bus(grid,nComp)) ;
    else, addEntry(section,'NirpTracer',nirp.tracer.bus(grid,nComp)) ; end
    saveChanges(dictionary) ;
end
