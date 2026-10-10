classdef ReactiveSystemDialog < handle
%REACTIVESYSTEMDIALOG Graphical editor for components and reactions.
%   ED = nirp.flowsheet.ReactiveSystemDialog('Visible','off') creates an editor
%   that can also be driven by scripts through its public tables.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 10, 2026
% =========================================================================

    properties (SetAccess = private)
        Figure
        ComponentTable
        ReactionTable
        FeedTable
        ConcentrationUnitDropDown
        TimeUnitDropDown
        TrefField
        TrefUnitDropDown
        StatusLabel
        ComponentCountSpinner
        ReactionCountSpinner
        MaxIterationsField
        ShowResultsCheckBox
        AutoRunCheckBox
        StoichTable
        ThermoComponentTable
        ThermoReactionTable
        GeneralComponentTable
        ReactionListBox
        KineticTypeDropDown
        K0Field
        EaField
        EaUnitDropDown
        OrdersField
        K0UnitLabel
        ForwardPanel
        ReversePanel
        ReverseK0UnitLabel
        RateEquationLabel
        EaCheckLabel
        ExpressionHelpLabel
        NoThermoCheckBox
        NoThermoNote
        ReverseK0Field
        ReverseEaField
        ReverseEaUnitDropDown
        ReverseOrdersField
        ExpressionField
        OKButton
        CancelButton
    end

    properties (Access = private)
        PackageName = "NIRP package"
        Mode = "new"
        Model = ""
        ComponentTab
        ReactionTab
        FeedTab
        KineticDetailGrid
        SelectedReaction = 1
        UpdatingKinetics = false
    end

    methods
        function obj = ReactiveSystemDialog(varargin)
            parser = inputParser ;
            addParameter(parser,'Visible','on') ;
            addParameter(parser,'Mode','new') ;
            addParameter(parser,'Model','') ;
            parse(parser,varargin{:}) ;
            obj.Mode = lower(string(parser.Results.Mode)) ;
            obj.Model = string(parser.Results.Model) ;
            if ~any(obj.Mode == ["new" "edit"])
                error('nirp:flowsheet:invalidEditorMode', ...
                    'Mode must be "new" or "edit".') ;
            end
            obj.buildUi(char(string(parser.Results.Visible))) ;
            if obj.Mode == "edit" && strlength(obj.Model) > 0
                obj.setPackage(nirp.pkg.readDictionary(obj.dictionaryPath())) ;
            else
                obj.setPackage(nirp.pkg.examples.firstOrderLiquid()) ;
            end
        end

        function delete(obj)
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                delete(obj.Figure) ;
            end
        end

        function setPackage(obj,pkg)
            nirp.pkg.validate(pkg) ;
            obj.PackageName = string(pkg.meta.name) ;
            componentData = cell(numel(pkg.components),5) ;
            for i = 1:numel(pkg.components)
                component = pkg.components(i) ;
                componentData{i,1} = char(string(component.name)) ;
                componentData{i,2} = component.Mw ;
                componentData{i,3} = char(string(component.cp.type)) ;
                if strcmpi(component.cp.type,'constant')
                    componentData{i,4} = obj.vectorText(component.cp.value) ;
                else
                    componentData{i,4} = obj.vectorText(component.cp.coeffs) ;
                end
                componentData{i,5} = char(string(component.cp.unit)) ;
            end
            obj.ComponentTable.Data = componentData ;
            obj.rebuildReactionColumns() ;
            nComp = numel(pkg.components) ;
            nReactions = size(pkg.reactions.stoich,1) ;
            reactionData = cell(nReactions,nComp+12) ;
            for i = 1:nReactions
                reactionData(i,1:nComp) = num2cell(pkg.reactions.stoich(i,:)) ;
                reactionData{i,nComp+1} = pkg.reactions.DH.value(i) ;
                reactionData{i,nComp+2} = char(string(pkg.reactions.DH.unit)) ;
                kinetic = pkg.reactions.kinetics(i) ;
                reactionData{i,nComp+3} = char(string(kinetic.type)) ;
                reactionData{i,nComp+4} = kinetic.k0 ;
                reactionData{i,nComp+5} = obj.quantityValue(kinetic.Ea) ;
                reactionData{i,nComp+6} = obj.quantityUnit(kinetic.Ea) ;
                reactionData{i,nComp+7} = obj.vectorText(kinetic.orders) ;
                reactionData{i,nComp+8} = obj.reverseValue(kinetic,'k0') ;
                reactionData{i,nComp+9} = obj.reverseQuantity(kinetic,'value') ;
                reactionData{i,nComp+10} = char(string(obj.reverseQuantity(kinetic,'unit'))) ;
                reactionData{i,nComp+11} = obj.reverseOrders(kinetic) ;
                reactionData{i,nComp+12} = char(string(kinetic.expression)) ;
            end
            obj.ReactionTable.Data = reactionData ;
            obj.StoichTable.ColumnName = cellstr(string({pkg.components.name})) ;
            obj.StoichTable.Data = num2cell(pkg.reactions.stoich) ;
            obj.ConcentrationUnitDropDown.Value = char(string( ...
                pkg.reactions.rateUnits.concentration)) ;
            obj.TimeUnitDropDown.Value = char(string(pkg.reactions.rateUnits.time)) ;
            obj.TrefField.Value = pkg.reactions.Tref.value ;
            obj.TrefUnitDropDown.Value = obj.temperatureUnit(pkg.reactions.Tref.unit) ;
            thermoComponents=cell(nComp,4) ;
            for i=1:nComp
                thermoComponents(i,:)={char(string(pkg.components(i).name)), ...
                    componentData{i,3},componentData{i,4},componentData{i,5}} ;
            end
            obj.ThermoComponentTable.Data=thermoComponents ;
            thermoReactions=cell(nReactions,3) ;
            for i=1:nReactions
                thermoReactions(i,:)={sprintf('Reaction %d',i), ...
                    pkg.reactions.DH.value(i),char(string(pkg.reactions.DH.unit))} ;
            end
            obj.ThermoReactionTable.Data=thermoReactions ;
            obj.NoThermoCheckBox.Value = isfield(pkg.meta,'thermodynamics') && ...
                isequal(pkg.meta.thermodynamics,false) ;
            obj.updateThermoState() ;
            feedData = cell(numel(pkg.feeds),12) ;
            for i = 1:numel(pkg.feeds)
                feed = pkg.feeds(i) ;
                feedData(i,:) = {char(string(feed.name)),char(string(feed.phase)), ...
                    feed.T.value,obj.temperatureUnit(feed.T.unit),feed.P.value, ...
                    char(string(feed.P.unit)),char(string(feed.basis)), ...
                    obj.vectorText(feed.values),char(string(feed.valuesUnit)), ...
                    obj.quantityValue(feed.Q),obj.quantityUnit(feed.Q),''} ;
            end
            obj.FeedTable.Data = feedData(:,1:11) ;
            obj.ComponentCountSpinner.Value = nComp ;
            obj.ReactionCountSpinner.Value = nReactions ;
            obj.refreshDerivedTables() ;
            obj.StatusLabel.Text = 'Package loaded.' ;
        end

        function pkg = getPackage(obj)
            componentData = obj.ComponentTable.Data ;
            nComp = size(componentData,1) ;
            components = repmat(struct('name',"",'Mw',[],'cp',[], ...
                'hf',[]),1,nComp) ;
            for i = 1:nComp
                components(i).name = string(componentData{i,1}) ;
                components(i).Mw = obj.optionalScalar(componentData{i,2}) ;
                cpType = lower(string(componentData{i,3})) ;
                cpValues = obj.parseVector(componentData{i,4}) ;
                if cpType == "constant"
                    cp = struct('type',"constant",'value',cpValues, ...
                        'unit',string(componentData{i,5})) ;
                else
                    cp = struct('type',"polynomial",'coeffs',cpValues, ...
                        'unit',string(componentData{i,5})) ;
                end
                if obj.NoThermoCheckBox.Value
                    cp = struct('type',"constant",'value',1,'unit',"J/(mol*K)") ;
                end
                components(i).cp = cp ;
            end
            reactionData = obj.ReactionTable.Data ;
            nReactions = size(reactionData,1) ;
            kinetics = repmat(struct('type',"powerlaw",'k0',[], ...
                'Ea',[],'orders',[],'reverse',[],'expression',""),1,nReactions) ;
            for i = 1:nReactions
                offset = nComp ;
                type = lower(string(reactionData{i,offset+3})) ;
                kinetics(i).type = type ;
                kinetics(i).expression = string(reactionData{i,offset+12}) ;
                if type == "powerlaw" || type == "reversible"
                    kinetics(i).k0 = obj.requiredScalar(reactionData{i,offset+4}) ;
                    kinetics(i).Ea = struct('value', ...
                        obj.requiredScalar(reactionData{i,offset+5}), ...
                        'unit',string(reactionData{i,offset+6})) ;
                    kinetics(i).orders = obj.parseVector(reactionData{i,offset+7}) ;
                    if type == "reversible"
                        kinetics(i).reverse = struct('k0', ...
                            obj.requiredScalar(reactionData{i,offset+8}), ...
                            'Ea',struct('value',obj.requiredScalar( ...
                            reactionData{i,offset+9}),'unit', ...
                            string(reactionData{i,offset+10})), ...
                            'orders',obj.parseVector(reactionData{i,offset+11})) ;
                    end
                end
            end
            dhUnits = string(reactionData(:,nComp+2)) ;
            if numel(unique(dhUnits)) > 1 && ~obj.NoThermoCheckBox.Value
                error('nirp:flowsheet:inconsistentUnits', ...
                    'All reaction DH values must use the same unit.') ;
            end
            pkg.meta = struct('formatVersion',1,'name',obj.PackageName) ;
            if obj.NoThermoCheckBox.Value
                % Placeholders (Cp = 1, DH = 0): blocks that need an energy
                % balance stop with nirp:blocks:noThermodynamics (T-144).
                pkg.meta.thermodynamics = false ;
            end
            pkg.components = components ;
            pkg.reactions.stoich = cell2mat(reactionData(:,1:nComp)) ;
            if obj.NoThermoCheckBox.Value
                dhValues = zeros(1,nReactions) ; dhUnits(:) = "J/mol" ;
            else
                dhValues = cell2mat(reactionData(:,nComp+1))' ;
            end
            pkg.reactions.DH = struct('value',dhValues,'unit',dhUnits(1)) ;
            pkg.reactions.Tref = struct('value',obj.TrefField.Value, ...
                'unit',string(obj.packageTemperatureUnit(obj.TrefUnitDropDown.Value))) ;
            pkg.reactions.rateUnits = struct('concentration', ...
                string(obj.ConcentrationUnitDropDown.Value),'time', ...
                string(obj.TimeUnitDropDown.Value)) ;
            pkg.reactions.kinetics = kinetics ;
            feedData = obj.FeedTable.Data ;
            feeds = repmat(struct('name',"",'phase',"L",'T',[], ...
                'P',[],'basis',"molarFlows",'values',[], ...
                'valuesUnit',"mol/s",'Q',[]),1,size(feedData,1)) ;
            for i = 1:size(feedData,1)
                feeds(i).name = string(feedData{i,1}) ;
                feeds(i).phase = string(feedData{i,2}) ;
                feeds(i).T = struct('value',obj.requiredScalar(feedData{i,3}), ...
                    'unit',string(obj.packageTemperatureUnit(feedData{i,4}))) ;
                feeds(i).P = struct('value',obj.requiredScalar(feedData{i,5}), ...
                    'unit',string(feedData{i,6})) ;
                feeds(i).basis = string(feedData{i,7}) ;
                feeds(i).values = obj.parseVector(feedData{i,8}) ;
                feeds(i).valuesUnit = string(feedData{i,9}) ;
                if lower(feeds(i).basis)=="totalandfractions"
                    total=feeds(i).values(1);fractions=feeds(i).values(2:end);
                    fractions=resizeVector(fractions,nComp);s=sum(fractions);
                    if s<=0,fractions(1)=1;else,fractions=fractions/s;end
                    feeds(i).values=[total fractions];
                else
                    feeds(i).values=resizeVector(feeds(i).values,nComp);
                end
                if isempty(feedData{i,10}) || string(feedData{i,10}) == ""
                    feeds(i).Q = [] ;
                else
                    feeds(i).Q = struct('value',obj.requiredScalar(feedData{i,10}), ...
                        'unit',string(feedData{i,11})) ;
                end
            end
            pkg.feeds = feeds ;
        end

        function [valid,message] = validate(obj)
            try
                nirp.pkg.validate(obj.getPackage()) ;
                valid = true ; message = "Package is valid." ;
            catch exception
                valid = false ; message = string(exception.message) ;
            end
            obj.StatusLabel.Text = char(message) ;
        end

        function [modelFile,dictionaryFile] = createFlowsheet(obj,name,folder,varargin)
            [valid,message] = obj.validate() ;
            if ~valid
                error('nirp:flowsheet:invalidPackage','%s',message) ;
            end
            [modelFile,dictionaryFile] = nirp.flowsheet.new( ...
                name,obj.getPackage(),folder,varargin{:}) ;
            load_system(modelFile) ; block=findFlowsheet(name) ;
            if ~isempty(block)
                set_param(block,'MaxIterations',num2str(obj.MaxIterationsField.Value), ...
                    'ShowResultsAfterRun',onOff(obj.ShowResultsCheckBox.Value), ...
                    'AutoRun',onOff(obj.AutoRunCheckBox.Value)) ;
                nirp.flowsheet.configure(name) ; save_system(name) ;
            end
        end

        function setCounts(obj,nComponents,nReactions)
            if nComponents < 1 || nComponents ~= fix(nComponents) || ...
                    nReactions < 1 || nReactions ~= fix(nReactions)
                error('nirp:flowsheet:invalidCount', ...
                    'Component and reaction counts must be positive integers.') ;
            end
            while size(obj.ComponentTable.Data,1) < nComponents, obj.addComponent() ; end
            while size(obj.ComponentTable.Data,1) > nComponents, obj.removeLast('component') ; end
            while size(obj.ReactionTable.Data,1) < nReactions, obj.addReaction() ; end
            while size(obj.ReactionTable.Data,1) > nReactions, obj.removeLast('reaction') ; end
            obj.ComponentCountSpinner.Value = nComponents ;
            obj.ReactionCountSpinner.Value = nReactions ;
        end

        function changed = saveToModel(obj,model)
            if nargin < 2 || strlength(string(model)) == 0, model = obj.Model ; end
            oldPkg = nirp.pkg.readDictionary(obj.dictionaryPath(model)) ;
            pkg = obj.getPackage() ;
            nirp.pkg.validate(pkg) ;
            changed = numel(oldPkg.components) ~= numel(pkg.components) ;
            nirp.pkg.writeDictionary(pkg,obj.dictionaryPath(model)) ;
            flowsheets=find_system(char(string(model)),'SearchDepth',1, ...
                'BlockType','SubSystem') ;
            for i=1:numel(flowsheets)
                if strcmp(get_param(flowsheets{i},'Mask'),'on') && ...
                        any(strcmp(get_param(flowsheets{i},'MaskNames'),'MaxIterations'))
                    set_param(flowsheets{i},'MaxIterations', ...
                        num2str(obj.MaxIterationsField.Value), ...
                        'ShowResultsAfterRun',onOff(obj.ShowResultsCheckBox.Value)) ;
                    break
                end
            end
            nirp.flowsheet.configure(char(string(model))) ;
            block=findFlowsheet(model) ;
            if ~isempty(block), set_param(block,'AutoRun',onOff(obj.AutoRunCheckBox.Value)) ; end
            if changed
                obj.StatusLabel.Text = ['Package saved. The component count changed; ' ...
                    'NirpStream was regenerated. Run the model again.'] ;
            else
                obj.StatusLabel.Text = 'Package saved to model.' ;
            end
        end

        function selectReaction(obj,index)
            nReactions=size(obj.ReactionTable.Data,1);
            if index<1 || index>nReactions || index~=fix(index)
                error('nirp:flowsheet:invalidReaction','Reaction index is out of range.') ;
            end
            obj.SelectedReaction=index;
            if ~isempty(obj.ReactionListBox.Items)
                obj.ReactionListBox.Value=obj.ReactionListBox.Items{index};
            end
            obj.loadKineticDetail();
        end

        function setKineticType(obj,type)
            type=lower(char(string(type)));
            if ~any(strcmp(type,{'powerlaw','reversible','expression'}))
                error('nirp:flowsheet:invalidKinetics','Unknown kinetics type.') ;
            end
            obj.KineticTypeDropDown.Value=type;
            data=obj.ReactionTable.Data;nComp=size(obj.ComponentTable.Data,1);
            data{obj.SelectedReaction,nComp+3}=type;obj.ReactionTable.Data=data;
            obj.updateKineticVisibility();obj.refreshReactionList();
        end
    end

    methods (Static)
        function obj = openForModel(model)
            obj = nirp.flowsheet.ReactiveSystemDialog('Mode','edit','Model',model) ;
        end
    end

    methods (Access = private)
        function buildUi(obj,visible)
            obj.Figure = uifigure('Name','Reactive System', ...
                'Tag','NirpReactiveSystemDialog','Position',[100 100 1260 720], ...
                'Visible',visible,'WindowStyle','alwaysontop') ;
            main = uigridlayout(obj.Figure,[4 1]) ;
            main.RowHeight = {'1x',38,42,26} ;
            tabs = uitabgroup(main) ;
            obj.ComponentTab = uitab(tabs,'Title','General') ;
            obj.ReactionTab = uitab(tabs,'Title','Kinetics') ;
            obj.FeedTab = uitab(tabs,'Title','Thermodynamics') ;
            obj.buildComponents() ; obj.buildReactions() ; obj.buildFeeds() ;
            settings=uigridlayout(main,[1 6],'ColumnWidth',{135,90,170,250,110,'1x'});
            uilabel(settings,'Text','Maximum iterations');
            obj.MaxIterationsField=uieditfield(settings,'numeric','Limits',[1 Inf], ...
                'RoundFractionalValues','on','Value',200);
            obj.ShowResultsCheckBox=uicheckbox(settings,'Text','Show results after run','Value',true);
            obj.AutoRunCheckBox=uicheckbox(settings,'Text','Auto-run when a dialog is accepted','Value',true);
            if obj.Mode=="edit"
                block=findFlowsheet(obj.Model);
                if ~isempty(block),obj.MaxIterationsField.Value=str2double(get_param(block,'MaxIterations'));obj.ShowResultsCheckBox.Value=strcmp(get_param(block,'ShowResultsAfterRun'),'on');end
                if ~isempty(block)&&any(strcmp(get_param(block,'MaskNames'),'AutoRun')),obj.AutoRunCheckBox.Value=strcmp(get_param(block,'AutoRun'),'on');end
                uibutton(settings,'Text','Show results','ButtonPushedFcn',@(~,~) nirp.flowsheet.showResults(obj.Model));
            end
            controls = uigridlayout(main,[1 4]) ;
            controls.Padding = [10 4 10 4] ;
            controls.ColumnWidth = {'1x',130,90,10} ;
            uilabel(controls,'Text','') ;
            if obj.Mode == "edit"
                obj.OKButton=uibutton(controls,'Text','OK','ButtonPushedFcn', ...
                    @(~,~) obj.acceptDialog()) ;
            else
                uibutton(controls,'Text','Create flowsheet...','ButtonPushedFcn', ...
                    @(~,~) obj.createInteractive()) ;
            end
            obj.CancelButton=uibutton(controls,'Text','Cancel','ButtonPushedFcn', ...
                @(~,~) delete(obj)) ;
            obj.StatusLabel = uilabel(main,'Text','Ready.','FontAngle','italic') ;
        end

        function buildComponents(obj)
            layout = uigridlayout(obj.ComponentTab,[6 1]) ;
            layout.RowHeight = {38,'0.45x',32,26,'0.55x',32} ;
            header=uigridlayout(layout,[1 5],'ColumnWidth',{150,110,140,110,'1x'});
            uilabel(header,'Text','Number of components');
            obj.ComponentCountSpinner=uispinner(header,'Limits',[1 Inf], ...
                'RoundFractionalValues','on','ValueChangedFcn',@(~,~) obj.countsChanged());
            uilabel(header,'Text','Number of reactions');
            obj.ReactionCountSpinner=uispinner(header,'Limits',[1 Inf], ...
                'RoundFractionalValues','on','ValueChangedFcn',@(~,~) obj.countsChanged());
            uilabel(header,'Text','Stoichiometry columns follow component names.','FontAngle','italic');
            obj.GeneralComponentTable = uitable(layout,'ColumnName', ...
                {'Name','Mw (g/mol)'},'ColumnEditable',[true true], ...
                'CellEditCallback',@(~,event) obj.generalComponentEdited(event)) ;
            obj.ComponentTable=uitable(obj.Figure,'Visible','off');
            buttons = uigridlayout(layout,[1 3]) ; buttons.ColumnWidth={80,80,'1x'} ;
            buttons.Padding = [0 0 0 0] ;
            uibutton(buttons,'Text','Add','ButtonPushedFcn',@(~,~) obj.addComponent()) ;
            uibutton(buttons,'Text','Remove','ButtonPushedFcn',@(~,~) obj.removeLast('component')) ;
            uilabel(layout,'Text','Stoichiometric matrix [reactions x components]', ...
                'FontWeight','bold','HorizontalAlignment','center') ;
            obj.StoichTable=uitable(layout,'ColumnEditable',true, ...
                'CellEditCallback',@(~,event) obj.stoichEdited(event)) ;
            buttons = uigridlayout(layout,[1 3],'ColumnWidth',{110,110,'1x'}, ...
                'Padding',[0 0 0 0]) ;
            uibutton(buttons,'Text','Add reaction','ButtonPushedFcn',@(~,~) obj.addReaction()) ;
            uibutton(buttons,'Text','Remove reaction','ButtonPushedFcn', ...
                @(~,~) obj.removeLast('reaction')) ;
        end

        function buildReactions(obj)
            layout = uigridlayout(obj.ReactionTab,[2 1]) ;
            layout.RowHeight = {38,'1x'} ;
            header = uigridlayout(layout,[1 4],'ColumnWidth',{130,'1x',80,'1x'}) ;
            header.Padding = [0 0 0 0] ;
            uilabel(header,'Text','Concentration unit') ;
            obj.ConcentrationUnitDropDown = uidropdown(header,'Items', ...
                UnitConverterHelper.getUnits('Concentration')) ;
            uilabel(header,'Text','Time unit') ;
            obj.TimeUnitDropDown = uidropdown(header,'Items', ...
                UnitConverterHelper.getUnits('Time')) ;
            obj.ConcentrationUnitDropDown.ValueChangedFcn=@(~,~) obj.updateKineticPreview();
            obj.TimeUnitDropDown.ValueChangedFcn=@(~,~) obj.updateKineticPreview();
            content=uigridlayout(layout,[1 2],'ColumnWidth',{260,'1x'});
            listPanel=uipanel(content,'Title','Reactions');listGrid=uigridlayout(listPanel,[1 1]);
            obj.ReactionListBox=uilistbox(listGrid,'ValueChangedFcn', ...
                @(~,~) obj.reactionSelected());
            detailPanel=uipanel(content,'Title','Kinetic details');
            obj.KineticDetailGrid=uigridlayout(detailPanel,[4 2], ...
                'ColumnWidth',{'1x','1x'},'RowHeight',{32,'1x',44,36});
            top=uigridlayout(obj.KineticDetailGrid,[1 3],'ColumnWidth',{60,160,'1x'},'Padding',[0 0 0 0]);
            top.Layout.Row=1;top.Layout.Column=[1 2];
            uilabel(top,'Text','Kinetics');
            obj.KineticTypeDropDown=uidropdown(top,'Items',{'powerlaw','reversible','expression'}, ...
                'ValueChangedFcn',@(~,~) obj.kineticTypeChanged());
            edited=@(~,~) obj.kineticDetailEdited();
            [obj.ForwardPanel,obj.K0Field,obj.K0UnitLabel,obj.EaField,obj.EaUnitDropDown, ...
                obj.OrdersField]=termPanel(obj.KineticDetailGrid,1,'Forward',edited);
            [obj.ReversePanel,obj.ReverseK0Field,obj.ReverseK0UnitLabel,obj.ReverseEaField, ...
                obj.ReverseEaUnitDropDown,obj.ReverseOrdersField]=termPanel(obj.KineticDetailGrid,2,'Reverse',edited);
            obj.ExpressionField=uitextarea(obj.KineticDetailGrid,'ValueChangedFcn',edited);
            obj.ExpressionField.Layout.Row=2;obj.ExpressionField.Layout.Column=[1 2];
            obj.RateEquationLabel=uilabel(obj.KineticDetailGrid,'Text','','WordWrap','on');
            obj.RateEquationLabel.Layout.Row=3;obj.RateEquationLabel.Layout.Column=[1 2];
            obj.ExpressionHelpLabel=uilabel(obj.KineticDetailGrid,'Text','','WordWrap','on', ...
                'FontColor',[0.35 0.35 0.35]);
            obj.ExpressionHelpLabel.Layout.Row=3;obj.ExpressionHelpLabel.Layout.Column=[1 2];
            obj.EaCheckLabel=uilabel(obj.KineticDetailGrid,'Text','','WordWrap','on', ...
                'FontColor',[0.8 0.4 0]);
            obj.EaCheckLabel.Layout.Row=4;obj.EaCheckLabel.Layout.Column=[1 2];
            obj.ReactionTable=uitable(obj.Figure,'Visible','off');
        end

        function buildFeeds(obj)
            layout = uigridlayout(obj.FeedTab,[5 1]) ;
            layout.RowHeight={34,'0.5x',26,'0.5x',36} ;
            header=uigridlayout(layout,[1 5],'ColumnWidth',{45,130,80,'1x',190});
            uilabel(header,'Text','Tref');obj.TrefField=uieditfield(header,'numeric');
            obj.TrefUnitDropDown=uidropdown(header,'Items',{'K',[char(176) 'C']});
            uilabel(header,'Text','Reference temperature for Cp and reaction enthalpy.','FontAngle','italic');
            obj.NoThermoCheckBox=uicheckbox(header,'Text','Without thermodynamics', ...
                'ValueChangedFcn',@(~,~) obj.noThermoChanged());
            obj.ThermoComponentTable=uitable(layout,'ColumnName', ...
                {'Component','Cp type','Cp coefficients / value','Cp unit'}, ...
                'ColumnEditable',[false true true true], ...
                'ColumnFormat',{'char',{'constant','polynomial'},'char', ...
                UnitConverterHelper.getUnits('MolarHeatCapacity')}, ...
                'CellEditCallback',@(~,event) obj.thermoComponentEdited(event));
            uilabel(layout,'Text','Reaction enthalpies','FontWeight','bold');
            obj.ThermoReactionTable=uitable(layout,'ColumnName', ...
                {'Reaction','DH','DH unit'},'ColumnEditable',[false true true], ...
                'ColumnFormat',{'char','numeric',UnitConverterHelper.getUnits('EnergyPerMol')}, ...
                'CellEditCallback',@(~,event) obj.thermoReactionEdited(event));
            obj.NoThermoNote=uilabel(layout,'Text','Feed conditions are edited in Feed Stream dialogs.', ...
                'FontAngle','italic','WordWrap','on');
            obj.FeedTable = uitable(obj.Figure,'Visible','off') ;
        end

        function stoichEdited(obj,event)
            data=obj.ReactionTable.Data ; data{event.Indices(1),event.Indices(2)}=event.NewData ;
            obj.ReactionTable.Data=data ;
            obj.refreshDerivedTables() ;
        end

        function generalComponentEdited(obj,event)
            data=obj.ComponentTable.Data;
            data{event.Indices(1),event.Indices(2)}=event.NewData;
            obj.ComponentTable.Data=data;
            obj.componentEdited(event);
        end

        function thermoComponentEdited(obj,event)
            data=obj.ComponentTable.Data ; data{event.Indices(1),event.Indices(2)+1}=event.NewData ;
            obj.ComponentTable.Data=data ;
        end

        function thermoReactionEdited(obj,event)
            data=obj.ReactionTable.Data;nComp=size(obj.ComponentTable.Data,1);
            data{event.Indices(1),nComp+event.Indices(2)-1}=event.NewData ;
            obj.ReactionTable.Data=data ;
            obj.updateKineticPreview() ;
        end

        function noThermoChanged(obj)
            obj.updateThermoState() ;
            if obj.NoThermoCheckBox.Value && strcmp(obj.Figure.Visible,'on')
                uialert(obj.Figure,noThermoText(),'Without thermodynamics','Icon','warning') ;
            end
        end

        function updateThermoState(obj)
            noThermo=obj.NoThermoCheckBox.Value ;
            obj.ThermoComponentTable.Enable=onOff(~noThermo) ;
            obj.ThermoReactionTable.Enable=onOff(~noThermo) ;
            if noThermo
                obj.NoThermoNote.Text=noThermoText() ;
                obj.NoThermoNote.FontColor=[0.8 0.4 0] ;
            else
                obj.NoThermoNote.Text='Feed conditions are edited in Feed Stream dialogs.' ;
                obj.NoThermoNote.FontColor=[0 0 0] ;
            end
            obj.updateKineticPreview() ;
        end

        function countsChanged(obj)
            obj.setCounts(obj.ComponentCountSpinner.Value, ...
                obj.ReactionCountSpinner.Value) ;
        end

        function rebuildReactionColumns(obj)
            names = string(obj.ComponentTable.Data(:,1))' ;
            fixed = ["DH","DH unit","Kinetics","k0","Ea","Ea unit", ...
                "Orders","Reverse k0","Reverse Ea","Reverse Ea unit", ...
                "Reverse orders","Expression"] ;
            obj.ReactionTable.ColumnName = cellstr([names fixed]) ;
            obj.ReactionTable.ColumnEditable = true(1,numel(names)+numel(fixed)) ;
            formats = repmat({'numeric'},1,numel(names)) ;
            obj.ReactionTable.ColumnFormat = [formats,{'numeric', ...
                UnitConverterHelper.getUnits('EnergyPerMol'), ...
                {'powerlaw','reversible','expression'},'numeric','numeric', ...
                UnitConverterHelper.getUnits('EnergyPerMol'),'char','numeric', ...
                'numeric',UnitConverterHelper.getUnits('EnergyPerMol'),'char','char'}] ;
        end

        function componentEdited(obj,event)
            if event.Indices(2) == 1, obj.rebuildReactionColumns() ; end
            obj.refreshDerivedTables() ;
        end

        function feedEdited(obj,event)
            if event.Indices(2) ~= 7, return, end
            row = event.Indices(1) ; basis = lower(string(event.NewData)) ;
            if basis == "concentrations"
                units = UnitConverterHelper.getUnits('Concentration') ;
            else
                units = UnitConverterHelper.getUnits('MolarFlow') ;
            end
            data = obj.FeedTable.Data ; data{row,9} = units{1} ; obj.FeedTable.Data = data ;
        end

        function addComponent(obj)
            data = obj.ComponentTable.Data ;
            data(end+1,:) = {sprintf('C%d',size(data,1)+1),[], ...
                'constant','100','J/(mol*K)'} ;
            obj.ComponentTable.Data = data ;
            old = obj.ReactionTable.Data ; obj.rebuildReactionColumns() ;
            if ~isempty(old), obj.ReactionTable.Data = [old(:,1:end-12) num2cell(zeros(size(old,1),1)) old(:,end-11:end)] ; end
            obj.refreshDerivedTables() ;
        end

        function addReaction(obj)
            nComp = size(obj.ComponentTable.Data,1) ;
            row = [num2cell(zeros(1,nComp)),{0,'J/mol','powerlaw',1,0, ...
                'J/mol',obj.vectorText(zeros(1,nComp)),[],[], ...
                'J/mol','', ''}] ;
            data = obj.ReactionTable.Data ; data(end+1,:) = row ; obj.ReactionTable.Data=data ;
            obj.refreshDerivedTables() ;
        end

        function addFeed(obj)
            units = UnitConverterHelper.getUnits('MolarFlow') ;
            row = {sprintf('F%d',size(obj.FeedTable.Data,1)+1),'L',298.15,'K', ...
                101325,'Pa','molarFlows',obj.vectorText(zeros(1,size( ...
                obj.ComponentTable.Data,1))),units{1},1e-3,'m^3/s'} ;
            data=obj.FeedTable.Data ; data(end+1,:)=row ; obj.FeedTable.Data=data ;
        end

        function removeLast(obj,type)
            switch type
                case 'component'
                    data=obj.ComponentTable.Data ; if size(data,1)<=1, return, end
                    data(end,:)=[] ; obj.ComponentTable.Data=data ;
                    reactions=obj.ReactionTable.Data ;
                    reactions(:,size(data,1)+1)=[] ; obj.rebuildReactionColumns() ;
                    obj.ReactionTable.Data=reactions ;
                case 'reaction'
                    data=obj.ReactionTable.Data ; if size(data,1)<=1, return, end
                    data(end,:)=[] ; obj.ReactionTable.Data=data ;
                case 'feed'
                    data=obj.FeedTable.Data ; if size(data,1)<=1, return, end
                    data(end,:)=[] ; obj.FeedTable.Data=data ;
            end
            obj.refreshDerivedTables() ;
        end

        function refreshDerivedTables(obj)
            components=obj.ComponentTable.Data;nComp=size(components,1);
            reactions=obj.ReactionTable.Data;nReactions=size(reactions,1);
            obj.StoichTable.ColumnName=components(:,1)';
            obj.StoichTable.Data=reactions(:,1:nComp);
            obj.GeneralComponentTable.Data=components(:,1:2);
            thermo=cell(nComp,4);
            for i=1:nComp,thermo(i,:)={components{i,1},components{i,3},components{i,4},components{i,5}};end
            obj.ThermoComponentTable.Data=thermo;
            dh=cell(nReactions,3);
            labels=obj.reactionLabels();
            for i=1:nReactions,dh(i,:)={labels{i},reactions{i,nComp+1},reactions{i,nComp+2}};end
            obj.ThermoReactionTable.Data=dh;
            obj.ComponentCountSpinner.Value=nComp;obj.ReactionCountSpinner.Value=nReactions;
            obj.refreshReactionList();
        end

        function refreshReactionList(obj)
            labels=obj.reactionLabels();
            if isempty(labels),return,end
            obj.SelectedReaction=min(max(obj.SelectedReaction,1),numel(labels));
            obj.ReactionListBox.Items=labels;
            obj.ReactionListBox.Value=labels{obj.SelectedReaction};
            obj.loadKineticDetail();
        end

        function labels=reactionLabels(obj)
            components=string(obj.ComponentTable.Data(:,1));data=obj.ReactionTable.Data;
            labels=cell(1,size(data,1));arrow=char(8594);
            for row=1:size(data,1)
                coefficients=cell2mat(data(row,1:numel(components)));
                reactants=sideText(-min(coefficients,0),components);
                products=sideText(max(coefficients,0),components);
                labels{row}=sprintf('R%d: %s %s %s',row,reactants,arrow,products);
            end
        end

        function reactionSelected(obj)
            index=find(strcmp(obj.ReactionListBox.Items,obj.ReactionListBox.Value),1);
            if ~isempty(index),obj.selectReaction(index);end
        end

        function loadKineticDetail(obj)
            if obj.UpdatingKinetics || isempty(obj.ReactionTable.Data),return,end
            obj.UpdatingKinetics=true;cleanup=onCleanup(@() obj.finishKineticUpdate());
            data=obj.ReactionTable.Data;nComp=size(obj.ComponentTable.Data,1);row=obj.SelectedReaction;
            names=obj.ComponentTable.Data(:,1);
            obj.KineticTypeDropDown.Value=data{row,nComp+3};
            obj.K0Field.Value=scalarText(data{row,nComp+4});
            obj.EaField.Value=scalarText(data{row,nComp+5});setDropdownValue(obj.EaUnitDropDown,data{row,nComp+6});
            obj.OrdersField.Data=ordersData(names,data{row,nComp+7});
            obj.ReverseK0Field.Value=scalarText(data{row,nComp+8});
            obj.ReverseEaField.Value=scalarText(data{row,nComp+9});
            setDropdownValue(obj.ReverseEaUnitDropDown,data{row,nComp+10});
            obj.ReverseOrdersField.Data=ordersData(names,data{row,nComp+11});
            obj.ExpressionField.Value=cellstr(string(data{row,nComp+12}));
            obj.updateKineticVisibility();
            obj.updateKineticPreview();
        end

        function finishKineticUpdate(obj),obj.UpdatingKinetics=false;end

        function kineticTypeChanged(obj)
            if obj.UpdatingKinetics,return,end
            obj.setKineticType(obj.KineticTypeDropDown.Value);
        end

        function kineticDetailEdited(obj)
            if obj.UpdatingKinetics,return,end
            data=obj.ReactionTable.Data;nComp=size(obj.ComponentTable.Data,1);row=obj.SelectedReaction;
            data(row,nComp+(4:12))={textScalar(obj.K0Field.Value),textScalar(obj.EaField.Value), ...
                obj.EaUnitDropDown.Value,tableOrders(obj.OrdersField.Data), ...
                textScalar(obj.ReverseK0Field.Value),textScalar(obj.ReverseEaField.Value), ...
                obj.ReverseEaUnitDropDown.Value,tableOrders(obj.ReverseOrdersField.Data), ...
                strjoin(string(obj.ExpressionField.Value),newline)};
            obj.ReactionTable.Data=data;
            obj.updateKineticPreview();
        end

        function updateKineticVisibility(obj)
            type=string(obj.KineticTypeDropDown.Value);
            isExpression=type=="expression";isReversible=type=="reversible";
            forward={obj.ForwardPanel,obj.K0Field,obj.EaField,obj.OrdersField,obj.RateEquationLabel};
            reverse={obj.ReversePanel,obj.ReverseK0Field,obj.ReverseEaField,obj.ReverseOrdersField,obj.EaCheckLabel};
            for i=1:numel(forward),forward{i}.Visible=onOff(~isExpression);end
            for i=1:numel(reverse),reverse{i}.Visible=onOff(isReversible);end
            obj.ExpressionField.Visible=onOff(isExpression);
            obj.ExpressionHelpLabel.Visible=onOff(isExpression);
        end

        function updateKineticPreview(obj)
            % Rate equation, k0 units, expression help and the Ea_f - Ea_r ~ DH check (T-144).
            data=obj.ReactionTable.Data;nComp=size(obj.ComponentTable.Data,1);
            if isempty(data)||isempty(obj.RateEquationLabel),return,end
            row=min(obj.SelectedReaction,size(data,1));
            names=string(obj.ComponentTable.Data(:,1))';
            conc=obj.ConcentrationUnitDropDown.Value;time=obj.TimeUnitDropDown.Value;
            forward=resizeVector(obj.parseVector(data{row,nComp+7}),nComp);
            reverse=resizeVector(obj.parseVector(data{row,nComp+11}),nComp);
            obj.K0UnitLabel.Text=rateConstantUnit(sum(forward),conc,time);
            obj.ReverseK0UnitLabel.Text=rateConstantUnit(sum(reverse),conc,time);
            dot=char(183);
            equation=['r = k0' dot 'exp(-Ea/RT)' concentrationTerms(forward,names)];
            if string(data{row,nComp+3})=="reversible"
                equation=['r = k0f' dot 'exp(-Eaf/RT)' concentrationTerms(forward,names) ...
                    ' ' char(8722) ' k0r' dot 'exp(-Ear/RT)' concentrationTerms(reverse,names)];
            end
            obj.RateEquationLabel.Text=sprintf('%s   [%s/%s]',equation,conc,time);
            variables=strings(1,nComp);
            for i=1:nComp,variables(i)=sprintf('concentration(%d) = %s',i,names(i));end
            obj.ExpressionHelpLabel.Text=sprintf(['Write r in %s/%s using %s (in %s) and T (K). ' ...
                'Example: 0.25*concentration(1)^2*exp(-5000/(8.314*T)). ' ...
                'The app converts concentrations and rates to SI automatically.'], ...
                conc,time,strjoin(variables,', '),conc);
            obj.EaCheckLabel.Text=eaCheckText(data(row,:),nComp,obj.NoThermoCheckBox.Value);
        end

        function applied=applyDialog(obj)
            applied=false;
            obj.kineticDetailEdited();
            [valid,~]=obj.validate();if ~valid,return,end
            try,if obj.Mode=="edit",obj.saveToModel();end;applied=true;catch exception,obj.StatusLabel.Text=exception.message;end
        end

        function acceptDialog(obj)
            if obj.applyDialog()
                model=obj.Model;delete(obj);
                if strlength(model)>0,nirp.flowsheet.autoRun(model);end
            end
        end

        function createInteractive(obj)
            answer=inputdlg('Model name:','New NIRP flowsheet',1,{'nirp_flowsheet'}) ;
            if isempty(answer), return, end
            folder=uigetdir(pwd,'Select a folder for the flowsheet') ;
            if isequal(folder,0), return, end
            try,obj.createFlowsheet(strtrim(answer{1}),folder) ;delete(obj);catch exception,obj.StatusLabel.Text=exception.message;end
        end

        function path = dictionaryPath(obj,model)
            if nargin < 2, model = obj.Model ; end
            model = char(string(model)) ;
            if isempty(model), error('nirp:flowsheet:noModel','No model was specified.') ; end
            if ~bdIsLoaded(model), load_system(model) ; end
            root = bdroot(model) ; dictionary = get_param(root,'DataDictionary') ;
            modelFile = get_param(root,'FileName') ;
            if isempty(dictionary)
                error('nirp:flowsheet:noDictionary','Model "%s" has no data dictionary.',root) ;
            end
            if isfile(dictionary), path = dictionary ;
            else, path = fullfile(fileparts(modelFile),dictionary) ; end
        end
    end

    methods (Static, Access = private)
        function value = parseVector(input)
            if isnumeric(input), value = input ; return, end
            text = strtrim(char(string(input))) ;
            if isempty(text), value = [] ; return, end
            value = sscanf(strrep(text,',',' '),'%f')' ;
        end
        function value = requiredScalar(input)
            if isnumeric(input), value=input ; else, value=str2double(input) ; end
        end
        function value = optionalScalar(input)
            if isempty(input) || string(input)=="", value=[] ;
            else, value=nirp.flowsheet.ReactiveSystemDialog.requiredScalar(input) ; end
        end
        function text = vectorText(value)
            if isempty(value), text='' ; else
                % Shortest text that reads back to the same double (Claude, T-109 review)
                parts = cell(1,numel(value)) ;
                for k = 1:numel(value)
                    parts{k} = sprintf('%.15g',value(k)) ;
                    if str2double(parts{k}) ~= value(k), parts{k} = sprintf('%.17g',value(k)) ; end
                end
                text = strjoin(parts,' ') ;
            end
        end
        function value = quantityValue(q)
            if isempty(q), value=[] ; else, value=q.value ; end
        end
        function unit = quantityUnit(q)
            if isempty(q), unit='' ; else, unit=char(string(q.unit)) ; end
        end
        function value = reverseValue(k,field)
            if isempty(k.reverse), value=[] ; else, value=k.reverse.(field) ; end
        end
        function value = reverseQuantity(k,field)
            if isempty(k.reverse), value=[] ; else, value=k.reverse.Ea.(field) ; end
        end
        function value = reverseOrders(k)
            if isempty(k.reverse), value='' ; else, value=nirp.flowsheet.ReactiveSystemDialog.vectorText(k.reverse.orders) ; end
        end
        function unit = temperatureUnit(unit)
            unit=char(string(unit)) ; if strcmp(unit,'C'), unit=[char(176) 'C']; end
        end
        function unit = packageTemperatureUnit(unit)
            unit=char(string(unit)) ; if strcmp(unit,[char(176) 'C']), unit='C'; end
        end
    end
end

function value=resizeVector(value,count)
    value=reshape(value,1,[]);
    if numel(value)<count,value(end+1:count)=0;else,value=value(1:count);end
end

function block=findFlowsheet(model)
    block='';if strlength(string(model))==0,return,end
    items=find_system(char(string(model)),'SearchDepth',1,'BlockType','SubSystem');
    for i=1:numel(items)
        if strcmp(get_param(items{i},'Mask'),'on')&&any(strcmp(get_param(items{i},'MaskNames'),'MaxIterations')),block=items{i};return,end
    end
end

function value=onOff(flag)
    if flag,value='on';else,value='off';end
end

function [panel,k0,k0Unit,ea,eaUnit,orders]=termPanel(grid,column,title,callback)
    panel=uipanel(grid,'Title',title);panel.Layout.Row=2;panel.Layout.Column=column;
    g=uigridlayout(panel,[3 3],'ColumnWidth',{28,100,'1x'},'RowHeight',{26,26,'1x'}, ...
        'Padding',[6 6 6 6]);
    uilabel(g,'Text','k0','HorizontalAlignment','right');
    k0=uieditfield(g,'text','ValueChangedFcn',callback);
    k0Unit=uilabel(g,'Text','','FontAngle','italic');
    uilabel(g,'Text','Ea','HorizontalAlignment','right');
    ea=uieditfield(g,'text','ValueChangedFcn',callback);
    eaUnit=uidropdown(g,'Items',UnitConverterHelper.getUnits('EnergyPerMol'),'ValueChangedFcn',callback);
    orders=uitable(g,'ColumnName',{'Component','Order'},'ColumnEditable',[false true], ...
        'ColumnFormat',{'char','numeric'},'RowName',{},'CellEditCallback',callback);
    orders.Layout.Row=3;orders.Layout.Column=[1 3];
end

function data=ordersData(names,text)
    values=resizeVector(localParse(text),numel(names));
    data=[reshape(cellstr(string(names)),[],1) num2cell(values(:))];
end

function text=tableOrders(data)
    values=zeros(1,size(data,1));
    for i=1:size(data,1)
        if isnumeric(data{i,2})&&isscalar(data{i,2})&&isfinite(data{i,2}),values(i)=data{i,2};end
    end
    text=strjoin(arrayfun(@(v) sprintf('%.15g',v),values,'UniformOutput',false),' ');
end

function text=rateConstantUnit(order,conc,time)
    if abs(order-1)<1e-12,text=['1/' time];
    elseif abs(order)<1e-12,text=[conc '/' time];
    else,text=sprintf('(%s)^%g/%s',conc,1-order,time);end
end

function text=concentrationTerms(orders,names)
    text='';
    for i=1:numel(orders)
        if orders(i)==0,continue,end
        text=[text char(183) 'C_' char(names(i))]; %#ok<AGROW>
        if orders(i)~=1,text=[text sprintf('^%g',orders(i))];end %#ok<AGROW>
    end
end

function text=eaCheckText(row,nComp,noThermo)
    text='';
    if noThermo||string(row{nComp+3})~="reversible",return,end
    try
        eaf=UnitConverterHelper.convertToSI('EnergyPerMol',row{nComp+5},char(string(row{nComp+6})));
        ear=UnitConverterHelper.convertToSI('EnergyPerMol',row{nComp+9},char(string(row{nComp+10})));
        dh=UnitConverterHelper.convertToSI('EnergyPerMol',row{nComp+1},char(string(row{nComp+2})));
    catch
        return
    end
    values=[eaf ear dh];
    if numel(values)~=3||~all(isfinite(values))||dh==0,return,end
    if abs((eaf-ear)-dh)>0.05*abs(dh)
        text=sprintf(['Check: Ea,f - Ea,r = %.4g J/mol, but DH = %.4g J/mol ' ...
            '(difference above 5 %%). For an elementary reversible reaction they should match.'],eaf-ear,dh);
    end
end

function value=localParse(input)
    if isnumeric(input),value=input;return,end
    text=strtrim(char(string(input)));
    if isempty(text),value=[];else,value=sscanf(strrep(text,',',' '),'%f')';end
end

function text=noThermoText()
    text=['Without thermodynamics only isothermal reactors can be used. Adiabatic reactors, ' ...
        'reactors with a Jacket, Heater and Jacket blocks will stop with an error; ' ...
        'a Mixer outlet temperature is a molar average.'];
end

function text=sideText(coefficients,names)
    terms=strings(0,1);
    for i=1:numel(coefficients)
        coefficient=coefficients(i);
        if coefficient<=0,continue,end
        if abs(coefficient-1)<1e-12
            terms(end+1)=names(i); %#ok<AGROW>
        else
            terms(end+1)=string(sprintf('%g %s',coefficient,names(i))); %#ok<AGROW>
        end
    end
    if isempty(terms),text=char(8709);else,text=char(strjoin(terms,' + '));end
end

function text=scalarText(value)
    if isempty(value),text='';elseif isnumeric(value),text=num2str(value,17);else,text=char(string(value));end
end

function value=textScalar(text)
    if isempty(text)||strlength(string(text))==0,value=[];else,value=str2double(text);end
end

function setDropdownValue(control,value)
    if any(strcmp(control.Items,char(string(value)))),control.Value=char(string(value));end
end
