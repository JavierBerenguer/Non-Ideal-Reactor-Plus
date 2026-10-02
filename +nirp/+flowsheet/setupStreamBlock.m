function setupStreamBlock(block)
%SETUPSTREAMBLOCK Install Stream UI and identity callbacks on a block.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    block = getfullname(block) ;
    data = get_param(block,'UserData') ;
    if ~isstruct(data), data = struct() ; end
    data.NirpStreamName = get_param(block,'Name') ;
    set_param(block,'UserData',data,'UserDataPersistent','on', ...
        'OpenFcn','nirp.flowsheet.StreamDialog.open(gcb);', ...
        'NameChangeFcn','nirp.flowsheet.streamRenamed(gcb);') ;
end
