classdef StreamDialog < handle
    % StreamDialog edits feeds and displays calculated stream results.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 2, 2026
    % =========================================================================

    properties (SetAccess = private)
        BlockPath
        Role
        Figure
        ComponentTable
        NameField
        PhaseDropDown
        PressureField
        PressureUnitDropDown
        TemperatureField
        TemperatureUnitDropDown
        VolumetricFlowField
        VolumetricFlowUnitDropDown
        DensityField
        DensityUnitDropDown
        ViscosityField
        ViscosityUnitDropDown
        MolarFlowUnitDropDown
        ConcentrationUnitDropDown
        StatusLabel
        ConversionLabel
        ConversionValue = NaN
        ReferenceFeedDropDown
        KeyComponentDropDown
        SaveButton
        DataModel
    end

    properties (Access = private)
        Package
        DictionaryPath
        ComponentNames
    end

    methods
        function obj = StreamDialog(blockPath,varargin)
            parser = inputParser ;
            addParameter(parser,'Visible','on') ; parse(parser,varargin{:}) ;
            obj.BlockPath = getfullname(blockPath) ;
            obj.Role = string(get_param(obj.BlockPath,'Role')) ;
            obj.DictionaryPath = nirp.flowsheet.modelDictionary(bdroot(obj.BlockPath)) ;
            obj.Package = nirp.pkg.readDictionary(obj.DictionaryPath) ;
            obj.ComponentNames = nirp.pkg.componentNames(obj.Package)' ;
            obj.build(char(string(parser.Results.Visible))) ;
            obj.loadData() ;
        end

        function delete(obj)
            if ~isempty(obj.Figure) && isvalid(obj.Figure), delete(obj.Figure) ; end
        end

        function setValues(obj,varargin)
            if isscalar(varargin) && isstruct(varargin{1})
                values = varargin{1} ; names = fieldnames(values) ;
                for i = 1:numel(names), obj.setValue(names{i},values.(names{i})) ; end
            elseif mod(numel(varargin),2) == 0
                for i = 1:2:numel(varargin), obj.setValue(varargin{i},varargin{i+1}) ; end
            else
                error('nirp:flowsheet:invalidOption', ...
                    'Values must be a struct or name-value pairs.') ;
            end
        end

        function setValue(obj,name,value)
            switch lower(char(string(name)))
                case {'f','molarflow','molarflows'}
                    obj.setComponentColumn(2,value) ;
                case {'c','concentration','concentrations'}
                    obj.setComponentColumn(3,value) ;
                case {'t','temperature'}, obj.TemperatureField.Value = value ;
                case {'p','pressure'}, obj.PressureField.Value = value ;
                case {'q','volumetricflow'}, obj.VolumetricFlowField.Value = value ;
                case 'density', obj.DensityField.Value = value ;
                case 'viscosity', obj.ViscosityField.Value = value ;
                case 'phase', obj.PhaseDropDown.Value = char(string(value)) ;
                case 'referencefeed', obj.ReferenceFeedDropDown.Value = char(string(value)) ;
                case 'keycomponent', obj.KeyComponentDropDown.Value = char(string(value)) ;
                otherwise
                    error('nirp:flowsheet:unknownMagnitude','Unknown stream magnitude "%s".',name) ;
            end
            obj.captureModel() ;
        end

        function value = getValue(obj,name)
            switch lower(char(string(name)))
                case {'f','molarflow','molarflows'}, value = obj.componentColumn(2) ;
                case {'c','concentration','concentrations'}, value = obj.componentColumn(3) ;
                case {'t','temperature'}, value = obj.TemperatureField.Value ;
                case {'p','pressure'}, value = obj.PressureField.Value ;
                case {'q','volumetricflow'}, value = obj.VolumetricFlowField.Value ;
                case 'density', value = obj.DensityField.Value ;
                case 'viscosity', value = obj.ViscosityField.Value ;
                case 'phase', value = string(obj.PhaseDropDown.Value) ;
                case 'name'
                    obj.NameField.Value=get_param(obj.BlockPath,'Name') ;
                    value = string(obj.NameField.Value) ;
                case 'status', value = string(obj.StatusLabel.Text) ;
                case 'conversion', value = obj.ConversionValue ;
                otherwise
                    error('nirp:flowsheet:unknownMagnitude','Unknown stream magnitude "%s".',name) ;
            end
        end

        function setUnits(obj,varargin)
            if isscalar(varargin) && isstruct(varargin{1})
                units = varargin{1} ; names = fieldnames(units) ;
                for i = 1:numel(names), obj.setUnit(names{i},units.(names{i})) ; end
            else
                for i = 1:2:numel(varargin), obj.setUnit(varargin{i},varargin{i+1}) ; end
            end
            if obj.Role ~= "Feed", obj.loadCalculatedResult() ; end
            obj.captureModel() ;
        end

        function setUnit(obj,name,unit)
            unit = char(string(unit)) ;
            switch lower(char(string(name)))
                case {'f','molarflow'}, obj.MolarFlowUnitDropDown.Value = unit ;
                case {'c','concentration'}, obj.ConcentrationUnitDropDown.Value = unit ;
                case {'t','temperature'}, obj.TemperatureUnitDropDown.Value = unit ;
                case {'p','pressure'}, obj.PressureUnitDropDown.Value = unit ;
                case {'q','volumetricflow'}, obj.VolumetricFlowUnitDropDown.Value = unit ;
                case 'density', obj.DensityUnitDropDown.Value = unit ;
                case 'viscosity', obj.ViscosityUnitDropDown.Value = unit ;
                otherwise, error('nirp:flowsheet:unknownMagnitude', ...
                        'Unknown stream magnitude "%s".',name) ;
            end
        end

        function values = getValues(obj)
            obj.NameField.Value=get_param(obj.BlockPath,'Name') ;
            obj.captureModel() ; values = obj.DataModel ;
        end

        function save(obj)
            if obj.Role ~= "Feed"
                error('nirp:flowsheet:readOnlyStream', ...
                    'Only Feed streams can be saved.') ;
            end
            name = get_param(obj.BlockPath,'Name') ;
            obj.NameField.Value=name ;
            flows = obj.componentColumn(2) ; concentrations = obj.componentColumn(3) ;
            hasFlows = any(isfinite(flows)) ; hasConcentrations = any(isfinite(concentrations)) ;
            if hasFlows && hasConcentrations
                error('nirp:flowsheet:ambiguousComposition', ...
                    'Enter molar flows or concentrations, not both.') ;
            elseif hasFlows
                basis = 'molarFlows' ; values = requireComplete(flows,'molar flows') ;
                valuesUnit = obj.MolarFlowUnitDropDown.Value ;
            elseif hasConcentrations
                basis = 'concentrations' ;
                values = requireComplete(concentrations,'concentrations') ;
                valuesUnit = obj.ConcentrationUnitDropDown.Value ;
            else
                error('nirp:flowsheet:missingComposition', ...
                    'Enter molar flows or concentrations for every component.') ;
            end
            qValue = obj.VolumetricFlowField.Value ;
            if qValue == 0, q = [] ;
            else, q = struct('value',qValue,'unit',obj.VolumetricFlowUnitDropDown.Value) ; end
            feed = struct('name',name,'phase',obj.PhaseDropDown.Value, ...
                'T',struct('value',obj.TemperatureField.Value, ...
                    'unit',obj.TemperatureUnitDropDown.Value), ...
                'P',struct('value',obj.PressureField.Value, ...
                    'unit',obj.PressureUnitDropDown.Value), ...
                'basis',basis,'values',reshape(values,1,[]), ...
                'valuesUnit',valuesUnit,'Q',q) ;
            names = string({obj.Package.feeds.name}) ;
            index = find(names == string(name),1) ;
            if isempty(index), obj.Package.feeds(end+1) = feed ;
            else, obj.Package.feeds(index) = feed ; end
            nirp.pkg.validate(obj.Package) ;
            nirp.pkg.writeDictionary(obj.Package,obj.DictionaryPath) ;
            obj.StatusLabel.Text = 'Specified' ;
            obj.captureModel() ;
        end
    end

    methods (Static)
        function dialog = open(blockPath)
            dialog = nirp.flowsheet.StreamDialog(blockPath) ;
        end
    end

    methods (Access = private)
        function build(obj,visible)
            obj.Figure = uifigure('Name','Stream','Visible',visible, ...
                'Position',[100 100 780 455],'Resize','off','Tag','NirpStreamDialog') ;
            grid = uigridlayout(obj.Figure,[9 5], ... % row 9: filler so row 8 keeps its height (Claude, T-111 review)
                'ColumnWidth',{145,145,20,120,170}, ...
                'RowHeight',{34,62,30,30,30,30,30,30,'1x'}, ...
                'Padding',[18 14 18 14]) ;
            helper = uibutton(grid,'Text','Unit conversion helper', ...
                'ButtonPushedFcn',@(~,~) UnitConverterHelper.launch()) ;
            helper.Layout.Row=1; helper.Layout.Column=1 ;
            title = uilabel(grid,'Text','Stream','FontWeight','bold', ...
                'FontSize',16,'HorizontalAlignment','center') ;
            title.Layout.Row=1; title.Layout.Column=[2 4] ;
            tips = uitextarea(grid,'Editable','off', ...
                'Value',{'TIPS';'Enter either molar flows or concentrations.'; ...
                'Feed values are stored in the selected units.'}) ;
            tips.Layout.Row=2; tips.Layout.Column=[1 2] ;
            nameLabel = uilabel(grid,'Text','Name','HorizontalAlignment','right', ...
                'FontWeight','bold') ; nameLabel.Layout.Row=2; nameLabel.Layout.Column=4 ;
            obj.NameField=uieditfield(grid,'text','Value',get_param(obj.BlockPath,'Name'), ...
                'Editable','off') ; obj.NameField.Layout.Row=2;obj.NameField.Layout.Column=5 ;
            obj.ComponentTable = uitable(grid,'ColumnName', ...
                {'Component','Molar Flow','Concentration'},'RowName',{}, ...
                'ColumnEditable',[false obj.Role=="Feed" obj.Role=="Feed"]) ;
            obj.ComponentTable.Layout.Row=[3 9]; obj.ComponentTable.Layout.Column=[1 2] ;
            [obj.PhaseDropDown,~] = rowControl(grid,3,'Phase',{'L','G'},'dropdown') ;
            [obj.PressureField,obj.PressureUnitDropDown] = quantityRow( ...
                grid,4,'P','Pressure') ;
            [obj.TemperatureField,obj.TemperatureUnitDropDown] = quantityRow( ...
                grid,5,'T','Temperature') ;
            [obj.VolumetricFlowField,obj.VolumetricFlowUnitDropDown] = quantityRow( ...
                grid,6,'Volumetric Flow','VolumetricFlow') ;
            [obj.DensityField,obj.DensityUnitDropDown] = quantityRow( ...
                grid,7,'Density','Density') ;
            [obj.ViscosityField,obj.ViscosityUnitDropDown] = quantityRow( ...
                grid,8,'Viscosity','Viscosity') ;
            obj.MolarFlowUnitDropDown = uidropdown(obj.Figure,'Items', ...
                UnitConverterHelper.getUnits('MolarFlow'),'Position',[35 18 130 22]) ;
            obj.ConcentrationUnitDropDown = uidropdown(obj.Figure,'Items', ...
                UnitConverterHelper.getUnits('Concentration'),'Position',[185 18 145 22]) ;
            obj.StatusLabel = uilabel(obj.Figure,'Text','Not calculated yet', ...
                'Position',[400 50 180 22],'FontWeight','bold') ;
            obj.ConversionLabel = uilabel(obj.Figure,'Text','Conversion: n/a', ...
                'Position',[575 50 180 22],'Visible',onOff(obj.Role=="Product")) ;
            feedNames = ['';cellstr(nirp.pkg.feedNames(obj.Package))] ;
            obj.ReferenceFeedDropDown = uidropdown(obj.Figure,'Items',feedNames, ...
                'Position',[400 22 115 22],'Visible',onOff(obj.Role=="Product"), ...
                'ValueChangedFcn',@(~,~) obj.updateConversion()) ;
            obj.KeyComponentDropDown = uidropdown(obj.Figure, ...
                'Items',['';cellstr(obj.ComponentNames)],'Position',[525 22 115 22], ...
                'Visible',onOff(obj.Role=="Product"), ...
                'ValueChangedFcn',@(~,~) obj.updateConversion()) ;
            obj.SaveButton = uibutton(obj.Figure,'Text','Save stream', ...
                'Position',[650 18 105 30],'Visible',onOff(obj.Role=="Feed"), ...
                'ButtonPushedFcn',@(~,~) obj.save()) ;
            editable = onOff(obj.Role=="Feed") ;
            obj.PhaseDropDown.Enable=editable; obj.PressureField.Editable=editable;
            obj.TemperatureField.Editable=editable;obj.VolumetricFlowField.Editable=editable;
            obj.DensityField.Editable='off';obj.ViscosityField.Editable='off';
        end

        function loadData(obj)
            data = cell(numel(obj.ComponentNames),3) ;
            data(:,1) = cellstr(obj.ComponentNames) ;
            data(:,2:3) = {NaN} ; obj.ComponentTable.Data = data ;
            if obj.Role == "Product"
                reference=char(string(get_param(obj.BlockPath,'ReferenceFeed'))) ;
                key=char(string(get_param(obj.BlockPath,'KeyComponent'))) ;
                if any(strcmp(reference,obj.ReferenceFeedDropDown.Items))
                    obj.ReferenceFeedDropDown.Value=reference ;
                end
                if any(strcmp(key,obj.KeyComponentDropDown.Items))
                    obj.KeyComponentDropDown.Value=key ;
                end
            end
            if obj.Role == "Feed", obj.loadFeed() ; else, obj.loadCalculatedResult() ; end
            obj.captureModel() ;
        end

        function loadFeed(obj)
            name = string(get_param(obj.BlockPath,'Name')) ;
            index = find(string({obj.Package.feeds.name}) == name,1) ;
            if isempty(index), obj.StatusLabel.Text='Not specified'; return, end
            feed = obj.Package.feeds(index) ; obj.PhaseDropDown.Value=char(feed.phase) ;
            obj.TemperatureUnitDropDown.Value=normalizeTemperature(feed.T.unit) ;
            obj.TemperatureField.Value=feed.T.value ;
            obj.PressureUnitDropDown.Value=char(feed.P.unit) ; obj.PressureField.Value=feed.P.value ;
            if ~isempty(feed.Q)
                obj.VolumetricFlowUnitDropDown.Value=char(feed.Q.unit) ;
                obj.VolumetricFlowField.Value=feed.Q.value ;
            end
            if strcmpi(feed.basis,'molarFlows')
                obj.MolarFlowUnitDropDown.Value=char(feed.valuesUnit) ;
                obj.setComponentColumn(2,feed.values) ;
            elseif strcmpi(feed.basis,'concentrations')
                obj.ConcentrationUnitDropDown.Value=char(feed.valuesUnit) ;
                obj.setComponentColumn(3,feed.values) ;
            end
            obj.StatusLabel.Text='Specified' ;
        end

        function loadCalculatedResult(obj)
            obj.StatusLabel.Text='Not calculated yet' ;
            if ~evalin('base','exist(''nirpResults'',''var'')'), return, end
            results=evalin('base','nirpResults') ; field=matlab.lang.makeValidName(get_param(obj.BlockPath,'Name')) ;
            if ~isstruct(results)||~isfield(results,'Streams')||~isfield(results.Streams,field),return,end
            item=results.Streams.(field); stream=item.streamSI ;
            obj.setComponentColumn(2,UnitConverterHelper.convertFromSI( ...
                'MolarFlow',stream.F,obj.MolarFlowUnitDropDown.Value)) ;
            if stream.Q>0, c=nirp.stream.concentration(stream);else,c=nan(size(stream.F));end
            obj.setComponentColumn(3,UnitConverterHelper.convertFromSI( ...
                'Concentration',c,obj.ConcentrationUnitDropDown.Value)) ;
            obj.TemperatureField.Value=UnitConverterHelper.convertFromSI( ...
                'Temperature',stream.T,obj.TemperatureUnitDropDown.Value) ;
            obj.PressureField.Value=UnitConverterHelper.convertFromSI( ...
                'Pressure',stream.P,obj.PressureUnitDropDown.Value) ;
            obj.VolumetricFlowField.Value=UnitConverterHelper.convertFromSI( ...
                'VolumetricFlow',stream.Q,obj.VolumetricFlowUnitDropDown.Value) ;
            phases={'L','G'};obj.PhaseDropDown.Value=phases{stream.phase+1} ;
            if stream.status<0,obj.StatusLabel.Text='Not converged';else,obj.StatusLabel.Text='Calculated';end
            obj.updateConversion() ;
        end

        function updateConversion(obj)
            obj.ConversionValue=NaN ; obj.ConversionLabel.Text='Conversion: n/a' ;
            if obj.Role~="Product" || isempty(obj.ReferenceFeedDropDown.Value) || ...
                    isempty(obj.KeyComponentDropDown.Value) || ...
                    ~evalin('base','exist(''nirpResults'',''var'')')
                return
            end
            results=evalin('base','nirpResults') ;
            field=matlab.lang.makeValidName(get_param(obj.BlockPath,'Name')) ;
            if ~isstruct(results)||~isfield(results,'Streams')|| ...
                    ~isfield(results.Streams,field),return,end
            reference=nirp.pkg.feedStream(obj.Package,obj.ReferenceFeedDropDown.Value) ;
            index=find(obj.ComponentNames==string(obj.KeyComponentDropDown.Value),1) ;
            if isempty(index)||reference.F(index)<=0,return,end
            stream=results.Streams.(field).streamSI ;
            obj.ConversionValue=(reference.F(index)-stream.F(index))/reference.F(index) ;
            obj.ConversionLabel.Text=sprintf('Conversion: %.6g',obj.ConversionValue) ;
        end

        function captureModel(obj)
            origin='calculated';if obj.Role=="Feed",origin='specified';end
            obj.DataModel=struct('MolarFlow',quantity(obj.componentColumn(2), ...
                obj.MolarFlowUnitDropDown.Value,origin), ...
                'Concentration',quantity(obj.componentColumn(3), ...
                obj.ConcentrationUnitDropDown.Value,origin), ...
                'T',quantity(obj.TemperatureField.Value,obj.TemperatureUnitDropDown.Value,origin), ...
                'P',quantity(obj.PressureField.Value,obj.PressureUnitDropDown.Value,origin), ...
                'Q',quantity(obj.VolumetricFlowField.Value,obj.VolumetricFlowUnitDropDown.Value,origin), ...
                'Density',quantity(obj.DensityField.Value,obj.DensityUnitDropDown.Value,origin), ...
                'Viscosity',quantity(obj.ViscosityField.Value,obj.ViscosityUnitDropDown.Value,origin)) ;
        end

        function setComponentColumn(obj,column,value)
            value=value(:);if numel(value)~=numel(obj.ComponentNames)
                error('nirp:flowsheet:invalidComposition','Expected %d component values.',numel(obj.ComponentNames));end
            data=obj.ComponentTable.Data;for i=1:numel(value),data{i,column}=value(i);end;obj.ComponentTable.Data=data;
        end
        function value=componentColumn(obj,column)
            data=obj.ComponentTable.Data;value=nan(size(data,1),1);
            for i=1:size(data,1),if isnumeric(data{i,column})&&isscalar(data{i,column}),value(i)=data{i,column};end,end
        end
    end
end

function [field,units]=quantityRow(grid,row,label,category)
    text=uilabel(grid,'Text',label,'HorizontalAlignment','right');text.Layout.Row=row;text.Layout.Column=4;
    holder=uigridlayout(grid,[1 2],'ColumnWidth',{'1x',85},'Padding',[0 0 0 0]);holder.Layout.Row=row;holder.Layout.Column=5;
    field=uieditfield(holder,'numeric','Value',0);units=uidropdown(holder,'Items',UnitConverterHelper.getUnits(category));
end
function [control,label]=rowControl(grid,row,text,items,type)
    label=uilabel(grid,'Text',text,'HorizontalAlignment','right');label.Layout.Row=row;label.Layout.Column=4;
    if strcmp(type,'dropdown'),control=uidropdown(grid,'Items',items);end;control.Layout.Row=row;control.Layout.Column=5;
end
function result=onOff(value),if value,result='on';else,result='off';end,end
function q=quantity(value,unit,origin),q=struct('value',value,'unit',char(unit),'origin',origin);end
function values=requireComplete(values,label)
    if any(~isfinite(values)),error('nirp:flowsheet:missingComposition','Enter %s for every component.',label);end
end
function unit=normalizeTemperature(unit),unit=char(string(unit));if strcmp(unit,'C'),unit=[char(176) 'C'];end,end
