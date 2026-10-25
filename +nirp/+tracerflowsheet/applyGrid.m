function applyGrid(coordinator,dt,tFinal,nComp)
%APPLYGRID Set the one common grid on every tracer block in the model.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 25, 2026
% =========================================================================
    if nargin < 4, nComp = 1 ; end
    grid=nirp.tracer.grid(dt,tFinal) ; root=bdroot(coordinator) ;
    blocks=find_system(root,'SearchDepth',1,'BlockType','MATLABSystem') ;
    for k=1:numel(blocks)
        if startsWith(string(get_param(blocks{k},'System')),"nirp.tracerblocks.")
            set_param(blocks{k},'Dt',num2str(grid.dt,17),'TFinal',num2str(grid.tFinal,17)) ;
        end
    end
    dictionary=get_param(root,'DataDictionary') ;
    if isempty(dictionary), error('nirp:tracerflowsheet:NoDictionary','Tracer flowsheet requires its data dictionary.') ; end
    if ~isfile(dictionary), dictionary=fullfile(fileparts(get_param(root,'FileName')),dictionary) ; end
    nirp.tracerflowsheet.writeDictionary(dictionary,grid,nComp) ;
end
