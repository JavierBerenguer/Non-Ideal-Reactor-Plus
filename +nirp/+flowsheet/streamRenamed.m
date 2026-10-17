function streamRenamed(block)
%STREAMRENAMED Keep package and result identities aligned with a Stream name.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 9, 2026
% =========================================================================

    block = getfullname(block) ;
    data = get_param(block,'UserData') ;
    current = get_param(block,'Name') ;
    if ~isstruct(data) || ~isfield(data,'NirpStreamName')
        nirp.flowsheet.setupStreamBlock(block) ;
        return
    end
    previous = char(string(data.NirpStreamName)) ;
    if strcmp(previous,current), return, end
    role = nirp.flowsheet.streamRole(block) ;
    if role == "Feed"
        path = nirp.flowsheet.modelDictionary(bdroot(block)) ;
        pkg = nirp.pkg.readDictionary(path) ;
        names = string({pkg.feeds.name}) ;
        oldIndex = find(names == string(previous),1) ;
        newIndex = find(names == string(current),1) ;
        if ~isempty(oldIndex)
            if ~isempty(newIndex) && newIndex ~= oldIndex
                error('nirp:flowsheet:duplicateStreamName', ...
                    'Feed "%s" already exists in the package.',current) ;
            end
            pkg.feeds(oldIndex).name = current ;
            nirp.pkg.writeDictionary(pkg,path) ;
        end
    end
    if evalin('base','exist(''nirpResults'',''var'')')
        results = evalin('base','nirpResults') ;
        oldField = matlab.lang.makeValidName(previous) ;
        newField = matlab.lang.makeValidName(current) ;
        if isstruct(results) && isfield(results,'Streams') && ...
                isstruct(results.Streams) && isfield(results.Streams,oldField)
            item = results.Streams.(oldField) ;
            results.Streams = rmfield(results.Streams,oldField) ;
            item.name = current ;
            results.Streams.(newField) = item ;
            assignin('base','nirpResults',results) ;
        end
    end
    data.NirpStreamName = current ;
    set_param(block,'UserData',data,'UserDataPersistent','on') ;
end
