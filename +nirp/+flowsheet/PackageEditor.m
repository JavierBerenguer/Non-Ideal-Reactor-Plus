classdef PackageEditor < handle
%PACKAGEEDITOR Graphical editor for version-1 NIRP packages.
%   ED = nirp.flowsheet.PackageEditor('Visible','off') creates an editor
%   that can also be driven by scripts through its public tables.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
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
        ExampleDropDown
        StatusLabel
    end

    properties (Access = private)
        PackageName = "NIRP package"
        Mode = "new"
        Model = ""
        ComponentTab
        ReactionTab
        FeedTab
    end

    methods
        function obj = PackageEditor(varargin)
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
                reactionData{i,nComp+10} = obj.reverseQuantity(kinetic,'unit') ;
                reactionData{i,nComp+11} = obj.reverseOrders(kinetic) ;
                reactionData{i,nComp+12} = char(string(kinetic.expression)) ;
            end
            obj.ReactionTable.Data = reactionData ;
            obj.ConcentrationUnitDropDown.Value = char(string( ...
                pkg.reactions.rateUnits.concentration)) ;
            obj.TimeUnitDropDown.Value = char(string(pkg.reactions.rateUnits.time)) ;
            obj.TrefField.Value = pkg.reactions.Tref.value ;
            obj.TrefUnitDropDown.Value = obj.temperatureUnit(pkg.reactions.Tref.unit) ;
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
            if numel(unique(dhUnits)) > 1
                error('nirp:flowsheet:inconsistentUnits', ...
                    'All reaction DH values must use the same unit.') ;
            end
            pkg.meta = struct('formatVersion',1,'name',obj.PackageName) ;
            pkg.components = components ;
            pkg.reactions.stoich = cell2mat(reactionData(:,1:nComp)) ;
            pkg.reactions.DH = struct('value',cell2mat( ...
                reactionData(:,nComp+1))','unit',dhUnits(1)) ;
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
        end

        function changed = saveToModel(obj,model)
            if nargin < 2 || strlength(string(model)) == 0, model = obj.Model ; end
            oldPkg = nirp.pkg.readDictionary(obj.dictionaryPath(model)) ;
            pkg = obj.getPackage() ;
            nirp.pkg.validate(pkg) ;
            changed = numel(oldPkg.components) ~= numel(pkg.components) ;
            nirp.pkg.writeDictionary(pkg,obj.dictionaryPath(model)) ;
            if changed
                obj.StatusLabel.Text = ['Package saved. The component count changed; ' ...
                    'NirpStream was regenerated. Run the model again.'] ;
            else
                obj.StatusLabel.Text = 'Package saved to model.' ;
            end
        end
    end

    methods (Static)
        function obj = openForModel(model)
            obj = nirp.flowsheet.PackageEditor('Mode','edit','Model',model) ;
        end
    end

    methods (Access = private)
        function buildUi(obj,visible)
            obj.Figure = uifigure('Name','NIRP Package Editor', ...
                'Tag','NirpPackageEditor','Position',[100 100 1260 720], ...
                'Visible',visible) ;
            main = uigridlayout(obj.Figure,[3 1]) ;
            main.RowHeight = {'1x',42,30} ;
            tabs = uitabgroup(main) ;
            obj.ComponentTab = uitab(tabs,'Title','Components') ;
            obj.ReactionTab = uitab(tabs,'Title','Reactions') ;
            obj.FeedTab = uitab(tabs,'Title','Feeds') ;
            obj.buildComponents() ; obj.buildReactions() ; obj.buildFeeds() ;
            controls = uigridlayout(main,[1 8]) ;
            controls.Padding = [10 4 10 4] ;
            controls.ColumnWidth = {115,180,90,'1x',115,115,115,115} ;
            uilabel(controls,'Text','Example') ;
            obj.ExampleDropDown = uidropdown(controls,'Items', ...
                {'firstOrderLiquid','problem40Gas'}) ;
            uibutton(controls,'Text','Load example','ButtonPushedFcn', ...
                @(~,~) obj.loadExample()) ;
            uilabel(controls,'Text','') ;
            uibutton(controls,'Text','Validate','ButtonPushedFcn', ...
                @(~,~) obj.validate()) ;
            if obj.Mode == "edit"
                uibutton(controls,'Text','Save to model','ButtonPushedFcn', ...
                    @(~,~) obj.saveToModel()) ;
            else
                uibutton(controls,'Text','Create flowsheet...','ButtonPushedFcn', ...
                    @(~,~) obj.createInteractive()) ;
            end
            obj.StatusLabel = uilabel(main,'Text','Ready.','FontAngle','italic') ;
        end

        function buildComponents(obj)
            layout = uigridlayout(obj.ComponentTab,[2 1]) ;
            layout.RowHeight = {'1x',32} ;
            obj.ComponentTable = uitable(layout,'ColumnName', ...
                {'Name','Mw (g/mol)','Cp type','Cp','Cp unit'}, ...
                'ColumnEditable',true(1,5),'ColumnFormat', ...
                {'char','numeric',{'constant','polynomial'},'char', ...
                UnitConverterHelper.getUnits('MolarHeatCapacity')}, ...
                'CellEditCallback',@(~,event) obj.componentEdited(event)) ;
            buttons = uigridlayout(layout,[1 3]) ; buttons.ColumnWidth={80,80,'1x'} ;
            buttons.Padding = [0 0 0 0] ;
            uibutton(buttons,'Text','Add','ButtonPushedFcn',@(~,~) obj.addComponent()) ;
            uibutton(buttons,'Text','Remove','ButtonPushedFcn',@(~,~) obj.removeLast('component')) ;
        end

        function buildReactions(obj)
            layout = uigridlayout(obj.ReactionTab,[3 1]) ;
            layout.RowHeight = {34,'1x',32} ;
            header = uigridlayout(layout,[1 7]) ;
            header.Padding = [0 0 0 0] ;
            uilabel(header,'Text','Concentration unit') ;
            obj.ConcentrationUnitDropDown = uidropdown(header,'Items', ...
                UnitConverterHelper.getUnits('Concentration')) ;
            uilabel(header,'Text','Time unit') ;
            obj.TimeUnitDropDown = uidropdown(header,'Items', ...
                UnitConverterHelper.getUnits('Time')) ;
            uilabel(header,'Text','Tref') ;
            obj.TrefField = uieditfield(header,'numeric') ;
            obj.TrefUnitDropDown = uidropdown(header,'Items',{'K',[char(176) 'C']}) ;
            obj.ReactionTable = uitable(layout,'ColumnEditable',true) ;
            buttons = uigridlayout(layout,[1 3]) ; buttons.ColumnWidth={80,80,'1x'} ;
            buttons.Padding = [0 0 0 0] ;
            uibutton(buttons,'Text','Add','ButtonPushedFcn',@(~,~) obj.addReaction()) ;
            uibutton(buttons,'Text','Remove','ButtonPushedFcn',@(~,~) obj.removeLast('reaction')) ;
        end

        function buildFeeds(obj)
            layout = uigridlayout(obj.FeedTab,[2 1]) ; layout.RowHeight={'1x',32} ;
            valueUnits = unique([UnitConverterHelper.getUnits('MolarFlow'), ...
                UnitConverterHelper.getUnits('Concentration')],'stable') ;
            obj.FeedTable = uitable(layout,'ColumnName',{'Name','Phase','T', ...
                'T unit','P','P unit','Basis','Values','Values unit','Q','Q unit'}, ...
                'ColumnEditable',true(1,11),'ColumnFormat',{'char',{'L','G'}, ...
                'numeric',{'K',[char(176) 'C']},'numeric', ...
                UnitConverterHelper.getUnits('Pressure'), ...
                {'molarFlows','concentrations','totalAndFractions'},'char',valueUnits, ...
                'numeric',UnitConverterHelper.getUnits('VolumetricFlow')}, ...
                'CellEditCallback',@(~,event) obj.feedEdited(event)) ;
            buttons = uigridlayout(layout,[1 3]) ; buttons.ColumnWidth={80,80,'1x'} ;
            buttons.Padding = [0 0 0 0] ;
            uibutton(buttons,'Text','Add','ButtonPushedFcn',@(~,~) obj.addFeed()) ;
            uibutton(buttons,'Text','Remove','ButtonPushedFcn',@(~,~) obj.removeLast('feed')) ;
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
        end

        function addReaction(obj)
            nComp = size(obj.ComponentTable.Data,1) ;
            row = [num2cell(zeros(1,nComp)),{0,'J/mol','powerlaw',1,0, ...
                'J/mol',obj.vectorText(zeros(1,nComp)),[],[], ...
                'J/mol','', ''}] ;
            data = obj.ReactionTable.Data ; data(end+1,:) = row ; obj.ReactionTable.Data=data ;
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
        end

        function loadExample(obj)
            obj.setPackage(feval(['nirp.pkg.examples.' obj.ExampleDropDown.Value])) ;
        end

        function createInteractive(obj)
            answer=inputdlg('Model name:','New NIRP flowsheet',1,{'nirp_flowsheet'}) ;
            if isempty(answer), return, end
            folder=uigetdir(pwd,'Select a folder for the flowsheet') ;
            if isequal(folder,0), return, end
            obj.createFlowsheet(strtrim(answer{1}),folder) ;
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
            else, value=nirp.flowsheet.PackageEditor.requiredScalar(input) ; end
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
            if isempty(k.reverse), value='' ; else, value=nirp.flowsheet.PackageEditor.vectorText(k.reverse.orders) ; end
        end
        function unit = temperatureUnit(unit)
            unit=char(string(unit)) ; if strcmp(unit,'C'), unit=[char(176) 'C']; end
        end
        function unit = packageTemperatureUnit(unit)
            unit=char(string(unit)) ; if strcmp(unit,[char(176) 'C']), unit='C'; end
        end
    end
end
