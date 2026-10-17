function [status,message,label] = blockStatus(blockPath)
%BLOCKSTATUS Return the latest-run state and first message for a NIRP block.
%   STATUS is "solved", "warning", "error", or "none". MESSAGE is the
%   first warning or error text, and LABEL is suitable for a block dialog.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 9, 2026. Last update: October 9, 2026
% =========================================================================

    block = getfullname(blockPath) ;
    model = bdroot(block) ;
    className = string(get_param(block,'System')) ;
    status = "none" ; message = "" ;
    results = struct() ;
    if evalin('base','exist(''nirpResults'',''var'')')
        candidate = evalin('base','nirpResults') ;
        if isstruct(candidate), results = candidate ; end
    end

    if className == "nirp.blocks.Stream"
        [status,message] = streamStatus(results,block) ;
    elseif any(className == ["nirp.blocks.Adjust","nirp.blocks.Recycle"])
        [status,message] = iterativeStatus(results,block,className) ;
    elseif startsWith(className,"nirp.blocks.")
        [status,message] = diagnosticStatus(results,block) ;
    end
    label = statusLabel(status,message) ;
end

function [status,message] = streamStatus(results,block)
    status = "none" ; message = "" ;
    role = nirp.flowsheet.streamRole(block) ;
    if role == "Unconnected"
        status = "warning" ;
        message = "Stream is unconnected." ;
        return
    elseif role == "Feed" && ~feedIsDefined(block)
        status = "warning" ;
        message = "Feed data are not defined in the flowsheet package." ;
        return
    end
    field = matlab.lang.makeValidName(get_param(block,'Name')) ;
    if ~isfield(results,'Streams') || ~isstruct(results.Streams) || ...
            ~isfield(results.Streams,field)
        return
    end
    item = results.Streams.(field) ;
    if ~isstruct(item) || ~isfield(item,'status'), return, end
    if item.status == -1 && flowsheetDidNotConverge(results)
        status = "warning" ;
        message = "Flowsheet did not converge; values are from the last iteration." ;
        return
    end
    [status,message] = numericStatus(item.status,"Stream calculation failed.") ;
end

function value = feedIsDefined(block)
    value = false ;
    try
        dictionary = nirp.flowsheet.modelDictionary(bdroot(block)) ;
        pkg = nirp.pkg.readDictionary(dictionary) ;
        value = any(string({pkg.feeds.name}) == string(get_param(block,'Name'))) ;
    catch
    end
end

function value = flowsheetDidNotConverge(results)
    value = isfield(results,'Flowsheet') && isstruct(results.Flowsheet) && ...
        isfield(results.Flowsheet,'notConverged') && ...
        ~isempty(results.Flowsheet.notConverged) ;
end

function [status,message] = iterativeStatus(results,block,className)
    [status,message] = diagnosticStatus(results,block) ;
    entries = nirp.flowsheet.registry('list',bdroot(block)) ;
    if isempty(entries), return, end
    kind = extractAfter(className,"nirp.blocks.") ;
    index = find(string({entries.key}) == string(block) & ...
        string({entries.kind}) == kind,1) ;
    if isempty(index), return, end
    if ~logical(entries(index).converged)
        status = "warning" ;
        message = kind+" did not converge." ;
    elseif status == "none"
        status = "solved" ;
    end
end

function [status,message] = diagnosticStatus(results,block)
    status = "none" ; message = "" ;
    if ~isfield(results,'Diagnostics') || ~isstruct(results.Diagnostics), return, end
    field = matlab.lang.makeValidName( ...
        [char(string(bdroot(block))) '_' get_param(block,'Name')]) ;
    if ~isfield(results.Diagnostics,field), return, end
    item = results.Diagnostics.(field) ; info = struct() ;
    if isstruct(item) && isfield(item,'lastInfo') && isstruct(item.lastInfo)
        info = item.lastInfo ;
    end
    value = NaN ;
    if isfield(info,'status')
        value = info.status ;
    elseif isstruct(item) && isfield(item,'lastOutput')
        output = item.lastOutput ;
        if iscell(output) && ~isempty(output), output = output{1} ; end
        if isstruct(output) && isfield(output,'status'), value = output.status ; end
    end
    if isfield(info,'message') && strlength(string(info.message)) > 0
        message = firstText(info.message) ;
    end
    if isnumeric(value) && isscalar(value) && value == -1
        status = "error" ;
        if strlength(message) == 0, message = "Calculation failed." ; end
        return
    end
    warningText = "" ;
    if isfield(info,'warnings'), warningText = firstText(info.warnings) ; end
    if strlength(warningText) > 0
        status = "warning" ; message = warningText ;
    elseif isnumeric(value) && isscalar(value) && value == 1
        status = "solved" ;
    end
end

function [status,message] = numericStatus(value,errorMessage)
    status = "none" ; message = "" ;
    if ~isnumeric(value) || ~isscalar(value), return, end
    if value == 1
        status = "solved" ;
    elseif value == -1
        status = "error" ; message = errorMessage ;
    end
end

function value = firstText(values)
    value = "" ;
    if ischar(values) || isstring(values)
        values = string(values(:)) ;
    elseif iscell(values)
        values = string(values(:)) ;
    else
        return
    end
    values = strip(values) ; values = values(strlength(values) > 0) ;
    if ~isempty(values), value = values(1) ; end
end

function label = statusLabel(status,message)
    switch status
        case "solved", label = "Solved" ;
        case "warning", label = "Warning: "+message ;
        case "error", label = "Error: "+message ;
        otherwise, label = "Not calculated yet" ;
    end
end
