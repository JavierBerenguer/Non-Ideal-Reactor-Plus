function finish(model)
%FINISH Warn and mark results when an iterative flowsheet did not converge.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    model = char(string(model)) ;
    entries = nirp.flowsheet.registry('list',model) ;
    if isempty(entries) || all([entries.converged]), return, end
    missing = {entries(~[entries.converged]).key} ;
    if evalin('base','exist(''nirpResults'',''var'')')
        results = evalin('base','nirpResults') ;
    else
        results = struct() ;
    end
    if ~isstruct(results), results = struct() ; end
    fields = fieldnames(results) ;
    for i = 1:numel(fields)
        item = results.(fields{i}) ;
        if isstruct(item) && isfield(item,'streamSI')
            item.status = -1 ;
            item.streamSI.status = -1 ;
            results.(fields{i}) = item ;
        end
    end
    results.Flowsheet = struct('status',-1,'notConverged',{missing}) ;
    assignin('base','nirpResults',results) ;
    warning('nirp:flowsheet:notConverged', ...
        'Maximum iterations reached. Blocks not converged: %s.', ...
        strjoin(missing,', ')) ;
end
