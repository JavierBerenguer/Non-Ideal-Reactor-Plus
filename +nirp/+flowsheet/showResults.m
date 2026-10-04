function tables = showResults(model,varargin)
%SHOWRESULTS Return and optionally display unit and Stream result tables.
%   TABLES = nirp.flowsheet.showResults(MODEL) returns Units and Adjust
%   tables followed by one table per Stream in nirpResults.Streams. Unit
%   volumes and heat duties use the display units selected on their blocks.
%   ...showResults(MODEL,'NoWindow',true) never creates a UI window.
%   ...showResults(MODEL,'Visible',VALUE) controls the results window.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 4, 2026
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
    modelLoaded = bdIsLoaded(model) ;
    if modelLoaded
        try
            graph = nirp.flowsheet.topology(model) ;
            ordered = matlab.lang.makeValidName(cellstr(graph.Order)) ;
            fields = [intersect(ordered,fields,'stable'); ...
                setdiff(fields,ordered,'stable')] ;
        catch
        end
    end
    tables = struct() ;
    tables.Units = emptyUnitTable() ;
    tables.Adjust = emptyAdjustTable() ;
    if modelLoaded
        try
            [tables.Units,tables.Adjust] = unitTables(model,results) ;
        catch
            % Stream results remain useful when block data cannot be read.
        end
    end
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
    figureGrid = uigridlayout(figureHandle,[1 1], ...
        'Padding',[10 10 10 10]) ;
    tabs = uitabgroup(figureGrid) ;
    unitTab = uitab(tabs,'Title','Units') ;
    unitGrid = uigridlayout(unitTab,[4 1], ...
        'RowHeight',{22,'1x',22,'1x'},'Padding',[10 10 10 10]) ;
    uilabel(unitGrid,'Text','Units','FontWeight','bold') ;
    createDisplayTable(unitGrid,tables.Units,2, ...
        {110,70,55,85,65,95,65,250}) ;
    uilabel(unitGrid,'Text','Adjust','FontWeight','bold') ;
    createDisplayTable(unitGrid,tables.Adjust,4, ...
        {125,65,90,110,120,75,100,85,90,85}) ;
    names = fieldnames(tables) ; names = names(3:end) ;
    for i = 1:numel(names)
        tab = uitab(tabs,'Title',names{i}) ;
        grid = uigridlayout(tab,[1 1],'Padding',[10 10 10 10]) ;
        createDisplayTable(grid,tables.(names{i}),1,'auto') ;
    end
end

function [units,adjusts] = unitTables(model,results)
    units = emptyUnitTable() ; adjusts = emptyAdjustTable() ;
    if ~bdIsLoaded(model), return, end
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
        row = {string(get_param(block,'Name')),type,NaN,NaN,"",NaN,"",""} ;
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
            adjusts(end+1,:) = adjustValues(block,info,registryEntries) ; %#ok<AGROW>
            continue
        elseif type == "Recycle"
            entry = registryEntry(registryEntries,block,'Recycle') ;
            if ~isempty(entry)
                row{3} = double(entry.status) ;
            end
        end
        units(end+1,:) = row ; %#ok<AGROW>
    end
end

function value = emptyUnitTable()
    columns = {'Block','Type','Status','V','VUnit','HeatDuty','QUnit','Message'} ;
    value = table('Size',[0 numel(columns)], ...
        'VariableTypes',{'string','string','double','double','string', ...
        'double','string','string'},'VariableNames',columns) ;
end

function value = emptyAdjustTable()
    columns = {'Block','Status','Parameter','ParameterUnit','TargetVariable', ...
        'Target','TargetUnit','Measured','Converged','Iterations'} ;
    value = table('Size',[0 numel(columns)], ...
        'VariableTypes',{'string','double','double','string','string', ...
        'double','string','double','double','double'},'VariableNames',columns) ;
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

function row = adjustValues(block,info,entries)
    row = {string(get_param(block,'Name')),NaN,NaN,"","",NaN,"",NaN,NaN,NaN} ;
    entry = registryEntry(entries,block,'Adjust') ;
    if ~isempty(entry)
        row{2} = double(entry.status) ; row{9} = double(entry.converged) ;
        row{10} = double(entry.iteration) ;
    end
    if isempty(fieldnames(info)), return, end
    row{4} = string(info.parameterUnit) ;
    category = nirp.blocks.internal.unitCategory( ...
        char(row{4}),{'Volume','Temperature'}) ;
    row{3} = UnitConverterHelper.convertFromSI( ...
        category,info.value,char(row{4})) ;
    row{5} = string(info.targetVariable) ; row{7} = string(info.targetUnit) ;
    [row{6},row{8}] = displayTarget(info) ;
    row{9} = double(info.converged) ; row{10} = double(info.iteration) ;
end

function createDisplayTable(parent,value,row,columnWidths)
    data = table2cell(value) ;
    for i = 1:numel(data)
        if isnumeric(data{i}) && isscalar(data{i}) && isnan(data{i})
            data{i} = '' ;
        elseif isstring(data{i})
            data{i} = char(data{i}) ;
        end
    end
    control = uitable(parent,'Data',data, ...
        'ColumnName',value.Properties.VariableNames,'RowName',{}, ...
        'ColumnWidth',columnWidths) ;
    control.Layout.Row = row ;
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
