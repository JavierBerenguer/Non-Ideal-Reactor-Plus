function tables = showResults(model,varargin)
%SHOWRESULTS Return and optionally display unit and Stream result tables.
%   TABLES = nirp.flowsheet.showResults(MODEL) returns a Units table followed
%   by one table per Stream in nirpResults.Streams. Unit volumes and heat
%   duties use the display units selected on their blocks.
%   ...showResults(MODEL,'NoWindow',true) never creates a UI window.
%   ...showResults(MODEL,'Visible',VALUE) controls the results window.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 3, 2026
% =========================================================================

    if nargin < 1 || isempty(model), model = bdroot ; end
    options = parseOptions(varargin{:}) ;
    if ~evalin('base','exist(''nirpResults'',''var'')')
        error('nirp:flowsheet:noResults', ...
            'No Stream results are available. Run the flowsheet first.') ;
    end
    results = evalin('base','nirpResults') ;
    if ~isstruct(results) || ~isfield(results,'Streams') || ...
            ~isstruct(results.Streams)
        error('nirp:flowsheet:noResults', ...
            'nirpResults contains no Stream results.') ;
    end
    fields = fieldnames(results.Streams) ;
    try
        graph = nirp.flowsheet.topology(model) ;
        ordered = matlab.lang.makeValidName(cellstr(graph.Order)) ;
        fields = [intersect(ordered,fields,'stable'); ...
            setdiff(fields,ordered,'stable')] ;
    catch
    end
    tables = struct() ;
    tables.Units = unitTable(model,results) ;
    for i = 1:numel(fields)
        item = results.Streams.(fields{i}) ;
        if ~isstruct(item) || ~isfield(item,'streamTable'), continue, end
        n = height(item.streamTable) ;
        conversion = NaN ;
        if ~isempty(item.conversion), conversion = item.conversion ; end
        tableValue = item.streamTable ;
        tableValue.FUnit = repmat(string(item.units.F),n,1) ;
        tableValue.CUnit = repmat(string(item.units.C),n,1) ;
        tableValue.T = repmat(item.T,n,1) ;
        tableValue.TUnit = repmat(string(item.units.T),n,1) ;
        tableValue.P = repmat(item.P,n,1) ;
        tableValue.PUnit = repmat(string(item.units.P),n,1) ;
        tableValue.Phase = repmat(string(item.phase),n,1) ;
        tableValue.Status = repmat(item.status,n,1) ;
        tableValue.Conversion = repmat(conversion,n,1) ;
        tables.(fields{i}) = tableValue ;
    end
    if isempty(fieldnames(tables))
        error('nirp:flowsheet:noResults','nirpResults contains no Stream results.') ;
    end
    if options.NoWindow || (~usejava('desktop') && ~options.VisibleSupplied), return, end

    figureHandle = uifigure('Name',sprintf('NIRP results - %s',char(string(model))), ...
        'Position',[100 100 1050 420],'Visible',options.Visible) ;
    tabs = uitabgroup(figureHandle,'Position',[10 10 1030 400]) ;
    names = fieldnames(tables) ;
    for i = 1:numel(names)
        tab = uitab(tabs,'Title',names{i}) ;
        uitable(tab,'Data',tables.(names{i}),'Position',[10 10 1000 350]) ;
    end
end

function value = unitTable(model,results)
    columns = {'Block','Type','Status','V','VUnit','HeatDuty','QUnit', ...
        'Message','Parameter','ParameterUnit','TargetVariable','Target', ...
        'TargetUnit','Measured','Converged','Iterations'} ;
    value = table('Size',[0 numel(columns)], ...
        'VariableTypes',{'string','string','double','double','string', ...
        'double','string','string','double','string','string','double', ...
        'string','double','double','double'},'VariableNames',columns) ;
    [blocks,types] = functionalBlocks(model) ;
    if isempty(blocks), return, end
    diagnostics = struct() ;
    if isfield(results,'Diagnostics') && isstruct(results.Diagnostics)
        diagnostics = results.Diagnostics ;
    end
    diagnosticFields = fieldnames(diagnostics) ;
    prefix = matlab.lang.makeValidName([char(string(model)) '_']) ;
    diagnosticFields = diagnosticFields(startsWith(diagnosticFields,prefix)) ;
    registryEntries = nirp.flowsheet.registry('list',model) ;
    for i = 1:numel(blocks)
        block = blocks{i} ; type = types(i) ;
        row = {string(get_param(block,'Name')),type,NaN,NaN,"",NaN,"", ...
            "",NaN,"","",NaN,"",NaN,NaN,NaN} ;
        name = char(row{1}) ;
        field = matlab.lang.makeValidName([char(string(model)) '_' name]) ;
        item = struct() ; info = struct() ;
        if any(strcmp(diagnosticFields,field))
            item = diagnostics.(field) ;
            if isfield(item,'lastInfo') && isstruct(item.lastInfo)
                info = item.lastInfo ;
            end
        end
        if isfield(info,'status'), row{3} = double(info.status) ;
        elseif isfield(item,'lastOutput'), row{3} = outputStatus(item.lastOutput) ;
        end
        if isfield(info,'message'), row{8} = string(info.message) ; end
        if any(type == ["CSTR","PFR"]) && isfield(info,'V')
            row{5} = volumeUnit(block) ;
            row{4} = UnitConverterHelper.convertFromSI( ...
                'Volume',info.V,char(row{5})) ;
        end
        if isfield(info,'heatDuty')
            row{7} = heatUnit(block,type) ;
            row{6} = UnitConverterHelper.convertFromSI( ...
                'Power',info.heatDuty,char(row{7})) ;
        end
        if type == "Adjust"
            row = adjustValues(row,block,info,registryEntries) ;
        elseif type == "Recycle"
            entry = registryEntry(registryEntries,block,'Recycle') ;
            if ~isempty(entry)
                row{3} = double(entry.status) ; row{15} = double(entry.converged) ;
                row{16} = double(entry.iteration) ;
            end
        end
        value(end+1,:) = row ; %#ok<AGROW>
    end
end

function [blocks,types] = functionalBlocks(model)
    supported = ["CSTR","PFR","Heater","Mixer","Splitter","Adjust","Recycle"] ;
    paths = find_system(model,'LookUnderMasks','all','SearchDepth',1, ...
        'BlockType','MATLABSystem') ;
    blocks = cell(0,1) ; types = strings(0,1) ;
    for i = 1:numel(paths)
        try
            className = string(get_param(paths{i},'System')) ;
        catch
            continue
        end
        if ~startsWith(className,"nirp.blocks."), continue, end
        type = extractAfter(className,"nirp.blocks.") ;
        if any(type == supported)
            blocks{end+1,1} = paths{i} ; %#ok<AGROW>
            types(end+1,1) = type ; %#ok<AGROW>
        end
    end
    try
        graph = nirp.flowsheet.topology(model) ;
        names = topologicalUnitNames(graph) ;
        blockNames = string(cellfun(@(path) get_param(path,'Name'), ...
            blocks,'UniformOutput',false)) ;
        rank = inf(numel(blocks),1) ;
        for i = 1:numel(names), rank(blockNames == names(i)) = i ; end
        [~,order] = sortrows([rank (1:numel(blocks))']) ;
        blocks = blocks(order) ; types = types(order) ;
    catch
    end
end

function names = topologicalUnitNames(graph)
    names = strings(0,1) ; streamFields = fieldnames(graph.Streams) ;
    for i = 1:numel(graph.Order)
        index = find(cellfun(@(field) graph.Streams.(field).Name == graph.Order(i), ...
            streamFields),1) ;
        if isempty(index), continue, end
        item = graph.Streams.(streamFields{index}) ;
        candidates = [string(item.Producer(:));string(item.Consumer(:))] ;
        for candidate = candidates'
            if ~any(names == candidate), names(end+1,1) = candidate ; end %#ok<AGROW>
        end
    end
end

function unit = volumeUnit(block)
    unit = string(get_param(block,'VUnit')) ;
    if ~strcmp(get_param(block,'VSource'),'Input port'), return, end
    try
        ports = get_param(block,'PortHandles') ;
        line = get_param(ports.Inport(2),'Line') ;
        source = get_param(line,'SrcBlockHandle') ;
        if source ~= -1 && strcmp(get_param(source,'System'),'nirp.blocks.Adjust')
            unit = string(get_param(source,'ParameterUnit')) ;
        end
    catch
    end
end

function status = outputStatus(output)
    status = NaN ;
    if iscell(output) && ~isempty(output), output = output{1} ; end
    if isstruct(output) && isfield(output,'status')
        status = double(output.status) ;
    end
end

function unit = heatUnit(block,type)
    if any(type == ["CSTR","PFR"])
        unit = string(get_param(block,'SpecifiedQUnit')) ;
    elseif type == "Heater"
        unit = string(get_param(block,'DutyUnit')) ;
    else
        unit = "kW" ;
    end
end

function row = adjustValues(row,block,info,entries)
    entry = registryEntry(entries,block,'Adjust') ;
    if ~isempty(entry)
        row{3} = double(entry.status) ; row{15} = double(entry.converged) ;
        row{16} = double(entry.iteration) ;
    end
    if isempty(fieldnames(info)), return, end
    row{10} = string(info.parameterUnit) ;
    category = nirp.blocks.internal.unitCategory( ...
        char(row{10}),{'Volume','Temperature'}) ;
    row{9} = UnitConverterHelper.convertFromSI( ...
        category,info.value,char(row{10})) ;
    row{11} = string(info.targetVariable) ; row{13} = string(info.targetUnit) ;
    [row{12},row{14}] = displayTarget(info) ;
    row{15} = double(info.converged) ; row{16} = double(info.iteration) ;
end

function [target,measured] = displayTarget(info)
    target = info.target ; measured = info.measured ;
    if strcmp(info.targetUnit,'as entered'), return, end
    switch info.targetVariable
        case 'Component molar flow', category = 'MolarFlow' ;
        case 'Temperature', category = 'Temperature' ;
        case 'Component concentration', category = 'Concentration' ;
        otherwise, return
    end
    target = UnitConverterHelper.convertFromSI(category,target,info.targetUnit) ;
    measured = UnitConverterHelper.convertFromSI(category,measured,info.targetUnit) ;
end

function entry = registryEntry(entries,block,kind)
    entry = [] ;
    if isempty(entries), return, end
    key = string(block) ; kinds = string({entries.kind}) ; keys = string({entries.key}) ;
    index = find(kinds == kind & keys == key,1) ;
    if ~isempty(index), entry = entries(index) ; end
end

function options = parseOptions(varargin)
    options = struct('NoWindow',false,'Visible','on','VisibleSupplied',false) ;
    if mod(numel(varargin),2) ~= 0
        error('nirp:flowsheet:invalidOption','Options must be name-value pairs.') ;
    end
    for i = 1:2:numel(varargin)
        name = char(string(varargin{i})) ; supplied = varargin{i+1} ;
        switch lower(name)
            case 'nowindow'
                if ~isscalar(supplied) || ...
                        (~islogical(supplied) && ~isnumeric(supplied))
                    error('nirp:flowsheet:invalidOption', ...
                        'NoWindow must be scalar logical.') ;
                end
                options.NoWindow = logical(supplied) ;
            case 'visible'
                visible = lower(string(supplied)) ;
                if ~isscalar(visible) || ~any(visible == ["on","off"])
                    error('nirp:flowsheet:invalidOption', ...
                        'Visible must be ''on'' or ''off''.') ;
                end
                options.Visible = char(visible) ;
                options.VisibleSupplied = true ;
            otherwise
                error('nirp:flowsheet:invalidOption', ...
                    'Unknown option "%s".',name) ;
        end
    end
end
