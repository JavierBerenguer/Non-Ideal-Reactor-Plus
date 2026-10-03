classdef StreamDialog < handle
    % StreamDialog edits feeds and displays calculated stream results.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 3, 2026
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
        OKButton
        ApplyButton
        CancelButton
        DataModel
    end

    properties (Access = private)
        Package
        DictionaryPath
        ComponentNames
        Origins
        Updating = false
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
            key=lower(char(string(name))) ;
            switch key
                case {'f','molarflow','molarflows'}
                    obj.setComponentColumn(2,value) ;
                case {'c','concentration','concentrations'}
                    obj.setComponentColumn(3,value) ;
                case {'t','temperature'}, obj.TemperatureField.Value = value ;
                case {'p','pressure'}, obj.PressureField.Value = value ;
                case {'q','volumetricflow'}
                    if isnumeric(value)&&isscalar(value)&&isnan(value),obj.Origins.Q="calculated";
                    else,obj.VolumetricFlowField.Value = value;end
                case 'density', obj.DensityField.Value = value ;
                case 'viscosity', obj.ViscosityField.Value = value ;
                case 'phase', obj.PhaseDropDown.Value = char(string(value)) ;
                case 'referencefeed', obj.ReferenceFeedDropDown.Value = char(string(value)) ;
                case 'keycomponent', obj.KeyComponentDropDown.Value = char(string(value)) ;
                otherwise
                    error('nirp:flowsheet:unknownMagnitude','Unknown stream magnitude "%s".',name) ;
            end
            if ~(any(strcmp(key,{'q','volumetricflow'}))&&isnumeric(value)&&isscalar(value)&&isnan(value)),obj.markSpecified(key);end
            obj.closeFeed() ; obj.captureModel() ;
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
            if obj.Role ~= "Feed", obj.loadCalculatedResult() ;
            else, obj.closeFeed() ; end
            obj.captureModel() ;
        end

        function setUnit(obj,name,unit)
            unit = char(string(unit)) ;
            switch lower(char(string(name)))
                case {'f','molarflow'}, obj.convertDisplayed('MolarFlow',obj.MolarFlowUnitDropDown,unit,2) ;
                case {'c','concentration'}, obj.convertDisplayed('Concentration',obj.ConcentrationUnitDropDown,unit,3) ;
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

        function applied = apply(obj)
            applied=false ;
            if obj.Role ~= "Feed", return, end
            try
                if ~obj.closeFeed(true), return, end
                obj.saveFeed() ; applied=true ;
            catch exception
                obj.StatusLabel.Text=exception.message ;
            end
        end

        function accept(obj)
            if obj.apply(), delete(obj) ; end
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
            flows = obj.componentColumn(2) ; concentrations = obj.componentColumn(3) ;
            hasFlows = all(isfinite(flows)) ; hasConcentrations = all(isfinite(concentrations)) ;
            if hasFlows && obj.Origins.MolarFlow ~= "calculated"
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
            if obj.PhaseDropDown.Value=='G', q = [] ;
            elseif ~isfinite(qValue) || qValue <= 0, q = [] ;
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
            if obj.Role == "Feed"
                tipsText = {'TIPS'; ...
                    'Two of molar flow, concentration, and liquid Q complete the third.'; ...
                    'Gas Q is calculated from flow, T, and P.'} ;
            else
                tipsText = {'TIPS'; ...
                    'Results of the last run. Choose the display units below;'; ...
                    'conversion is relative to the selected feed and key component.'} ;
            end
            tips = uitextarea(grid,'Editable','off','Value',tipsText) ;
            tips.Layout.Row=2; tips.Layout.Column=[1 2] ;
            nameLabel = uilabel(grid,'Text','Name','HorizontalAlignment','right', ...
                'FontWeight','bold') ; nameLabel.Layout.Row=2; nameLabel.Layout.Column=4 ;
            obj.NameField=uieditfield(grid,'text','Value',get_param(obj.BlockPath,'Name'), ...
                'Editable','off') ; obj.NameField.Layout.Row=2;obj.NameField.Layout.Column=5 ;
            obj.ComponentTable = uitable(grid,'ColumnName', ...
                {'Component','Molar Flow','Concentration'},'RowName',{}, ...
                'ColumnEditable',[false obj.Role=="Feed" obj.Role=="Feed"], ...
                'CellEditCallback',@(~,event) obj.componentEdited(event)) ;
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
            obj.DensityField.AllowEmpty='on';obj.DensityField.Value=[];
            obj.ViscosityField.AllowEmpty='on';obj.ViscosityField.Value=[];
            obj.MolarFlowUnitDropDown = uidropdown(obj.Figure,'Items', ...
                UnitConverterHelper.getUnits('MolarFlow'),'Position',[35 18 130 22], ...
                'ValueChangedFcn',@(source,event) obj.unitEdited('MolarFlow',source,event,2)) ;
            obj.ConcentrationUnitDropDown = uidropdown(obj.Figure,'Items', ...
                UnitConverterHelper.getUnits('Concentration'),'Position',[185 18 145 22], ...
                'ValueChangedFcn',@(source,event) obj.unitEdited('Concentration',source,event,3)) ;
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
            if obj.Role=="Feed"
                obj.OKButton=uibutton(obj.Figure,'Text','OK','Position',[465 18 90 30], ...
                    'ButtonPushedFcn',@(~,~) obj.accept()) ;
                obj.CancelButton=uibutton(obj.Figure,'Text','Cancel','Position',[565 18 90 30], ...
                    'ButtonPushedFcn',@(~,~) obj.cancel()) ;
                obj.ApplyButton=uibutton(obj.Figure,'Text','Apply','Position',[665 18 90 30], ...
                    'ButtonPushedFcn',@(~,~) obj.apply()) ;
                obj.SaveButton=obj.ApplyButton ;
            else
                obj.CancelButton=uibutton(obj.Figure,'Text','Close','Position',[665 18 90 30], ...
                    'ButtonPushedFcn',@(~,~) obj.cancel()) ;
                obj.SaveButton=obj.CancelButton ;
            end
            editable = onOff(obj.Role=="Feed") ;
            obj.PhaseDropDown.Enable=editable; obj.PressureField.Editable=editable;
            obj.TemperatureField.Editable=editable;obj.VolumetricFlowField.Editable=editable;
            obj.DensityField.Editable='off';obj.ViscosityField.Editable='off';
            obj.PhaseDropDown.ValueChangedFcn=@(~,~) obj.phaseEdited() ;
            obj.TemperatureField.ValueChangedFcn=@(~,~) obj.scalarEdited('T') ;
            obj.PressureField.ValueChangedFcn=@(~,~) obj.scalarEdited('P') ;
            obj.VolumetricFlowField.ValueChangedFcn=@(~,~) obj.scalarEdited('Q') ;
            obj.TemperatureUnitDropDown.ValueChangedFcn=@(source,event) obj.unitEdited('Temperature',source,event,obj.TemperatureField) ;
            obj.PressureUnitDropDown.ValueChangedFcn=@(source,event) obj.unitEdited('Pressure',source,event,obj.PressureField) ;
            obj.VolumetricFlowUnitDropDown.ValueChangedFcn=@(source,event) obj.unitEdited('VolumetricFlow',source,event,obj.VolumetricFlowField) ;
        end

        function loadData(obj)
            obj.Origins=struct('MolarFlow',"calculated",'Concentration',"calculated", ...
                'T',"specified",'P',"specified",'Q',"specified") ;
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
            if obj.Role == "Feed", obj.loadFeed() ; obj.closeFeed() ; else, obj.loadCalculatedResult() ; end
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
                obj.Origins.MolarFlow="specified" ;
            elseif strcmpi(feed.basis,'concentrations')
                obj.ConcentrationUnitDropDown.Value=char(feed.valuesUnit) ;
                obj.setComponentColumn(3,feed.values) ;
                obj.Origins.Concentration="specified" ;
            end
            if isempty(feed.Q),obj.Origins.Q="calculated";end
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
            origin="calculated";if obj.Role=="Feed",origin="specified";end
            fOrigin=origin;cOrigin=origin;tOrigin=origin;pOrigin=origin;qOrigin=origin;
            if obj.Role=="Feed",fOrigin=obj.Origins.MolarFlow;cOrigin=obj.Origins.Concentration;tOrigin=obj.Origins.T;pOrigin=obj.Origins.P;qOrigin=obj.Origins.Q;end
            obj.DataModel=struct('MolarFlow',quantity(obj.componentColumn(2), ...
                obj.MolarFlowUnitDropDown.Value,fOrigin), ...
                'Concentration',quantity(obj.componentColumn(3), ...
                obj.ConcentrationUnitDropDown.Value,cOrigin), ...
                'T',quantity(obj.TemperatureField.Value,obj.TemperatureUnitDropDown.Value,tOrigin), ...
                'P',quantity(obj.PressureField.Value,obj.PressureUnitDropDown.Value,pOrigin), ...
                'Q',quantity(obj.VolumetricFlowField.Value,obj.VolumetricFlowUnitDropDown.Value,qOrigin), ...
                'Density',quantity(obj.DensityField.Value,obj.DensityUnitDropDown.Value,origin), ...
                'Viscosity',quantity(obj.ViscosityField.Value,obj.ViscosityUnitDropDown.Value,origin)) ;
        end

        function valid=closeFeed(obj,highlight)
            if nargin<2,highlight=false;end
            valid=true;if obj.Role~="Feed"||obj.Updating,return,end
            obj.Updating=true;cleanup=onCleanup(@() obj.finishUpdate());
            obj.resetStyles();
            flows=obj.componentColumn(2);concentrations=obj.componentColumn(3);
            q=obj.VolumetricFlowField.Value;
            if obj.Origins.MolarFlow=="calculated",flows(:)=NaN;end
            if obj.Origins.Concentration=="calculated",concentrations(:)=NaN;end
            if obj.Origins.Q=="calculated",q=NaN;end
            message="";
            try
                fSI=UnitConverterHelper.convertToSI('MolarFlow',flows,obj.MolarFlowUnitDropDown.Value);
                cSI=UnitConverterHelper.convertToSI('Concentration',concentrations,obj.ConcentrationUnitDropDown.Value);
                qSI=UnitConverterHelper.convertToSI('VolumetricFlow',q,obj.VolumetricFlowUnitDropDown.Value);
                tSI=UnitConverterHelper.convertToSI('Temperature',obj.TemperatureField.Value,obj.TemperatureUnitDropDown.Value);
                pSI=UnitConverterHelper.convertToSI('Pressure',obj.PressureField.Value,obj.PressureUnitDropDown.Value);
                if any(fSI(isfinite(fSI))<0)||any(cSI(isfinite(cSI))<0)|| ...
                        (isfinite(qSI)&&qSI<=0)
                    message="Flows, concentrations, and volumetric flow must be nonnegative (Q positive).";
                elseif obj.PhaseDropDown.Value=='G'
                    obj.VolumetricFlowField.Editable='off';
                    if all(isfinite(fSI))&&isfinite(tSI)&&tSI>0&&isfinite(pSI)&&pSI>0
                        qSI=sum(fSI)*8.314*tSI/pSI;
                        obj.VolumetricFlowField.Value=UnitConverterHelper.convertFromSI('VolumetricFlow',qSI,obj.VolumetricFlowUnitDropDown.Value);
                        obj.Origins.Q="calculated";
                    else
                        obj.Origins.Q="calculated";
                    end
                else
                    obj.VolumetricFlowField.Editable='on';
                    hasF=all(isfinite(fSI));hasC=all(isfinite(cSI));hasQ=isfinite(qSI)&&qSI>0;
                    if hasF&&hasC&&hasQ
                        residual=fSI-cSI*qSI;
                        if any(abs(residual)>1e-9*max(1,max(abs([fSI;cSI*qSI]))))
                            message="Molar flows, concentrations, and volumetric flow are inconsistent.";
                        end
                    elseif hasF&&hasQ
                        cSI=fSI/qSI;obj.setComponentColumn(3,UnitConverterHelper.convertFromSI('Concentration',cSI,obj.ConcentrationUnitDropDown.Value));obj.Origins.Concentration="calculated";
                    elseif hasC&&hasQ
                        fSI=cSI*qSI;obj.setComponentColumn(2,UnitConverterHelper.convertFromSI('MolarFlow',fSI,obj.MolarFlowUnitDropDown.Value));obj.Origins.MolarFlow="calculated";
                    elseif hasF&&hasC
                        positive=cSI>1e-15;
                        if any(~positive&abs(fSI)>1e-12)
                            message="Molar flows and concentrations are inconsistent.";
                        elseif any(positive)
                            candidates=fSI(positive)./cSI(positive);
                            candidate=mean(candidates);
                            if candidate<=0||any(abs(candidates-candidate)>1e-9*max(1,abs(candidate)))
                                message="Component flows and concentrations imply inconsistent volumetric flows.";
                            else
                                obj.VolumetricFlowField.Value=UnitConverterHelper.convertFromSI('VolumetricFlow',candidate,obj.VolumetricFlowUnitDropDown.Value);obj.Origins.Q="calculated";
                            end
                        end
                    end
                end
            catch exception
                message=string(exception.message);
            end
            if strlength(message)>0,obj.StatusLabel.Text=char(message);valid=false;
            elseif highlight
                valid=obj.feedComplete();if valid,obj.StatusLabel.Text='Ready to apply.';else,obj.StatusLabel.Text='';obj.highlightMissing();end
            end
            obj.showOrigins();obj.captureModel();
        end

        function flag=feedComplete(obj)
            f=all(isfinite(obj.componentColumn(2)));c=all(isfinite(obj.componentColumn(3)));
            flag=(f||c)&&isfinite(obj.TemperatureField.Value)&&obj.TemperatureField.Value>0&& ...
                isfinite(obj.PressureField.Value)&&obj.PressureField.Value>0;
            if obj.PhaseDropDown.Value=='L',flag=flag&&isfinite(obj.VolumetricFlowField.Value)&&obj.VolumetricFlowField.Value>0;end
        end

        function componentEdited(obj,event)
            if obj.Updating||obj.Role~="Feed",return,end
            if event.Indices(2)==2,obj.Origins.MolarFlow="specified";else,obj.Origins.Concentration="specified";end
            obj.closeFeed();
        end
        function scalarEdited(obj,name),if obj.Updating,return,end;obj.Origins.(name)="specified";obj.closeFeed();end
        function phaseEdited(obj),if ~obj.Updating,obj.closeFeed();end,end
        function markSpecified(obj,key)
            if any(strcmp(key,{'f','molarflow','molarflows'})),obj.Origins.MolarFlow="specified";
            elseif any(strcmp(key,{'c','concentration','concentrations'})),obj.Origins.Concentration="specified";
            elseif strcmp(key,'t')||strcmp(key,'temperature'),obj.Origins.T="specified";
            elseif strcmp(key,'p')||strcmp(key,'pressure'),obj.Origins.P="specified";
            elseif strcmp(key,'q')||strcmp(key,'volumetricflow'),obj.Origins.Q="specified";end
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
        function showOrigins(obj)
            removeStyle(obj.ComponentTable);
            style=uistyle('FontAngle','italic','BackgroundColor',[0.92 0.92 0.92]);
            if obj.Origins.MolarFlow=="calculated",addStyle(obj.ComponentTable,style,'column',2);end
            if obj.Origins.Concentration=="calculated",addStyle(obj.ComponentTable,style,'column',3);end
            if obj.Origins.Q=="calculated",obj.VolumetricFlowField.BackgroundColor=[0.92 0.92 0.92];end
        end
        function resetStyles(obj),removeStyle(obj.ComponentTable);obj.VolumetricFlowField.BackgroundColor=[1 1 1];obj.TemperatureField.BackgroundColor=[1 1 1];obj.PressureField.BackgroundColor=[1 1 1];end
        function highlightMissing(obj)
            style=uistyle('BackgroundColor',[1 0.86 0.86]);f=obj.componentColumn(2);c=obj.componentColumn(3);
            if ~all(isfinite(f))&&~all(isfinite(c)),rows=find(~isfinite(f));if ~isempty(rows),addStyle(obj.ComponentTable,style,'cell',[rows repmat(2,numel(rows),1)]);end;rows=find(~isfinite(c));if ~isempty(rows),addStyle(obj.ComponentTable,style,'cell',[rows repmat(3,numel(rows),1)]);end,end
            if ~isfinite(obj.TemperatureField.Value)||obj.TemperatureField.Value<=0,obj.TemperatureField.BackgroundColor=[1 0.86 0.86];end
            if ~isfinite(obj.PressureField.Value)||obj.PressureField.Value<=0,obj.PressureField.BackgroundColor=[1 0.86 0.86];end
            if obj.PhaseDropDown.Value=='L'&&(~isfinite(obj.VolumetricFlowField.Value)||obj.VolumetricFlowField.Value<=0),obj.VolumetricFlowField.BackgroundColor=[1 0.86 0.86];end
        end
        function finishUpdate(obj),obj.Updating=false;end

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
function q=quantity(value,unit,origin),q=struct('value',value,'unit',char(unit),'origin',char(string(origin)));end
function values=requireComplete(values,label)
    if any(~isfinite(values)),error('nirp:flowsheet:missingComposition','Enter %s for every component.',label);end
end
function unit=normalizeTemperature(unit),unit=char(string(unit));if strcmp(unit,'C'),unit=[char(176) 'C'];end,end
