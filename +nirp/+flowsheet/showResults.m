function tables = showResults(model,varargin)
%SHOWRESULTS Return and optionally display unit and Stream result tables.
%   TABLES = nirp.flowsheet.showResults(MODEL) returns Units and Adjust
%   tables followed by one table per Stream in nirpResults.Streams. Unit
%   volumes, Jacket heat-transfer parameters, heat duties, and optional
%   utility mass flows use display units (mass flow is reported in kg/s).
%   ...showResults(MODEL,'NoWindow',true) never creates a UI window.
%   ...showResults(MODEL,'Visible',VALUE) controls the results window.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 8, 2026
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
        [tables.Units,tables.Adjust] = unitTables(model,results) ;
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
    % Keep each result and unit in its typed column. The table deliberately
    % scrolls horizontally so neither engineering values nor headings are
    % truncated at the default window size.
    createDisplayTable(unitGrid,tables.Units,2, ...
        {130,75,65,110,65,110,65,110,95,110,75,110,75,140,70, ...
        130,80,320},true) ;
    uilabel(unitGrid,'Text','Adjust','FontWeight','bold') ;
    createDisplayTable(unitGrid,tables.Adjust,4, ...
        {115,55,80,95,105,70,90,75,80,75,160},true) ;
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
        row = emptyUnitRow(block,type) ;
        name = char(row{1}) ;
        field = matlab.lang.makeValidName([char(string(model)) '_' name]) ;
        item = struct() ; info = struct() ;
        if any(strcmp(diagnosticFields,field))
            item = diagnostics.(field) ;
            if isfield(item,'lastInfo') && isstruct(item.lastInfo)
                info = item.lastInfo ;
            end
        end
        try
            if isfield(info,'status'), row{3} = double(info.status) ;
            elseif isfield(item,'lastOutput'), row{3} = outputStatus(item.lastOutput) ;
            end
            if isfield(info,'message'), row{18} = string(info.message) ; end
            if any(type == ["CSTR","PFR"])
                row = reactorValues(block,info,row) ;
            elseif type == "Jacket"
                row = jacketValues(model,block,info,row,diagnostics) ;
            end
            if isfield(info,'heatDuty')
                row{15} = heatUnit(block,type) ;
                row{14} = UnitConverterHelper.convertFromSI( ...
                    'Power',info.heatDuty,char(row{15})) ;
            end
            if type == "Adjust"
                adjusts(end+1,:) = adjustValues(block,info,registryEntries) ; %#ok<AGROW>
                continue
            elseif type == "Recycle"
                entry = registryEntry(registryEntries,block,'Recycle') ;
                if ~isempty(entry), row{3} = double(entry.status) ; end
            end
        catch exception
            warning('nirp:flowsheet:unitResultRow', ...
                'Could not build results row for "%s": %s',name,exception.message) ;
            if type == "Adjust"
                failed = emptyAdjustRow(block) ; failed{11} = string(exception.message) ;
                adjusts(end+1,:) = failed ; %#ok<AGROW>
                continue
            end
            row{18} = string(exception.message) ;
        end
        units(end+1,:) = row ; %#ok<AGROW>
    end
    units = clearUnitsWithoutValues(units) ;
end

function value = emptyUnitTable()
    columns = {'Block','Type','Status','V','VUnit','A','AUnit','U','UUnit', ...
        'UtilityTin','UtilityTinUnit','UtilityTout','UtilityToutUnit', ...
        'HeatDuty','QUnit','ServiceFlow','ServiceFlowUnit','Message'} ;
    value = table('Size',[0 numel(columns)], ...
        'VariableTypes',{'string','string','double','double','string', ...
        'double','string','double','string','double','string','double','string', ...
        'double','string','double','string','string'}, ...
        'VariableNames',columns) ;
end

function value = emptyAdjustTable()
    columns = {'Block','Status','Parameter','ParameterUnit','TargetVariable', ...
        'Target','TargetUnit','Measured','Converged','Iterations','Message'} ;
    value = table('Size',[0 numel(columns)], ...
        'VariableTypes',{'string','double','double','string','string', ...
        'double','string','double','double','double','string'}, ...
        'VariableNames',columns) ;
end

function row = emptyUnitRow(block,type)
    row = {string(get_param(block,'Name')),type,NaN,NaN,"",NaN,"", ...
        NaN,"",NaN,"",NaN,"",NaN,"",NaN,"",""} ;
end

function row = emptyAdjustRow(block)
    row = {string(get_param(block,'Name')),NaN,NaN,"","",NaN,"", ...
        NaN,NaN,NaN,""} ;
end

function [blocks,types] = functionalBlocks(model)
    supported = ["CSTR","PFR","Heater","Jacket","Mixer","Splitter","Adjust","Recycle"] ;
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

function row = reactorValues(block,info,row)
    if isfield(info,'V')
        row{5} = parameterUnit(block,'V') ;
        row{4} = UnitConverterHelper.convertFromSI( ...
            'Volume',info.V,char(row{5})) ;
    end
end

function units = clearUnitsWithoutValues(units)
    pairs = {'V','VUnit';'A','AUnit';'U','UUnit'; ...
        'UtilityTin','UtilityTinUnit';'UtilityTout','UtilityToutUnit'; ...
        'HeatDuty','QUnit';'ServiceFlow','ServiceFlowUnit'} ;
    for i = 1:size(pairs,1)
        missing = ismissing(units.(pairs{i,1})) ;
        units.(pairs{i,2})(missing) = "" ;
    end
end

function row = jacketValues(model,block,info,row,diagnostics)
    if isempty(fieldnames(info)), return, end
    row{7}=string(get_param(block,'AUnit'));row{6}=UnitConverterHelper.convertFromSI('Area',info.A,char(row{7}));
    row{9}=string(get_param(block,'UUnit'));row{8}=UnitConverterHelper.convertFromSI('HeatTransferCoefficient',info.U,char(row{9}));
    row{11}=string(get_param(block,'UtilityTinUnit'));row{10}=UnitConverterHelper.convertFromSI('Temperature',info.utilityTin,char(row{11}));
    row{13}=string(get_param(block,'UtilityToutUnit'));
    if ~isnan(info.utilityTout),row{12}=UnitConverterHelper.convertFromSI('Temperature',info.utilityTout,char(row{13}));end
    reactorInfo=connectedReactorInfo(model,block,diagnostics);
    if isfield(reactorInfo,'heatDuty')
        row{14}=reactorInfo.heatDuty;row{15}="W";
        latent=str2double(get_param(block,'LatentHeat'));cp=str2double(get_param(block,'UtilityCp'));
        if ison(get_param(block,'Condenses'))&&isfinite(latent)&&latent>0
            row{16}=abs(reactorInfo.heatDuty)/latent;row{17}="kg/s";
        elseif isfinite(cp)&&cp>0&&~isnan(info.utilityTout)&&info.utilityTout~=info.utilityTin
            row{16}=abs(reactorInfo.heatDuty)/(cp*abs(info.utilityTout-info.utilityTin));row{17}="kg/s";
        end
    end
end

function info = connectedReactorInfo(model,block,diagnostics)
    info=struct();ports=get_param(block,'PortHandles');
    if isempty(ports.Outport),return,end;line=get_param(ports.Outport(1),'Line');if line==-1,return,end
    destinations=get_param(line,'DstBlockHandle');
    for destination=reshape(destinations,1,[])
        try,className=string(get_param(destination,'System'));catch,continue,end
        if ~any(className==["nirp.blocks.CSTR","nirp.blocks.PFR"]),continue,end
        field=matlab.lang.makeValidName([char(string(model)) '_' get_param(destination,'Name')]);
        if isfield(diagnostics,field)&&isfield(diagnostics.(field),'lastInfo'),info=diagnostics.(field).lastInfo;return,end
    end
end

function value = parameterSI(block,name,category)
    source = get_param(block,[name 'Source']) ;
    if strcmp(source,'Input port')
        adjust = parameterSource(block,name) ;
        entries = evalin('base','nirpResults.Diagnostics') ;
        model = string(bdroot(block)) ; adjustName = string(get_param(adjust,'Name')) ;
        field = matlab.lang.makeValidName(model+"_"+adjustName) ;
        value = entries.(field).lastInfo.value ;
    else
        value = UnitConverterHelper.convertToSI(category, ...
            str2double(get_param(block,name)),get_param(block,[name 'Unit'])) ;
    end
end

function unit = parameterUnit(block,name)
    unit = string(get_param(block,[name 'Unit'])) ;
    if strcmp(get_param(block,[name 'Source']),'Input port')
        source = parameterSource(block,name) ;
        if strcmp(get_param(source,'System'),'nirp.blocks.Adjust')
            unit = string(get_param(source,'ParameterUnit')) ;
        end
    end
end

function source = parameterSource(block,name)
    names = {'V','A','UtilityTin'} ; index = 1 ;
    for i = 1:numel(names)
        if strcmp(get_param(block,[names{i} 'Source']),'Input port')
            index = index+1 ;
            if strcmp(names{i},name), break, end
        end
    end
    ports = get_param(block,'PortHandles') ;
    line = get_param(ports.Inport(index),'Line') ;
    source = get_param(line,'SrcBlockHandle') ;
    if source == -1
        error('nirp:flowsheet:unconnectedParameterPort', ...
            '%s input port is not connected.',name) ;
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
        % T-131: reactors no longer expose a specified-Q unit; the heat
        % port is in W.
        unit = "W" ;
    elseif type == "Heater"
        unit = string(get_param(block,'DutyUnit')) ;
    elseif type == "Jacket"
        unit = "W" ;
    else
        unit = "kW" ;
    end
end

function flag=ison(value),flag=strcmp(value,'on')||strcmp(value,'1');end

function row = adjustValues(block,info,entries)
    row = emptyAdjustRow(block) ;
    entry = registryEntry(entries,block,'Adjust') ;
    if ~isempty(entry)
        row{2} = double(entry.status) ; row{9} = double(entry.converged) ;
        row{10} = double(entry.iteration) ;
    end
    if isempty(fieldnames(info)), return, end
    row{4} = string(info.parameterUnit) ;
    category = nirp.blocks.internal.unitCategory( ...
        char(row{4}),{'Volume','Temperature','VolumetricFlow','Area'}) ;
    row{3} = UnitConverterHelper.convertFromSI( ...
        category,info.value,char(row{4})) ;
    row{5} = string(info.targetVariable) ; row{7} = string(info.targetUnit) ;
    [row{6},row{8}] = displayTarget(info) ;
    row{9} = double(info.converged) ; row{10} = double(info.iteration) ;
end

function createDisplayTable(parent,value,row,columnWidths,formatUnitResults)
    if nargin < 5, formatUnitResults = false ; end
    data = table2cell(value) ;
    for i = 1:numel(data)
        if isnumeric(data{i}) && isscalar(data{i}) && isnan(data{i})
            data{i} = '' ;
        elseif isstring(data{i})
            data{i} = char(data{i}) ;
        end
    end
    if formatUnitResults
        data = formatUnitResultData(data,value.Properties.VariableNames) ;
    end
    columnNames = value.Properties.VariableNames ;
    if formatUnitResults && width(value) == 18
        columnNames = {'Block','Type','Status','V','V unit','A','A unit', ...
            'U','U unit','Tin','Tin unit','Tout','Tout unit','Q','Q unit', ...
            'Service flow','Flow unit','Message'} ;
    end
    control = uitable(parent,'Data',data, ...
        'ColumnName',columnNames,'RowName',{}, ...
        'ColumnWidth',columnWidths) ;
    control.Layout.Row = row ;
end

function data = formatUnitResultData(data,names)
    integerColumns = find(ismember(names,{'Status','Iterations'})) ;
    for column = integerColumns
        for row = 1:size(data,1)
            if isnumeric(data{row,column}) && isscalar(data{row,column})
                data{row,column} = sprintf('%.0f',data{row,column}) ;
            end
        end
    end
    convergedColumn = find(strcmp(names,'Converged'),1) ;
    if isempty(convergedColumn), return, end
    for row = 1:size(data,1)
        if isnumeric(data{row,convergedColumn}) || islogical(data{row,convergedColumn})
            if logical(data{row,convergedColumn})
                data{row,convergedColumn} = 'Yes' ;
            else
                data{row,convergedColumn} = 'No' ;
            end
        end
    end
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
