classdef StreamDialog < handle
    % StreamDialog edits feeds and displays calculated stream results.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 12, 2026
    % =========================================================================

    properties (SetAccess = private)
        BlockPath
        Role
        RoleDropDown
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
        TSourceDropDown
        QSourceDropDown
        TPortLabel
        QPortLabel
        TSourceLabel
        QSourceLabel
        DensityField
        DensityUnitDropDown
        ViscosityField
        ViscosityUnitDropDown
        MolarFlowUnitDropDown
        ConcentrationUnitDropDown
        MassFlowUnitDropDown
        TotalMolarFlowField
        TotalMolarFlowUnitDropDown
        TotalConcentrationField
        TotalConcentrationUnitDropDown
        TotalMassFlowField
        TotalMassFlowUnitDropDown
        TotalMassFlowLabel
        StatusLabel
        ConversionLabel
        ConversionValue = NaN
        ReferenceFeedDropDown
        KeyComponentDropDown
        SaveButton
        OKButton
        ApplyButton
        CancelButton
        SpecificationPanel
        SpecificationTable
        SpecificationFlowUnitDropDown
        SpecificationTotalFlowField
        SpecificationTotalFlowUnitDropDown
        SpecificationTemperatureField
        SpecificationTemperatureUnitDropDown
        SpecificationPressureField
        SpecificationPressureUnitDropDown
        DataModel
    end

    properties (Access = private)
        Package
        DictionaryPath
        ComponentNames
        Origins
        Updating = false
        OriginalRole = ''
        Committed = false
        HasMw = false
        LastResult
        SpecifiedSI = struct()
    end

    methods
        function obj = StreamDialog(blockPath,varargin)
            parser = inputParser ;
            addParameter(parser,'Visible','on') ; parse(parser,varargin{:}) ;
            obj.BlockPath = getfullname(blockPath) ;
            try
                mask=Simulink.Mask.get(obj.BlockPath);parameter=mask.getParameter('Specifications');
                if ~isempty(parameter),parameter.Visible='off';end
            catch
            end
            obj.OriginalRole = get_param(obj.BlockPath,'Role') ;
            if strcmp(get_param(obj.BlockPath,'Role'),'Auto')
                % T-145: models saved with the old Auto role take the deduced role.
                role = nirp.flowsheet.streamRole(obj.BlockPath) ;
                if role == "Unconnected", role = "Intermediate" ; end
                set_param(obj.BlockPath,'Role',char(role)) ;
            end
            obj.Role = nirp.flowsheet.streamRole(obj.BlockPath) ;
            obj.DictionaryPath = nirp.flowsheet.modelDictionary(bdroot(obj.BlockPath)) ;
            obj.Package = nirp.pkg.readDictionary(obj.DictionaryPath) ;
            obj.ComponentNames = nirp.pkg.componentNames(obj.Package)' ;
            weights={obj.Package.components.Mw};
            obj.HasMw=all(cellfun(@(x)isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>0,weights)) ;
            obj.build(char(string(parser.Results.Visible))) ;
            nirp.flowsheet.internal.formatNumericControls(obj.Figure) ;
            obj.loadData() ;
            if obj.Role~="Feed"&&isempty(fieldnames(nirp.dof.readSpecs(obj.BlockPath)))&& ...
                    ~startsWith(obj.StatusLabel.Text,'Calculated before run')&& ...
                    ~startsWith(obj.StatusLabel.Text,'Waiting for:')
                [~,~,label] = nirp.flowsheet.blockStatus(obj.BlockPath) ;
                obj.StatusLabel.Text = char(label) ;
            end
        end

        function delete(obj)
            if ~obj.Committed && strlength(string(obj.BlockPath))>0
                try,set_param(obj.BlockPath,'Role',obj.OriginalRole);catch,end
            end
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
            key=lower(char(string(name))) ;
            switch key
                case {'f','molarflow','molarflows'}
                    obj.setComponentColumn(2,value) ;
                case {'c','concentration','concentrations'}
                    obj.setComponentColumn(3,value) ;
                case {'x','molefraction','molefractions'}
                    obj.setComponentColumn(4,value) ;
                case {'mdot','massflow','massflows'}
                    if ~obj.HasMw,error('nirp:flowsheet:missingMolecularWeight','Mass-basis fields require Mw for every component.');end
                    obj.setComponentColumn(5,value) ;
                case {'w','massfraction','massfractions'}
                    if ~obj.HasMw,error('nirp:flowsheet:missingMolecularWeight','Mass-basis fields require Mw for every component.');end
                    obj.setComponentColumn(6,value) ;
                case {'totalf','totalmolarflow'}, obj.TotalMolarFlowField.Value=value ;
                case {'ctot','totalconcentration'}, obj.TotalConcentrationField.Value=value ;
                case {'totalmass','totalmassflow'}, obj.TotalMassFlowField.Value=value ;
                case {'t','temperature'}, obj.TemperatureField.Value = value ;
                case {'p','pressure'}, obj.PressureField.Value = value ;
                case {'q','volumetricflow'}
                    if isnumeric(value)&&isscalar(value)&&isnan(value),obj.Origins.Q="calculated";
                    else,obj.VolumetricFlowField.Value = value;end
                case 'density', obj.DensityField.Value = value ;
                case 'viscosity', obj.ViscosityField.Value = value ;
                case 'phase'
                    obj.PhaseDropDown.Value = char(string(value)) ;
                case 'referencefeed', obj.ReferenceFeedDropDown.Value = char(string(value)) ;
                case 'keycomponent', obj.KeyComponentDropDown.Value = char(string(value)) ;
                case 'tsource', obj.TSourceDropDown.Value = char(string(value)) ;
                case 'qsource', obj.QSourceDropDown.Value = char(string(value)) ;
                otherwise
                    error('nirp:flowsheet:unknownMagnitude','Unknown stream magnitude "%s".',name) ;
            end
            if ~(any(strcmp(key,{'q','volumetricflow'}))&&isnumeric(value)&&isscalar(value)&&isnan(value)),obj.markSpecified(key);obj.rememberSetValue(key,value);end
            obj.closeFeed() ; obj.captureModel() ;
        end

        function value = getValue(obj,name)
            switch lower(char(string(name)))
                case {'f','molarflow','molarflows'}, value = obj.componentColumn(2) ;
                case {'c','concentration','concentrations'}, value = obj.componentColumn(3) ;
                case {'x','molefraction','molefractions'}, value = obj.componentColumn(4) ;
                case {'mdot','massflow','massflows'}, value = obj.componentColumn(5) ;
                case {'w','massfraction','massfractions'}, value = obj.componentColumn(6) ;
                case {'totalf','totalmolarflow'}, value=obj.TotalMolarFlowField.Value ;
                case {'ctot','totalconcentration'}, value=obj.TotalConcentrationField.Value ;
                case {'totalmass','totalmassflow'}, value=obj.TotalMassFlowField.Value ;
                case {'t','temperature'}, value = obj.TemperatureField.Value ;
                case {'p','pressure'}, value = obj.PressureField.Value ;
                case {'q','volumetricflow'}, value = obj.VolumetricFlowField.Value ;
                case 'density', value = obj.DensityField.Value ;
                case 'viscosity', value = obj.ViscosityField.Value ;
                case 'tsource', value = string(obj.TSourceDropDown.Value) ;
                case 'qsource', value = string(obj.QSourceDropDown.Value) ;
                case 'phase', value = string(obj.PhaseDropDown.Value) ;
                case 'role', value = obj.Role ;
                case 'declaredrole', value = string(get_param(obj.BlockPath,'Role')) ;
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
            if obj.Role ~= "Feed", obj.loadCalculatedResult() ;
            else, obj.closeFeed() ; end
            obj.captureModel() ;
        end

        function setUnit(obj,name,unit)
            unit = char(string(unit)) ;
            switch lower(char(string(name)))
                case {'f','molarflow'}, obj.convertDisplayed('MolarFlow',obj.MolarFlowUnitDropDown,unit,2) ;
                case {'c','concentration'}, obj.convertDisplayed('Concentration',obj.ConcentrationUnitDropDown,unit,3) ;
                case {'mdot','massflow'}, obj.convertDisplayed('MassFlow',obj.MassFlowUnitDropDown,unit,5) ;
                case {'totalf','totalmolarflow'}, obj.convertDisplayed('MolarFlow',obj.TotalMolarFlowUnitDropDown,unit,obj.TotalMolarFlowField) ;
                case {'ctot','totalconcentration'}, obj.convertDisplayed('Concentration',obj.TotalConcentrationUnitDropDown,unit,obj.TotalConcentrationField) ;
                case {'totalmass','totalmassflow'}, obj.convertDisplayed('MassFlow',obj.TotalMassFlowUnitDropDown,unit,obj.TotalMassFlowField) ;
                case {'t','temperature'}, obj.convertDisplayed('Temperature',obj.TemperatureUnitDropDown,unit,obj.TemperatureField) ;
                case {'p','pressure'}, obj.convertDisplayed('Pressure',obj.PressureUnitDropDown,unit,obj.PressureField) ;
                case {'q','volumetricflow'}, obj.convertDisplayed('VolumetricFlow',obj.VolumetricFlowUnitDropDown,unit,obj.VolumetricFlowField) ;
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

        function setSpecification(obj,name,value,varargin)
            if obj.Role=="Feed",error('nirp:flowsheet:feedStreamSpecification','Feed data are edited in the feed fields.');end
            key=char(string(name));unit='';if ~isempty(varargin),unit=char(string(varargin{1}));end
            token=regexp(key,'^(F|x)(\d+)$','tokens','once') ;
            if ~isempty(token)
                row=str2double(token{2});if row<1||row>numel(obj.ComponentNames),error('nirp:flowsheet:unknownMagnitude','Unknown stream specification "%s".',name);end
                column=2;if strcmp(token{1},'x'),column=3;end
                if column==2&&~isempty(unit),setUnitIfValid(obj.SpecificationFlowUnitDropDown,unit);end
                data=obj.SpecificationTable.Data;data{row,column}=emptyValue(value);obj.SpecificationTable.Data=data;
            else
                switch upper(key)
                    case 'F',field=obj.SpecificationTotalFlowField;dropdown=obj.SpecificationTotalFlowUnitDropDown;
                    case 'T',field=obj.SpecificationTemperatureField;dropdown=obj.SpecificationTemperatureUnitDropDown;
                    case 'P',field=obj.SpecificationPressureField;dropdown=obj.SpecificationPressureUnitDropDown;
                    otherwise,error('nirp:flowsheet:unknownMagnitude','Unknown stream specification "%s".',name);
                end
                if ~isempty(unit),setUnitIfValid(dropdown,unit);end;field.Value=emptyValue(value);
            end
            obj.previewConnectedSpecifications();
        end

        function specs=getSpecifications(obj),specs=obj.buildConnectedSpecs();end

        function applied = apply(obj)
            applied=false ;
            try
                if obj.Role ~= "Feed"
                    if ~obj.saveConnectedSpecifications(),return,end
                    if obj.Role=="Product"
                        set_param(obj.BlockPath,'ReferenceFeed',obj.ReferenceFeedDropDown.Value, ...
                            'KeyComponent',obj.KeyComponentDropDown.Value);
                    end
                    nirp.flowsheet.afterApply(bdroot(obj.BlockPath),obj.StatusLabel);obj.loadCalculatedResult();obj.Committed=true;applied=true;return
                end
                if ~obj.closeFeed(true), return, end
                obj.saveFeed() ; nirp.flowsheet.afterApply(bdroot(obj.BlockPath),obj.StatusLabel);obj.Committed=true;applied=true ;
            catch exception
                obj.StatusLabel.Text=exception.message ;
            end
        end

        function accept(obj)
            if obj.apply(),delete(obj) ;
            else,nirp.flowsheet.internal.showDialogError(obj.Figure,obj.StatusLabel.Text,'Stream');end
        end

        function cancel(obj), delete(obj) ; end

        function save(obj)
            if ~obj.apply()
                error('nirp:flowsheet:invalidFeed','%s',obj.StatusLabel.Text) ;
            end
        end
    end

    methods (Static)
        function dialog = open(blockPath)
            dialog = nirp.flowsheet.StreamDialog(blockPath) ;
        end
    end

    methods (Access = private)
        function saveFeed(obj)
            if obj.Role ~= "Feed"
                error('nirp:flowsheet:readOnlyStream', ...
                    'Only Feed streams can be saved.') ;
            end
            name = get_param(obj.BlockPath,'Name') ;
            obj.NameField.Value=name ;
            if isempty(obj.LastResult)||~strcmp(obj.LastResult.status,'complete'),error('nirp:flowsheet:missingComposition','The feed is not fully specified.');end
            n=numel(obj.ComponentNames);valuesSI=zeros(1,n);for i=1:n,valuesSI(i)=obj.LastResult.values.(['F' num2str(i)]);end
            if any(~isfinite(valuesSI)),error('nirp:flowsheet:missingComposition','Molar flows must be closed before the feed can be saved.');end
            basis='molarFlows';valuesUnit=obj.MolarFlowUnitDropDown.Value;values=UnitConverterHelper.convertFromSI('MolarFlow',valuesSI,valuesUnit);% A new feed is not in the package yet: only an existing one supplies fallback T, P and Q (Claude, T-157).
            legacy=[];if any(string({obj.Package.feeds.name})==string(name)),legacy=nirp.pkg.feedStream(obj.Package,name);end
            t=obj.LastResult.values.T;if ~isfinite(t),if isempty(legacy),error('nirp:flowsheet:missingSpecification','Enter the feed temperature.');end;t=legacy.T;end
            p=obj.LastResult.values.P;if ~isfinite(p),if isempty(legacy),error('nirp:flowsheet:missingSpecification','Enter the feed pressure.');end;p=legacy.P;end
            qSI=obj.LastResult.values.Q;if ~isfinite(qSI)&&~isempty(legacy),qSI=legacy.Q;end
            if ~isfinite(qSI)&&obj.PhaseDropDown.Value=='L',error('nirp:flowsheet:missingSpecification','Enter the volumetric flow of the liquid feed.');end
            tValue=UnitConverterHelper.convertFromSI('Temperature',t,obj.TemperatureUnitDropDown.Value);pValue=UnitConverterHelper.convertFromSI('Pressure',p,obj.PressureUnitDropDown.Value);
            if obj.PhaseDropDown.Value=='G',q=[];else,q=struct('value',UnitConverterHelper.convertFromSI('VolumetricFlow',qSI,obj.VolumetricFlowUnitDropDown.Value),'unit',obj.VolumetricFlowUnitDropDown.Value);end
            feed = struct('name',name,'phase',obj.PhaseDropDown.Value, ...
                'T',struct('value',tValue,'unit',obj.TemperatureUnitDropDown.Value), ...
                'P',struct('value',pValue,'unit',obj.PressureUnitDropDown.Value), ...
                'basis',basis,'values',reshape(values,1,[]), ...
                'valuesUnit',valuesUnit,'Q',q) ;
            names = string({obj.Package.feeds.name}) ;
            index = find(names == string(name),1) ;
            if isempty(index), obj.Package.feeds(end+1) = feed ;
            else, obj.Package.feeds(index) = feed ; end
            nirp.pkg.validate(obj.Package) ;
            nirp.pkg.writeDictionary(obj.Package,obj.DictionaryPath) ;
            set_param(obj.BlockPath,'TSource',obj.TSourceDropDown.Value, ...
                'QSource',obj.QSourceDropDown.Value) ;
            nirp.dof.writeSpecs(obj.BlockPath,obj.buildFeedSpecs());
            obj.StatusLabel.Text = 'Fully specified' ;
            obj.captureModel() ;
        end
        function build(obj,visible)
            % T-131: grid layout, resizable and always on top; the component
            % table keeps its height and the unit drop-downs sit below it.
            obj.Figure = uifigure('Name','Stream','Visible',visible, ...
                'Position',[30 60 1510 680],'Resize','on', ...
                'WindowStyle','alwaysontop','Tag','NirpStreamDialog') ;
            root = uigridlayout(obj.Figure,[2 1],'RowHeight',{'1x',74}, ...
                'Padding',[0 0 0 0],'RowSpacing',0) ;
            grid = uigridlayout(root,[15 7], ...
                'ColumnWidth',{'1x','1x',110,120,245,135,255}, ...
                'RowHeight',{34,30,30,30,30,30,30,30,30,30,30,30,30,'1x',26}, ...
                'Padding',[18 14 18 4]) ;
            grid.Layout.Row=1 ;
            helper = uibutton(grid,'Text','Unit conversion helper', ...
                'ButtonPushedFcn',@(~,~) UnitConverterHelper.launch()) ;
            helper.Layout.Row=1; helper.Layout.Column=1 ;
            title = uilabel(grid,'Text','Stream','FontWeight','bold', ...
                'FontSize',16,'HorizontalAlignment','center') ;
            title.Layout.Row=1; title.Layout.Column=[2 3] ;
            roleLabel = uilabel(grid,'Text','Role','HorizontalAlignment','right', ...
                'FontWeight','bold') ;
            roleLabel.Layout.Row=1; roleLabel.Layout.Column=4 ;
            obj.RoleDropDown = uidropdown(grid, ...
                'ValueChangedFcn',@(~,~) obj.roleEdited()) ;
            obj.RoleDropDown.Layout.Row=1; obj.RoleDropDown.Layout.Column=5 ;
            obj.updateRoleSelector() ;
            nameLabel = uilabel(grid,'Text','Name','HorizontalAlignment','right', ...
                'FontWeight','bold') ; nameLabel.Layout.Row=2; nameLabel.Layout.Column=4 ;
            obj.NameField=uieditfield(grid,'text','Value',get_param(obj.BlockPath,'Name'), ...
                'Editable','off') ; obj.NameField.Layout.Row=2;obj.NameField.Layout.Column=5 ;
            columns={'Component','Molar Flow','Concentration','Mole Fraction'};
            if obj.HasMw,columns=[columns {'Mass Flow','Mass Fraction'}];end
            obj.ComponentTable = uitable(grid,'ColumnName',columns,'RowName',{}, ...
                'ColumnEditable',[false repmat(obj.Role=="Feed",1,numel(columns)-1)], ...
                'CellEditCallback',@(~,event) obj.componentEdited(event)) ;
            obj.ComponentTable.Layout.Row=[2 14]; obj.ComponentTable.Layout.Column=[1 3] ;
            [obj.PhaseDropDown,~] = rowControl(grid,3,'Phase',{'L','G'},'dropdown') ;
            [obj.PressureField,obj.PressureUnitDropDown] = quantityRow( ...
                grid,4,'P','Pressure') ;
            [obj.TemperatureField,obj.TemperatureUnitDropDown] = quantityRow( ...
                grid,5,'T','Temperature') ;
            obj.TPortLabel = portLabel(obj.TemperatureField.Parent) ;
            [obj.VolumetricFlowField,obj.VolumetricFlowUnitDropDown] = quantityRow( ...
                grid,6,'Volumetric Flow','VolumetricFlow') ;
            obj.QPortLabel = portLabel(obj.VolumetricFlowField.Parent) ;
            [obj.TotalMolarFlowField,obj.TotalMolarFlowUnitDropDown] = quantityRow(grid,7,'Total Molar Flow','MolarFlow') ;
            [obj.TotalConcentrationField,obj.TotalConcentrationUnitDropDown] = quantityRow(grid,8,'Total Concentration','Concentration') ;
            [obj.TotalMassFlowField,obj.TotalMassFlowUnitDropDown,obj.TotalMassFlowLabel] = quantityRow(grid,9,'Total Mass Flow','MassFlow') ;
            [obj.TSourceDropDown,obj.TSourceLabel] = rowControl(grid,10,'T source', ...
                {'Dialog','Input port'},'dropdown') ;
            [obj.QSourceDropDown,obj.QSourceLabel] = rowControl(grid,11,'Q source', ...
                {'Dialog','Input port'},'dropdown') ;
            obj.TSourceDropDown.ValueChangedFcn=@(~,~) obj.updatePortSources() ;
            obj.QSourceDropDown.ValueChangedFcn=@(~,~) obj.updatePortSources() ;
            [obj.DensityField,obj.DensityUnitDropDown] = quantityRow( ...
                grid,12,'Density','Density') ;
            [obj.ViscosityField,obj.ViscosityUnitDropDown] = quantityRow( ...
                grid,13,'Viscosity','Viscosity') ;
            note = uilabel(grid,'Text','Density and viscosity are optional; leave them blank if not used.', ...
                'FontAngle','italic','WordWrap','on','VerticalAlignment','top') ;
            note.Layout.Row=14; note.Layout.Column=[4 5] ;
            obj.DensityField.AllowEmpty='on';obj.DensityField.Value=[];
            obj.ViscosityField.AllowEmpty='on';obj.ViscosityField.Value=[];
            obj.MolarFlowUnitDropDown = uidropdown(grid,'Items', ...
                UnitConverterHelper.getUnits('MolarFlow'), ...
                'ValueChangedFcn',@(source,event) obj.unitEdited('MolarFlow',source,event,2)) ;
            obj.MolarFlowUnitDropDown.Layout.Row=15; obj.MolarFlowUnitDropDown.Layout.Column=1 ;
            obj.ConcentrationUnitDropDown = uidropdown(grid,'Items', ...
                UnitConverterHelper.getUnits('Concentration'), ...
                'ValueChangedFcn',@(source,event) obj.unitEdited('Concentration',source,event,3)) ;
            obj.ConcentrationUnitDropDown.Layout.Row=15; obj.ConcentrationUnitDropDown.Layout.Column=2 ;
            obj.MassFlowUnitDropDown = uidropdown(grid,'Items',UnitConverterHelper.getUnits('MassFlow'), ...
                'Visible',onOff(obj.HasMw),'ValueChangedFcn',@(source,event) obj.unitEdited('MassFlow',source,event,5)) ;
            obj.MassFlowUnitDropDown.Layout.Row=15;obj.MassFlowUnitDropDown.Layout.Column=3 ;
            bottom = uigridlayout(root,[2 4],'ColumnWidth',{'1x',115,115,95}, ...
                'RowHeight',{22,30},'Padding',[18 12 18 4]) ;
            bottom.Layout.Row=2 ;
            obj.StatusLabel = uilabel(bottom,'Text','Not calculated yet','FontWeight','bold') ;
            obj.StatusLabel.Layout.Row=1; obj.StatusLabel.Layout.Column=1 ;
            obj.ConversionLabel = uilabel(bottom,'Text','Conversion: n/a', ...
                'Visible',onOff(obj.Role=="Product")) ;
            obj.ConversionLabel.Layout.Row=1; obj.ConversionLabel.Layout.Column=[2 4] ;
            feedNames = ['';cellstr(nirp.pkg.feedNames(obj.Package))] ;
            obj.ReferenceFeedDropDown = uidropdown(bottom,'Items',feedNames, ...
                'Visible',onOff(obj.Role=="Product"), ...
                'ValueChangedFcn',@(~,~) obj.updateConversion()) ;
            obj.ReferenceFeedDropDown.Layout.Row=2; obj.ReferenceFeedDropDown.Layout.Column=2 ;
            obj.KeyComponentDropDown = uidropdown(bottom, ...
                'Items',['';cellstr(obj.ComponentNames)], ...
                'Visible',onOff(obj.Role=="Product"), ...
                'ValueChangedFcn',@(~,~) obj.updateConversion()) ;
            obj.KeyComponentDropDown.Layout.Row=2; obj.KeyComponentDropDown.Layout.Column=3 ;
            obj.OKButton=uibutton(bottom,'Text','OK', ...
                'ButtonPushedFcn',@(~,~) obj.accept()) ;
            obj.OKButton.Layout.Row=2; obj.OKButton.Layout.Column=2 ;
            obj.CancelButton=uibutton(bottom,'Text','Cancel', ...
                'ButtonPushedFcn',@(~,~) obj.cancel()) ;
            obj.CancelButton.Layout.Row=2; obj.CancelButton.Layout.Column=3 ;
            obj.ApplyButton=uibutton(bottom,'Text','Apply', ...
                'ButtonPushedFcn',@(~,~) obj.apply()) ;
            obj.ApplyButton.Layout.Row=2; obj.ApplyButton.Layout.Column=4 ;
            obj.SaveButton=obj.ApplyButton ;
            obj.DensityField.Editable='off';obj.ViscosityField.Editable='off';
            obj.PhaseDropDown.ValueChangedFcn=@(~,~) obj.phaseEdited() ;
            obj.TemperatureField.ValueChangedFcn=@(~,~) obj.scalarEdited('T') ;
            obj.PressureField.ValueChangedFcn=@(~,~) obj.scalarEdited('P') ;
            obj.VolumetricFlowField.ValueChangedFcn=@(~,~) obj.scalarEdited('Q') ;
            obj.TotalMolarFlowField.ValueChangedFcn=@(~,~) obj.scalarEdited('F_total') ;
            obj.TotalConcentrationField.ValueChangedFcn=@(~,~) obj.scalarEdited('C_tot') ;
            obj.TotalMassFlowField.ValueChangedFcn=@(~,~) obj.scalarEdited('mdot_total') ;
            obj.TemperatureUnitDropDown.ValueChangedFcn=@(source,event) obj.unitEdited('Temperature',source,event,obj.TemperatureField) ;
            obj.PressureUnitDropDown.ValueChangedFcn=@(source,event) obj.unitEdited('Pressure',source,event,obj.PressureField) ;
            obj.VolumetricFlowUnitDropDown.ValueChangedFcn=@(source,event) obj.unitEdited('VolumetricFlow',source,event,obj.VolumetricFlowField) ;
            obj.TotalMolarFlowUnitDropDown.ValueChangedFcn=@(source,event) obj.unitEdited('MolarFlow',source,event,obj.TotalMolarFlowField) ;
            obj.TotalConcentrationUnitDropDown.ValueChangedFcn=@(source,event) obj.unitEdited('Concentration',source,event,obj.TotalConcentrationField) ;
            obj.TotalMassFlowUnitDropDown.ValueChangedFcn=@(source,event) obj.unitEdited('MassFlow',source,event,obj.TotalMassFlowField) ;
            obj.TotalMassFlowField.Visible=onOff(obj.HasMw);obj.TotalMassFlowUnitDropDown.Visible=onOff(obj.HasMw);obj.TotalMassFlowLabel.Visible=onOff(obj.HasMw);
            obj.buildSpecificationPanel(grid) ;
            obj.updateRolePresentation() ;
        end

        function buildSpecificationPanel(obj,grid)
            obj.SpecificationPanel=uipanel(grid,'Title','Specifications','FontWeight','bold');
            obj.SpecificationPanel.Layout.Row=[2 14];obj.SpecificationPanel.Layout.Column=[6 7];
            g=uigridlayout(obj.SpecificationPanel,[8 3],'ColumnWidth',{115,'1x',88}, ...
                'RowHeight',{44,30,24,'1x',30,30,30,42},'Padding',[8 6 8 6]);
            note=uilabel(g,'Text','Output targets for the directly connected producer. Leave all fields empty unless the producer can meet them.','WordWrap','on','FontAngle','italic');note.Layout.Row=1;note.Layout.Column=[1 3];
            label=uilabel(g,'Text','Total molar flow','HorizontalAlignment','right');label.Layout.Row=2;label.Layout.Column=1;
            obj.SpecificationTotalFlowField=uieditfield(g,'numeric','AllowEmpty','on','Value',[],'ValueChangedFcn',@(~,~)obj.previewConnectedSpecifications());obj.SpecificationTotalFlowField.Layout.Row=2;obj.SpecificationTotalFlowField.Layout.Column=2;
            obj.SpecificationTotalFlowUnitDropDown=uidropdown(g,'Items',UnitConverterHelper.getUnits('MolarFlow'),'ValueChangedFcn',@(source,event)obj.specificationUnitEdited('MolarFlow',source,event,obj.SpecificationTotalFlowField));obj.SpecificationTotalFlowUnitDropDown.Layout.Row=2;obj.SpecificationTotalFlowUnitDropDown.Layout.Column=3;
            label=uilabel(g,'Text','Component specifications','FontWeight','bold');label.Layout.Row=3;label.Layout.Column=[1 3];
            data=[cellstr(obj.ComponentNames(:)) repmat({[]},numel(obj.ComponentNames),2)];
            obj.SpecificationTable=uitable(g,'Data',data,'ColumnName',{'Component','F','x'},'RowName',{},'ColumnEditable',[false true true],'CellEditCallback',@(~,~)obj.previewConnectedSpecifications());obj.SpecificationTable.Layout.Row=4;obj.SpecificationTable.Layout.Column=[1 3];
            label=uilabel(g,'Text','Component F unit','HorizontalAlignment','right');label.Layout.Row=5;label.Layout.Column=1;
            obj.SpecificationFlowUnitDropDown=uidropdown(g,'Items',UnitConverterHelper.getUnits('MolarFlow'),'ValueChangedFcn',@(source,event)obj.specificationUnitEdited('MolarFlow',source,event,2));obj.SpecificationFlowUnitDropDown.Layout.Row=5;obj.SpecificationFlowUnitDropDown.Layout.Column=[2 3];
            label=uilabel(g,'Text','Temperature','HorizontalAlignment','right');label.Layout.Row=6;label.Layout.Column=1;
            obj.SpecificationTemperatureField=uieditfield(g,'numeric','AllowEmpty','on','Value',[],'ValueChangedFcn',@(~,~)obj.previewConnectedSpecifications());obj.SpecificationTemperatureField.Layout.Row=6;obj.SpecificationTemperatureField.Layout.Column=2;
            obj.SpecificationTemperatureUnitDropDown=uidropdown(g,'Items',UnitConverterHelper.getUnits('Temperature'),'ValueChangedFcn',@(source,event)obj.specificationUnitEdited('Temperature',source,event,obj.SpecificationTemperatureField));obj.SpecificationTemperatureUnitDropDown.Layout.Row=6;obj.SpecificationTemperatureUnitDropDown.Layout.Column=3;
            label=uilabel(g,'Text','Pressure','HorizontalAlignment','right');label.Layout.Row=7;label.Layout.Column=1;
            obj.SpecificationPressureField=uieditfield(g,'numeric','AllowEmpty','on','Value',[],'ValueChangedFcn',@(~,~)obj.previewConnectedSpecifications());obj.SpecificationPressureField.Layout.Row=7;obj.SpecificationPressureField.Layout.Column=2;
            obj.SpecificationPressureUnitDropDown=uidropdown(g,'Items',UnitConverterHelper.getUnits('Pressure'),'ValueChangedFcn',@(source,event)obj.specificationUnitEdited('Pressure',source,event,obj.SpecificationPressureField));obj.SpecificationPressureUnitDropDown.Layout.Row=7;obj.SpecificationPressureUnitDropDown.Layout.Column=3;
            hint=uilabel(g,'Text','Splitter: total F. Separator: component F or x. Heater: T or P.','WordWrap','on');hint.Layout.Row=8;hint.Layout.Column=[1 3];
        end

        function loadConnectedSpecifications(obj)
            obj.SpecificationTotalFlowField.Value=[];obj.SpecificationTemperatureField.Value=[];obj.SpecificationPressureField.Value=[];
            data=obj.SpecificationTable.Data;data(:,2:3)={[]};obj.SpecificationTable.Data=data;
            specs=nirp.dof.readSpecs(obj.BlockPath);names=fieldnames(specs);
            flowUnit='';for i=1:numel(names),if strcmp(names{i},'F')||~isempty(regexp(names{i},'^F\d+$','once')),flowUnit=char(string(specs.(names{i}).unit));break,end,end
            if ~isempty(flowUnit),setUnitIfValid(obj.SpecificationTotalFlowUnitDropDown,flowUnit);setUnitIfValid(obj.SpecificationFlowUnitDropDown,flowUnit);end
            for i=1:numel(names)
                name=names{i};item=specs.(name);token=regexp(name,'^(F|x)(\d+)$','tokens','once');
                if ~isempty(token)
                    row=str2double(token{2});if row>numel(obj.ComponentNames),continue,end;column=2;if strcmp(token{1},'x'),column=3;value=item.si;else,value=UnitConverterHelper.convertFromSI('MolarFlow',value,obj.SpecificationFlowUnitDropDown.Value);end
                    data=obj.SpecificationTable.Data;data{row,column}=value;obj.SpecificationTable.Data=data;continue
                end
                switch name
                    case 'F',setUnitIfValid(obj.SpecificationTotalFlowUnitDropDown,item.unit);obj.SpecificationTotalFlowField.Value=UnitConverterHelper.convertFromSI('MolarFlow',item.si,obj.SpecificationTotalFlowUnitDropDown.Value);
                    case 'T',setUnitIfValid(obj.SpecificationTemperatureUnitDropDown,item.unit);obj.SpecificationTemperatureField.Value=UnitConverterHelper.convertFromSI('Temperature',item.si,obj.SpecificationTemperatureUnitDropDown.Value);
                    case 'P',setUnitIfValid(obj.SpecificationPressureUnitDropDown,item.unit);obj.SpecificationPressureField.Value=UnitConverterHelper.convertFromSI('Pressure',item.si,obj.SpecificationPressureUnitDropDown.Value);
                end
            end
            obj.previewConnectedSpecifications();
        end

        function specs=buildConnectedSpecs(obj)
            specs=struct();
            if ~isempty(obj.SpecificationTotalFlowField.Value),specs.F=struct('si',UnitConverterHelper.convertToSI('MolarFlow',obj.SpecificationTotalFlowField.Value,obj.SpecificationTotalFlowUnitDropDown.Value),'unit',char(obj.SpecificationTotalFlowUnitDropDown.Value));end
            data=obj.SpecificationTable.Data;for i=1:size(data,1),if isFiniteScalar(data{i,2}),name=['F' num2str(i)];specs.(name)=struct('si',UnitConverterHelper.convertToSI('MolarFlow',data{i,2},obj.SpecificationFlowUnitDropDown.Value),'unit',char(obj.SpecificationFlowUnitDropDown.Value));end;if isFiniteScalar(data{i,3}),name=['x' num2str(i)];specs.(name)=struct('si',data{i,3},'unit','1');end,end
            if ~isempty(obj.SpecificationTemperatureField.Value),specs.T=struct('si',UnitConverterHelper.convertToSI('Temperature',obj.SpecificationTemperatureField.Value,obj.SpecificationTemperatureUnitDropDown.Value),'unit',char(obj.SpecificationTemperatureUnitDropDown.Value));end
            if ~isempty(obj.SpecificationPressureField.Value),specs.P=struct('si',UnitConverterHelper.convertToSI('Pressure',obj.SpecificationPressureField.Value,obj.SpecificationPressureUnitDropDown.Value),'unit',char(obj.SpecificationPressureUnitDropDown.Value));end
        end

        function [valid,target,state]=previewConnectedSpecifications(obj)
            valid=true;target=[];state=[];specs=obj.buildConnectedSpecs();obj.styleConnectedSpecifications([],specs);
            if isempty(fieldnames(specs)),obj.StatusLabel.Text='No stream specifications.';return,end
            try
                target=nirp.dof.streamSpecificationTarget(obj.BlockPath,specs);
                state=nirp.dof.producerState(target.ProducerPath,'OverrideStream',obj.BlockPath,'OverrideSpecifications',specs);
                obj.styleConnectedSpecifications(state.Result,specs);
                if strcmp(state.Result.status,'conflict'),valid=false;message="Conflict: "+strjoin(state.Result.messages,' ');status='conflict';
                elseif strcmp(state.Result.status,'missing'),message="Producer needs more specifications: "+state.Result.messages(end);status='missing';
                else,message="Fully specified by "+string(target.ProducerName);status='complete';end
                nirp.flowsheet.internal.paintDofStatus(obj.StatusLabel,status,message);
            catch exception
                valid=false;obj.styleConnectedSpecifications([],specs,'conflict');nirp.flowsheet.internal.paintDofStatus(obj.StatusLabel,'conflict',exception.message);
            end
        end

        function saved=saveConnectedSpecifications(obj)
            specs=obj.buildConnectedSpecs();
            if isempty(fieldnames(specs)),nirp.dof.writeSpecs(obj.BlockPath,specs);saved=true;obj.StatusLabel.Text='No stream specifications.';return,end
            [saved,~,~]=obj.previewConnectedSpecifications();
            if ~saved
                warning('nirp:flowsheet:streamSpecificationNotSaved','%s',obj.StatusLabel.Text);return
            end
            nirp.dof.writeSpecs(obj.BlockPath,specs);
        end

        function styleConnectedSpecifications(obj,result,specs,forcedState)
            if nargin<4,forcedState='specified';end
            styleDofField(obj.SpecificationTotalFlowField,'optional');styleDofField(obj.SpecificationTemperatureField,'optional');styleDofField(obj.SpecificationPressureField,'optional');removeStyle(obj.SpecificationTable);
            fields=fieldnames(specs);for i=1:numel(fields),name=fields{i};state=forcedState;
                if ~isempty(result)
                    try,target=nirp.dof.streamSpecificationTarget(obj.BlockPath,struct(name,specs.(name)));producerNames=fieldnames(target.Values);state=result.states.(producerNames{1});catch,end
                end
                token=regexp(name,'^(F|x)(\d+)$','tokens','once');
                if ~isempty(token),row=str2double(token{2});column=2;if strcmp(token{1},'x'),column=3;end;addCellStateStyles(obj.SpecificationTable,column,setAt(strings(size(obj.SpecificationTable.Data,1),1),row,state));
                elseif strcmp(name,'F'),styleDofField(obj.SpecificationTotalFlowField,state);elseif strcmp(name,'T'),styleDofField(obj.SpecificationTemperatureField,state);elseif strcmp(name,'P'),styleDofField(obj.SpecificationPressureField,state);end
            end
        end

        function specificationUnitEdited(obj,category,source,event,target)
            old=event.PreviousValue;new=event.Value;if strcmp(old,new),return,end
            if isnumeric(target),data=obj.SpecificationTable.Data;values=nan(size(data,1),1);for i=1:numel(values),if isFiniteScalar(data{i,target}),values(i)=data{i,target};end,end;converted=UnitConverterHelper.convertFromSI(category,UnitConverterHelper.convertToSI(category,values,old),new);for i=1:numel(values),if isfinite(values(i)),data{i,target}=converted(i);end,end;obj.SpecificationTable.Data=data;
            elseif ~isempty(target.Value),target.Value=UnitConverterHelper.convertFromSI(category,UnitConverterHelper.convertToSI(category,target.Value,old),new);end
            source.Value=new;obj.previewConnectedSpecifications();
        end

        function roleEdited(obj)
            declared = char(string(obj.RoleDropDown.Value)) ;
            try
                set_param(obj.BlockPath,'Role',declared) ;
                obj.Role = nirp.flowsheet.streamRole(obj.BlockPath) ;
                obj.updateRoleSelector() ;
                obj.updateRolePresentation() ;
                obj.loadData() ;
                [~,~,label] = nirp.flowsheet.blockStatus(obj.BlockPath) ;
                obj.StatusLabel.Text = char(label) ;
            catch exception
                obj.StatusLabel.Text = exception.message ;
                obj.updateRoleSelector() ;
            end
        end

        function updateRoleSelector(obj)
            declared = char(string(get_param(obj.BlockPath,'Role'))) ;
            obj.RoleDropDown.Items = {'Select...','Feed','Intermediate','Product'} ;
            obj.RoleDropDown.ItemsData = {'Select...','Feed','Intermediate','Product'} ;
            if any(strcmp(declared,obj.RoleDropDown.Items)), obj.RoleDropDown.Value = declared ; end
        end

        function updateRolePresentation(obj)
            isFeed = obj.Role == "Feed" ;
            isProduct = obj.Role == "Product" ;
            editable = onOff(isFeed) ;
            obj.ComponentTable.ColumnEditable = [false repmat(isFeed,1,numel(obj.ComponentTable.ColumnName)-1)] ; % from the columns, not the (possibly empty) data (Claude, T-157)
            obj.TSourceLabel.Visible=editable;obj.QSourceLabel.Visible=editable;
            obj.TSourceDropDown.Visible=editable;obj.QSourceDropDown.Visible=editable;
            obj.PhaseDropDown.Enable=editable;obj.PressureField.Editable=editable;
            obj.TemperatureField.Editable=editable;
            obj.VolumetricFlowField.Editable=editable;
            obj.TotalMolarFlowField.Editable=editable;obj.TotalConcentrationField.Editable=editable;
            obj.TotalMassFlowField.Editable=onOff(isFeed&&obj.HasMw);
            obj.ConversionLabel.Visible=onOff(isProduct) ;
            obj.ReferenceFeedDropDown.Visible=onOff(isProduct) ;
            obj.KeyComponentDropDown.Visible=onOff(isProduct) ;
            obj.SpecificationPanel.Visible=onOff(~isFeed) ;
            obj.OKButton.Visible='on';obj.ApplyButton.Visible='on';
            obj.CancelButton.Text='Cancel' ;obj.CancelButton.Layout.Column=3 ;obj.SaveButton=obj.ApplyButton ;
            obj.updatePortSources() ;
        end

        function loadData(obj)
            n=numel(obj.ComponentNames);empty=repmat("empty",n,1);
            obj.SpecifiedSI=struct();
            obj.Origins=struct('F',empty,'C',empty,'x',empty,'mdot',empty,'w',empty, ...
                'F_total',"empty",'C_tot',"empty",'mdot_total',"empty", ...
                'T',"empty",'P',"empty",'Q',"empty") ;
            data = cell(n,4+2*obj.HasMw) ;
            data(:,1) = cellstr(obj.ComponentNames) ;
            data(:,2:end) = {[]} ; obj.ComponentTable.Data = data ;
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
            if obj.Role == "Feed"
                obj.TSourceDropDown.Value=get_param(obj.BlockPath,'TSource') ;
                obj.QSourceDropDown.Value=get_param(obj.BlockPath,'QSource') ;
            end
            if obj.Role == "Feed"
                obj.loadFeed() ; obj.closeFeed() ;
            else
                obj.loadCalculatedResult();previewStatus=obj.StatusLabel.Text;obj.loadConnectedSpecifications();
                if isempty(fieldnames(nirp.dof.readSpecs(obj.BlockPath)))&& ...
                        (startsWith(previewStatus,'Calculated before run')||startsWith(previewStatus,'Waiting for:'))
                    obj.StatusLabel.Text=previewStatus;
                end
            end
            obj.captureModel() ;
        end

        function loadFeed(obj)
            name = string(get_param(obj.BlockPath,'Name')) ;
            index = find(string({obj.Package.feeds.name}) == name,1) ;
            if isempty(index), obj.StatusLabel.Text='Not specified'; return, end
            feed=obj.Package.feeds(index);stream=nirp.pkg.feedStream(obj.Package,name);obj.PhaseDropDown.Value=char(feed.phase);
            obj.TemperatureUnitDropDown.Value=normalizeTemperature(feed.T.unit);obj.TemperatureField.Value=feed.T.value;
            obj.PressureUnitDropDown.Value=char(feed.P.unit);obj.PressureField.Value=feed.P.value;
            if ~isempty(feed.Q),obj.VolumetricFlowUnitDropDown.Value=char(feed.Q.unit);obj.VolumetricFlowField.Value=feed.Q.value;end
            obj.setComponentColumn(2,UnitConverterHelper.convertFromSI('MolarFlow',stream.F,obj.MolarFlowUnitDropDown.Value));
            c=nirp.stream.concentration(stream);obj.setComponentColumn(3,UnitConverterHelper.convertFromSI('Concentration',c,obj.ConcentrationUnitDropDown.Value));
            total=sum(stream.F);obj.setComponentColumn(4,stream.F/total);
            obj.TotalMolarFlowField.Value=UnitConverterHelper.convertFromSI('MolarFlow',total,obj.TotalMolarFlowUnitDropDown.Value);
            obj.TotalConcentrationField.Value=UnitConverterHelper.convertFromSI('Concentration',sum(c),obj.TotalConcentrationUnitDropDown.Value);
            if obj.HasMw
                mw=cell2mat({obj.Package.components.Mw});mw=mw(:)*1e-3;mass=stream.F.*mw;massTotal=sum(mass);
                obj.setComponentColumn(5,UnitConverterHelper.convertFromSI('MassFlow',mass,obj.MassFlowUnitDropDown.Value));obj.setComponentColumn(6,mass/massTotal);
                obj.TotalMassFlowField.Value=UnitConverterHelper.convertFromSI('MassFlow',massTotal,obj.TotalMassFlowUnitDropDown.Value);
            end
            specText='';try,specText=get_param(obj.BlockPath,'Specifications');catch,end
            if isempty(strtrim(specText))
                switch lower(char(feed.basis))
                    case 'molarflows',obj.Origins.F(:)="specified";
                    case 'concentrations',obj.Origins.C(:)="specified";
                    otherwise
                        obj.Origins.F_total="specified";obj.Origins.x(1:max(0,numel(obj.ComponentNames)-1))="specified";
                end
                obj.Origins.T="specified";obj.Origins.P="specified";
                if obj.PhaseDropDown.Value=='L',obj.Origins.Q="specified";end
            else
                specs=nirp.dof.readSpecs(specText);fields=fieldnames(specs);
                for k=1:numel(fields),obj.loadSpecification(fields{k},specs.(fields{k}));end
            end
            if strcmp(obj.TSourceDropDown.Value,'Input port'),obj.Origins.T="external";end
            if strcmp(obj.QSourceDropDown.Value,'Input port'),obj.Origins.Q="external";end
            for i=1:numel(obj.ComponentNames)
                obj.SpecifiedSI.(['F' num2str(i)])=stream.F(i);
                obj.SpecifiedSI.(['C' num2str(i)])=c(i);
                obj.SpecifiedSI.(['x' num2str(i)])=stream.F(i)/total;
                if obj.HasMw
                    obj.SpecifiedSI.(['mdot' num2str(i)])=mass(i);
                    obj.SpecifiedSI.(['w' num2str(i)])=mass(i)/massTotal;
                end
            end
            obj.SpecifiedSI.F=total;obj.SpecifiedSI.C_tot=sum(c);
            if obj.HasMw,obj.SpecifiedSI.mdot=massTotal;end
            obj.SpecifiedSI.T=stream.T;obj.SpecifiedSI.P=stream.P;obj.SpecifiedSI.Q=stream.Q;
            obj.StatusLabel.Text='Specified' ;
        end

        function loadCalculatedResult(obj)
            obj.StatusLabel.Text='Not calculated yet' ;
            field=matlab.lang.makeValidName(get_param(obj.BlockPath,'Name')) ;
            preview=nirp.flowsheet.preview('get',bdroot(obj.BlockPath));fromPreview=false;
            if isstruct(preview)&&isfield(preview,'Streams')&&isfield(preview.Streams,field)
                item=preview.Streams.(field);
                if strcmp(item.status,'waiting'),obj.StatusLabel.Text=['Waiting for: ' stripWaiting(item.reason)];return,end
                stream=item.streamSI;fromPreview=true;
            elseif evalin('base','exist(''nirpResults'',''var'')')
                results=evalin('base','nirpResults');
                if ~isstruct(results)||~isfield(results,'Streams')||~isfield(results.Streams,field),return,end
                item=results.Streams.(field);stream=item.streamSI;
            else
                return
            end
            obj.setComponentColumn(2,UnitConverterHelper.convertFromSI( ...
                'MolarFlow',stream.F,obj.MolarFlowUnitDropDown.Value)) ;
            if stream.Q>0, c=nirp.stream.concentration(stream);else,c=nan(size(stream.F));end
            obj.setComponentColumn(3,UnitConverterHelper.convertFromSI( ...
                'Concentration',c,obj.ConcentrationUnitDropDown.Value)) ;
            total=sum(stream.F);if total>0,obj.setComponentColumn(4,stream.F/total);else,obj.setComponentColumn(4,nan(size(stream.F)));end
            obj.TotalMolarFlowField.Value=UnitConverterHelper.convertFromSI('MolarFlow',total,obj.TotalMolarFlowUnitDropDown.Value);
            obj.TotalConcentrationField.Value=UnitConverterHelper.convertFromSI('Concentration',sum(c),obj.TotalConcentrationUnitDropDown.Value);
            if obj.HasMw
                mw=cell2mat({obj.Package.components.Mw});mw=mw(:)*1e-3;mass=stream.F(:).*mw;mt=sum(mass);
                obj.setComponentColumn(5,UnitConverterHelper.convertFromSI('MassFlow',mass,obj.MassFlowUnitDropDown.Value));
                if mt>0,obj.setComponentColumn(6,mass/mt);else,obj.setComponentColumn(6,nan(size(mass)));end
                obj.TotalMassFlowField.Value=UnitConverterHelper.convertFromSI('MassFlow',mt,obj.TotalMassFlowUnitDropDown.Value);
            end
            obj.TemperatureField.Value=UnitConverterHelper.convertFromSI( ...
                'Temperature',stream.T,obj.TemperatureUnitDropDown.Value) ;
            obj.PressureField.Value=UnitConverterHelper.convertFromSI( ...
                'Pressure',stream.P,obj.PressureUnitDropDown.Value) ;
            obj.VolumetricFlowField.Value=UnitConverterHelper.convertFromSI( ...
                'VolumetricFlow',stream.Q,obj.VolumetricFlowUnitDropDown.Value) ;
            phases={'L','G'};obj.PhaseDropDown.Value=phases{stream.phase+1} ;
            removeStyle(obj.ComponentTable) ;
            calculated=repmat("calculated",numel(obj.ComponentNames),1) ;
            for column=2:size(obj.ComponentTable.Data,2)
                addCellStateStyles(obj.ComponentTable,column,calculated) ;
            end
            styleDofField(obj.TotalMolarFlowField,'calculated') ;
            styleDofField(obj.TotalConcentrationField,'calculated') ;
            if obj.HasMw,styleDofField(obj.TotalMassFlowField,'calculated');end
            styleDofField(obj.VolumetricFlowField,'calculated') ;
            styleDofField(obj.TemperatureField,'calculated') ;
            styleDofField(obj.PressureField,'calculated') ;
            if stream.status<0,obj.StatusLabel.Text='Not converged';elseif fromPreview,obj.StatusLabel.Text='Calculated before run';else,obj.StatusLabel.Text='Calculated';end
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
            origin="calculated";fOrigin=origin;cOrigin=origin;xOrigin=origin;mOrigin=origin;wOrigin=origin;tOrigin=origin;pOrigin=origin;qOrigin=origin;
            totalFOrigin=origin;totalCOrigin=origin;totalMOrigin=origin;
            if obj.Role=="Feed"
                fOrigin=compactOrigin(obj.Origins.F);cOrigin=compactOrigin(obj.Origins.C);xOrigin=compactOrigin(obj.Origins.x);
                mOrigin=compactOrigin(obj.Origins.mdot);wOrigin=compactOrigin(obj.Origins.w);tOrigin=obj.Origins.T;pOrigin=obj.Origins.P;qOrigin=obj.Origins.Q;
                totalFOrigin=obj.Origins.F_total;totalCOrigin=obj.Origins.C_tot;totalMOrigin=obj.Origins.mdot_total;
            end
            obj.DataModel=struct('MolarFlow',quantity(obj.componentColumn(2), ...
                obj.MolarFlowUnitDropDown.Value,fOrigin), ...
                'Concentration',quantity(obj.componentColumn(3), ...
                obj.ConcentrationUnitDropDown.Value,cOrigin), ...
                'MoleFraction',quantity(obj.componentColumn(4),'1',xOrigin), ...
                'TotalMolarFlow',quantity(obj.TotalMolarFlowField.Value,obj.TotalMolarFlowUnitDropDown.Value,totalFOrigin), ...
                'TotalConcentration',quantity(obj.TotalConcentrationField.Value,obj.TotalConcentrationUnitDropDown.Value,totalCOrigin), ...
                'T',quantity(obj.TemperatureField.Value,obj.TemperatureUnitDropDown.Value,tOrigin), ...
                'P',quantity(obj.PressureField.Value,obj.PressureUnitDropDown.Value,pOrigin), ...
                'Q',quantity(obj.VolumetricFlowField.Value,obj.VolumetricFlowUnitDropDown.Value,qOrigin), ...
                'Density',quantity(obj.DensityField.Value,obj.DensityUnitDropDown.Value,origin), ...
                'Viscosity',quantity(obj.ViscosityField.Value,obj.ViscosityUnitDropDown.Value,origin)) ;
            if obj.HasMw
                obj.DataModel.MassFlow=quantity(obj.componentColumn(5),obj.MassFlowUnitDropDown.Value,mOrigin);
                obj.DataModel.MassFraction=quantity(obj.componentColumn(6),'1',wOrigin);
                obj.DataModel.TotalMassFlow=quantity(obj.TotalMassFlowField.Value,obj.TotalMassFlowUnitDropDown.Value,totalMOrigin);
            end
            obj.DataModel.Result=obj.LastResult;
            if obj.Role~="Feed",obj.DataModel.Specifications=obj.buildConnectedSpecs();end
        end

        function valid=closeFeed(obj,highlight)
            if nargin<2,highlight=false;end
            valid=true;if obj.Role~="Feed"||obj.Updating,return,end
            obj.Updating=true;cleanup=onCleanup(@() obj.finishUpdate());
            try
                [model,values,origins]=obj.feedDofInput();result=nirp.dof.solve(model,values,origins);obj.LastResult=result;
                obj.writeFeedResult(result);obj.showFeedStates(result);obj.updatePortSources();
                if strcmp(result.status,'conflict'),message="Conflict: "+strjoin(result.messages,' ');
                elseif strcmp(result.status,'missing'),message=result.messages(end);if ~any(string({obj.Package.feeds.name})==string(get_param(obj.BlockPath,'Name'))),message="Feed data are not defined. "+message;end
                else,message="Fully specified";end
                nirp.flowsheet.internal.paintDofStatus(obj.StatusLabel,result.status,message);
                valid=strcmp(result.status,'complete');
            catch exception
                obj.StatusLabel.Text=exception.message;valid=false;
            end
            if highlight&&~valid,obj.StatusLabel.FontWeight='bold';end
            obj.captureModel();
        end

        function updatePortSources(obj)
            if obj.Role~="Feed",return,end
            inputT=strcmp(obj.TSourceDropDown.Value,'Input port');
            obj.TemperatureField.Visible=onOff(~inputT);obj.TemperatureField.Editable=onOff(~inputT);obj.TPortLabel.Visible=onOff(inputT);
            if inputT,obj.TPortLabel.Text=nirp.flowsheet.receivedValue(obj.BlockPath,'T','Temperature',obj.TemperatureUnitDropDown.Value,1);end
            inputQ=strcmp(obj.QSourceDropDown.Value,'Input port');
            editableQ=~inputQ;
            obj.VolumetricFlowField.Visible=onOff(~inputQ);obj.VolumetricFlowField.Editable=onOff(editableQ);obj.QPortLabel.Visible=onOff(inputQ);
            if inputQ,obj.QPortLabel.Text=nirp.flowsheet.receivedValue(obj.BlockPath,'Q','VolumetricFlow',obj.VolumetricFlowUnitDropDown.Value,1+inputT);end
        end

        function flag=feedComplete(obj)
            flag=~isempty(obj.LastResult)&&strcmp(obj.LastResult.status,'complete');
        end

        function componentEdited(obj,event)
            if obj.Updating||obj.Role~="Feed",return,end
            row=event.Indices(1);column=event.Indices(2);keys={'','F','C','x','mdot','w'};key=keys{column};
            value=event.NewData;catalogName=[key num2str(row)];
            if isempty(value)||(isnumeric(value)&&isscalar(value)&&isnan(value)),obj.Origins.(key)(row)="empty";obj.SpecifiedSI.(catalogName)=NaN;
            else
                obj.Origins.(key)(row)="specified";
                if strcmp(key,'F'),value=UnitConverterHelper.convertToSI('MolarFlow',value,obj.MolarFlowUnitDropDown.Value);
                elseif strcmp(key,'C'),value=UnitConverterHelper.convertToSI('Concentration',value,obj.ConcentrationUnitDropDown.Value);
                elseif strcmp(key,'mdot'),value=UnitConverterHelper.convertToSI('MassFlow',value,obj.MassFlowUnitDropDown.Value);end
                obj.SpecifiedSI.(catalogName)=value;
            end
            obj.closeFeed();
        end
        function scalarEdited(obj,name)
            if obj.Updating,return,end
            field=obj.scalarField(name);catalogName=name;category='';unit='1';
            switch name
                case 'F_total',catalogName='F';category='MolarFlow';unit=obj.TotalMolarFlowUnitDropDown.Value;
                case 'C_tot',category='Concentration';unit=obj.TotalConcentrationUnitDropDown.Value;
                case 'mdot_total',catalogName='mdot';category='MassFlow';unit=obj.TotalMassFlowUnitDropDown.Value;
                case 'Q',category='VolumetricFlow';unit=obj.VolumetricFlowUnitDropDown.Value;
                case 'T',category='Temperature';unit=obj.TemperatureUnitDropDown.Value;
                case 'P',category='Pressure';unit=obj.PressureUnitDropDown.Value;
            end
            if isempty(field.Value),obj.Origins.(name)="empty";obj.SpecifiedSI.(catalogName)=NaN;
            else,obj.Origins.(name)="specified";value=field.Value;if ~isempty(category),value=UnitConverterHelper.convertToSI(category,value,unit);end;obj.SpecifiedSI.(catalogName)=value;end
            obj.closeFeed();
        end
        function phaseEdited(obj),if obj.Updating,return,end;obj.closeFeed();end
        function markSpecified(obj,key)
            if any(strcmp(key,{'f','molarflow','molarflows'})),obj.Origins.F(:)="specified";
            elseif any(strcmp(key,{'c','concentration','concentrations'})),obj.Origins.C(:)="specified";
            elseif any(strcmp(key,{'x','molefraction','molefractions'})),obj.Origins.x(:)="specified";
            elseif any(strcmp(key,{'mdot','massflow','massflows'})),obj.Origins.mdot(:)="specified";
            elseif any(strcmp(key,{'w','massfraction','massfractions'})),obj.Origins.w(:)="specified";
            elseif any(strcmp(key,{'totalf','totalmolarflow'})),obj.Origins.F_total="specified";
            elseif any(strcmp(key,{'ctot','totalconcentration'})),obj.Origins.C_tot="specified";
            elseif any(strcmp(key,{'totalmass','totalmassflow'})),obj.Origins.mdot_total="specified";
            elseif strcmp(key,'t')||strcmp(key,'temperature'),obj.Origins.T="specified";
            elseif strcmp(key,'p')||strcmp(key,'pressure'),obj.Origins.P="specified";
            elseif strcmp(key,'q')||strcmp(key,'volumetricflow'),obj.Origins.Q="specified";end
        end
        function rememberSetValue(obj,key,value)
            if any(strcmp(key,{'f','molarflow','molarflows'})),prefix='F';value=UnitConverterHelper.convertToSI('MolarFlow',value,obj.MolarFlowUnitDropDown.Value);
            elseif any(strcmp(key,{'c','concentration','concentrations'})),prefix='C';value=UnitConverterHelper.convertToSI('Concentration',value,obj.ConcentrationUnitDropDown.Value);
            elseif any(strcmp(key,{'x','molefraction','molefractions'})),prefix='x';
            elseif any(strcmp(key,{'mdot','massflow','massflows'})),prefix='mdot';value=UnitConverterHelper.convertToSI('MassFlow',value,obj.MassFlowUnitDropDown.Value);
            elseif any(strcmp(key,{'w','massfraction','massfractions'})),prefix='w';
            elseif any(strcmp(key,{'totalf','totalmolarflow','ctot','totalconcentration', ...
                    'totalmass','totalmassflow','t','temperature','p','pressure', ...
                    'q','volumetricflow'}))
                switch key
                    case {'totalf','totalmolarflow'},name='F';category='MolarFlow';unit=obj.TotalMolarFlowUnitDropDown.Value;
                    case {'ctot','totalconcentration'},name='C_tot';category='Concentration';unit=obj.TotalConcentrationUnitDropDown.Value;
                    case {'totalmass','totalmassflow'},name='mdot';category='MassFlow';unit=obj.TotalMassFlowUnitDropDown.Value;
                    case {'t','temperature'},name='T';category='Temperature';unit=obj.TemperatureUnitDropDown.Value;
                    case {'p','pressure'},name='P';category='Pressure';unit=obj.PressureUnitDropDown.Value;
                    otherwise,name='Q';category='VolumetricFlow';unit=obj.VolumetricFlowUnitDropDown.Value;
                end
                if isempty(value)||(isnumeric(value)&&isscalar(value)&&isnan(value))
                    obj.SpecifiedSI.(name)=NaN;
                else
                    obj.SpecifiedSI.(name)=UnitConverterHelper.convertToSI(category,value,unit);
                end
                return
            else
                return
            end
            for i=1:numel(value),obj.SpecifiedSI.([prefix num2str(i)])=value(i);end
        end
        function [model,values,origins]=feedDofInput(obj)
            context=struct('nComponents',numel(obj.ComponentNames),'phase',obj.PhaseDropDown.Value,'components',obj.Package.components);
            model=nirp.dof.catalog.feed(context);values=struct();origins=struct();n=numel(obj.ComponentNames);
            f=UnitConverterHelper.convertToSI('MolarFlow',obj.componentColumn(2),obj.MolarFlowUnitDropDown.Value);
            c=UnitConverterHelper.convertToSI('Concentration',obj.componentColumn(3),obj.ConcentrationUnitDropDown.Value);
            x=obj.componentColumn(4);
            for i=1:n
                keys={['F' num2str(i)],['C' num2str(i)],['x' num2str(i)]};ors={obj.Origins.F(i),obj.Origins.C(i),obj.Origins.x(i)};vals={specifiedValue(f(i),ors{1}),specifiedValue(c(i),ors{2}),specifiedValue(x(i),ors{3})};
                for k=1:3,values.(keys{k})=vals{k};origins.(keys{k})=char(ors{k});end
            end
            if obj.HasMw
                m=UnitConverterHelper.convertToSI('MassFlow',obj.componentColumn(5),obj.MassFlowUnitDropDown.Value);w=obj.componentColumn(6);
                for i=1:n,values.(['mdot' num2str(i)])=specifiedValue(m(i),obj.Origins.mdot(i));origins.(['mdot' num2str(i)])=char(obj.Origins.mdot(i));values.(['w' num2str(i)])=specifiedValue(w(i),obj.Origins.w(i));origins.(['w' num2str(i)])=char(obj.Origins.w(i));end
            end
            values.F=toSIField(obj.TotalMolarFlowField,obj.TotalMolarFlowUnitDropDown,'MolarFlow');origins.F=char(obj.Origins.F_total);
            values.C_tot=toSIField(obj.TotalConcentrationField,obj.TotalConcentrationUnitDropDown,'Concentration');origins.C_tot=char(obj.Origins.C_tot);
            if obj.HasMw,values.mdot=toSIField(obj.TotalMassFlowField,obj.TotalMassFlowUnitDropDown,'MassFlow');origins.mdot=char(obj.Origins.mdot_total);end
            values.Q=toSIField(obj.VolumetricFlowField,obj.VolumetricFlowUnitDropDown,'VolumetricFlow');origins.Q=char(obj.Origins.Q);
            values.T=toSIField(obj.TemperatureField,obj.TemperatureUnitDropDown,'Temperature');origins.T=char(obj.Origins.T);
            values.P=toSIField(obj.PressureField,obj.PressureUnitDropDown,'Pressure');origins.P=char(obj.Origins.P);
            scalarNames={'F','C_tot','Q','T','P'};originNames={'F_total','C_tot','Q','T','P'};if obj.HasMw,scalarNames=[scalarNames {'mdot'}];originNames=[originNames {'mdot_total'}];end
            for i=1:numel(scalarNames),values.(scalarNames{i})=specifiedValue(values.(scalarNames{i}),obj.Origins.(originNames{i}));end
            if strcmp(obj.TSourceDropDown.Value,'Input port'),values.T=toSIField(obj.TemperatureField,obj.TemperatureUnitDropDown,'Temperature');origins.T='external';end
            if strcmp(obj.QSourceDropDown.Value,'Input port'),values.Q=toSIField(obj.VolumetricFlowField,obj.VolumetricFlowUnitDropDown,'VolumetricFlow');origins.Q='external';end
            names=fieldnames(values);for i=1:numel(names),name=names{i};if string(origins.(name))=="specified"&&isfield(obj.SpecifiedSI,name)&&isfinite(obj.SpecifiedSI.(name)),values.(name)=obj.SpecifiedSI.(name);end,end
        end
        function writeFeedResult(obj,result)
            n=numel(obj.ComponentNames);f=nan(n,1);c=f;x=f;
            for i=1:n
                f(i)=result.values.(['F' num2str(i)]);c(i)=result.values.(['C' num2str(i)]);x(i)=result.values.(['x' num2str(i)]);
                obj.Origins.F(i)=string(result.origins.(['F' num2str(i)]));obj.Origins.C(i)=string(result.origins.(['C' num2str(i)]));obj.Origins.x(i)=string(result.origins.(['x' num2str(i)]));
            end
            obj.setComponentColumn(2,UnitConverterHelper.convertFromSI('MolarFlow',f,obj.MolarFlowUnitDropDown.Value));
            obj.setComponentColumn(3,UnitConverterHelper.convertFromSI('Concentration',c,obj.ConcentrationUnitDropDown.Value));obj.setComponentColumn(4,x);
            if obj.HasMw
                m=nan(n,1);w=m;for i=1:n,m(i)=result.values.(['mdot' num2str(i)]);w(i)=result.values.(['w' num2str(i)]);obj.Origins.mdot(i)=string(result.origins.(['mdot' num2str(i)]));obj.Origins.w(i)=string(result.origins.(['w' num2str(i)]));end
                obj.setComponentColumn(5,UnitConverterHelper.convertFromSI('MassFlow',m,obj.MassFlowUnitDropDown.Value));obj.setComponentColumn(6,w);
            end
            setFromSI(obj.TotalMolarFlowField,obj.TotalMolarFlowUnitDropDown,'MolarFlow',result.values.F);obj.Origins.F_total=string(result.origins.F);
            setFromSI(obj.TotalConcentrationField,obj.TotalConcentrationUnitDropDown,'Concentration',result.values.C_tot);obj.Origins.C_tot=string(result.origins.C_tot);
            if obj.HasMw,setFromSI(obj.TotalMassFlowField,obj.TotalMassFlowUnitDropDown,'MassFlow',result.values.mdot);obj.Origins.mdot_total=string(result.origins.mdot);end
            setFromSI(obj.VolumetricFlowField,obj.VolumetricFlowUnitDropDown,'VolumetricFlow',result.values.Q);obj.Origins.Q=string(result.origins.Q);
            setFromSI(obj.TemperatureField,obj.TemperatureUnitDropDown,'Temperature',result.values.T);obj.Origins.T=string(result.origins.T);
            setFromSI(obj.PressureField,obj.PressureUnitDropDown,'Pressure',result.values.P);obj.Origins.P=string(result.origins.P);
        end
        function showFeedStates(obj,result)
            removeStyle(obj.ComponentTable);n=numel(obj.ComponentNames);columns={'F','C','x','mdot','w'};
            for column=1:(3+2*obj.HasMw)
                states=strings(n,1);for i=1:n,states(i)=string(result.states.([columns{column} num2str(i)]));end
                addCellStateStyles(obj.ComponentTable,column+1,states);
            end
            styleDofField(obj.TotalMolarFlowField,result.states.F);styleDofField(obj.TotalConcentrationField,result.states.C_tot);
            if obj.HasMw,styleDofField(obj.TotalMassFlowField,result.states.mdot);end
            styleDofField(obj.VolumetricFlowField,result.states.Q);styleDofField(obj.TemperatureField,result.states.T);styleDofField(obj.PressureField,result.states.P);
        end
        function field=scalarField(obj,name)
            switch name
                case 'F_total',field=obj.TotalMolarFlowField;case 'C_tot',field=obj.TotalConcentrationField;case 'mdot_total',field=obj.TotalMassFlowField;
                case 'T',field=obj.TemperatureField;case 'P',field=obj.PressureField;otherwise,field=obj.VolumetricFlowField;
            end
        end
        function specs=buildFeedSpecs(obj)
            specs=struct();names=fieldnames(obj.LastResult.origins);
            for i=1:numel(names)
                name=names{i};if string(obj.LastResult.origins.(name))~="specified",continue,end
                unit='1';
                if ~isempty(regexp(name,'^F\d+$','once')),unit=obj.MolarFlowUnitDropDown.Value;
                elseif ~isempty(regexp(name,'^C\d+$','once')),unit=obj.ConcentrationUnitDropDown.Value;
                elseif ~isempty(regexp(name,'^mdot\d+$','once')),unit=obj.MassFlowUnitDropDown.Value;
                elseif strcmp(name,'F'),unit=obj.TotalMolarFlowUnitDropDown.Value;
                elseif strcmp(name,'C_tot'),unit=obj.TotalConcentrationUnitDropDown.Value;
                elseif strcmp(name,'mdot'),unit=obj.TotalMassFlowUnitDropDown.Value;
                elseif strcmp(name,'Q'),unit=obj.VolumetricFlowUnitDropDown.Value;
                elseif strcmp(name,'T'),unit=obj.TemperatureUnitDropDown.Value;
                elseif strcmp(name,'P'),unit=obj.PressureUnitDropDown.Value;end
                specs.(name)=struct('si',obj.LastResult.values.(name),'unit',char(unit));
            end
        end
        function loadSpecification(obj,key,item)
            unit=char(string(item.unit));value=item.si;
            obj.SpecifiedSI.(key)=value;
            token=regexp(key,'^(F|C|x|mdot|w)(\d+)$','tokens','once');
            if ~isempty(token)
                row=str2double(token{2});prefix=token{1};map=struct('F',2,'C',3,'x',4,'mdot',5,'w',6);column=map.(prefix);
                if row>numel(obj.ComponentNames)||column>size(obj.ComponentTable.Data,2),return,end
                if strcmp(prefix,'F'),setUnitIfValid(obj.MolarFlowUnitDropDown,unit);value=UnitConverterHelper.convertFromSI('MolarFlow',value,obj.MolarFlowUnitDropDown.Value);
                elseif strcmp(prefix,'C'),setUnitIfValid(obj.ConcentrationUnitDropDown,unit);value=UnitConverterHelper.convertFromSI('Concentration',value,obj.ConcentrationUnitDropDown.Value);
                elseif strcmp(prefix,'mdot'),setUnitIfValid(obj.MassFlowUnitDropDown,unit);value=UnitConverterHelper.convertFromSI('MassFlow',value,obj.MassFlowUnitDropDown.Value);end
                d=obj.ComponentTable.Data;d{row,column}=value;obj.ComponentTable.Data=d;obj.Origins.(prefix)(row)="specified";return
            end
            switch key
                case 'F',setUnitIfValid(obj.TotalMolarFlowUnitDropDown,unit);obj.TotalMolarFlowField.Value=UnitConverterHelper.convertFromSI('MolarFlow',value,obj.TotalMolarFlowUnitDropDown.Value);obj.Origins.F_total="specified";
                case 'C_tot',setUnitIfValid(obj.TotalConcentrationUnitDropDown,unit);obj.TotalConcentrationField.Value=UnitConverterHelper.convertFromSI('Concentration',value,obj.TotalConcentrationUnitDropDown.Value);obj.Origins.C_tot="specified";
                case 'mdot',setUnitIfValid(obj.TotalMassFlowUnitDropDown,unit);obj.TotalMassFlowField.Value=UnitConverterHelper.convertFromSI('MassFlow',value,obj.TotalMassFlowUnitDropDown.Value);obj.Origins.mdot_total="specified";
                case 'Q',setUnitIfValid(obj.VolumetricFlowUnitDropDown,unit);obj.VolumetricFlowField.Value=UnitConverterHelper.convertFromSI('VolumetricFlow',value,obj.VolumetricFlowUnitDropDown.Value);obj.Origins.Q="specified";
                case 'T',setUnitIfValid(obj.TemperatureUnitDropDown,unit);obj.TemperatureField.Value=UnitConverterHelper.convertFromSI('Temperature',value,obj.TemperatureUnitDropDown.Value);obj.Origins.T="specified";
                case 'P',setUnitIfValid(obj.PressureUnitDropDown,unit);obj.PressureField.Value=UnitConverterHelper.convertFromSI('Pressure',value,obj.PressureUnitDropDown.Value);obj.Origins.P="specified";
            end
        end
        function unitEdited(obj,category,source,event,target)
            if obj.Updating,return,end
            obj.convertDisplayed(category,source,event.Value,target,event.PreviousValue);obj.closeFeed();
        end
        function convertDisplayed(obj,category,dropdown,newUnit,target,oldUnit)
            if nargin<6,oldUnit=dropdown.Value;end
            if strcmp(oldUnit,newUnit),dropdown.Value=newUnit;return,end
            if isnumeric(target),value=obj.componentColumn(target);else,value=target.Value;end
            si=UnitConverterHelper.convertToSI(category,value,char(string(oldUnit)));
            converted=UnitConverterHelper.convertFromSI(category,si,newUnit);dropdown.Value=newUnit;
            if isnumeric(target),obj.setComponentColumn(target,converted);else,target.Value=converted;end
        end
        function finishUpdate(obj),obj.Updating=false;end

        function setComponentColumn(obj,column,value)
            value=value(:);if numel(value)~=numel(obj.ComponentNames)
                error('nirp:flowsheet:invalidComposition','Expected %d component values.',numel(obj.ComponentNames));end
            data=obj.ComponentTable.Data;for i=1:numel(value),data{i,column}=nirp.flowsheet.internal.formatTableNumber(value(i));end;obj.ComponentTable.Data=data;
        end
        function value=componentColumn(obj,column)
            data=obj.ComponentTable.Data;value=nan(size(data,1),1);
            for i=1:size(data,1),item=data{i,column};if ischar(item)||isstring(item),item=str2double(item);end;if isnumeric(item)&&isscalar(item),value(i)=item;end,end
        end
    end
end

function [field,units,text]=quantityRow(grid,row,label,category)
    text=uilabel(grid,'Text',label,'HorizontalAlignment','right');text.Layout.Row=row;text.Layout.Column=4;
    holder=uigridlayout(grid,[1 2],'ColumnWidth',{'1x',85},'Padding',[0 0 0 0]);holder.Layout.Row=row;holder.Layout.Column=5;
    field=uieditfield(holder,'numeric','AllowEmpty','on','Value',[]);units=uidropdown(holder,'Items',UnitConverterHelper.getUnits(category));
end
function label=portLabel(holder)
    label=uilabel(holder,'Text','Input port','FontAngle','italic', ...
        'HorizontalAlignment','center','Visible','off');
    label.Layout.Row=1;label.Layout.Column=1;
end
function [control,label]=rowControl(grid,row,text,items,type)
    label=uilabel(grid,'Text',text,'HorizontalAlignment','right');label.Layout.Row=row;label.Layout.Column=4;
    if strcmp(type,'dropdown'),control=uidropdown(grid,'Items',items);end;control.Layout.Row=row;control.Layout.Column=5;
end
function result=onOff(value),if value,result='on';else,result='off';end,end
function q=quantity(value,unit,origin),q=struct('value',value,'unit',char(unit),'origin',char(string(origin)));end
function values=requireComplete(values,label)
    if any(~isfinite(values)),error('nirp:flowsheet:missingComposition','Enter %s for every component.',label);end
end
function unit=normalizeTemperature(unit),unit=char(string(unit));if strcmp(unit,'C'),unit=[char(176) 'C'];end,end
function origin=compactOrigin(values),values=string(values);if all(values==values(1)),origin=values(1);else,origin=values;end,end
function value=toSIField(field,units,category),if isempty(field.Value),value=NaN;else,value=UnitConverterHelper.convertToSI(category,field.Value,units.Value);end,end
function value=specifiedValue(value,origin),if string(origin)~="specified",value=NaN;end,end
function setFromSI(field,units,category,value),if isnumeric(value)&&isscalar(value)&&isfinite(value),field.Value=UnitConverterHelper.convertFromSI(category,value,units.Value);else,field.Value=[];end,end
function setUnitIfValid(dropdown,unit),if isempty(unit),return,end;if any(string(dropdown.Items)==string(unit)),dropdown.Value=unit;end,end
function value=emptyValue(value),if isempty(value)||(isnumeric(value)&&isscalar(value)&&isnan(value)),value=[];end,end
function flag=isFiniteScalar(value),flag=isnumeric(value)&&isscalar(value)&&isfinite(value);end
function value=stripWaiting(value),value=char(string(value));value=regexprep(value,'^Waiting for:\s*','');end
function values=setAt(values,index,value),if index>=1&&index<=numel(values),values(index)=string(value);end,end
function addCellStateStyles(tableHandle,column,states)
    definitions={"specified",[0.15 0.25 0.55],'normal';"calculated",[0.92 0.92 0.92],'italic';"empty",[1 0.90 0.90],'normal';"external",[0.88 0.88 0.88],'normal';"conflict",[1 0.72 0.72],'normal'};
    for i=1:size(definitions,1),rows=find(states==definitions{i,1});if isempty(rows),continue,end;style=uistyle('FontAngle',definitions{i,3});if definitions{i,1}=="specified",style.FontColor=definitions{i,2};else,style.BackgroundColor=definitions{i,2};end;addStyle(tableHandle,style,'cell',[rows repmat(column,numel(rows),1)]);end
end
function styleDofField(field,state)
    field.BackgroundColor=[1 1 1];field.FontColor=[0 0 0];field.FontAngle='normal';
    switch char(string(state))
        case 'specified',field.FontColor=[0.15 0.25 0.55];
        case 'calculated',field.BackgroundColor=[0.92 0.92 0.92];field.FontAngle='italic';
        case 'empty',field.BackgroundColor=[1 0.90 0.90];
        case 'external',field.BackgroundColor=[0.88 0.88 0.88];
        case 'conflict',field.BackgroundColor=[1 0.72 0.72];
    end
end
