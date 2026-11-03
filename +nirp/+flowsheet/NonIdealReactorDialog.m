classdef NonIdealReactorDialog < handle
%NONIDEALREACTORDIALOG Structured editor for Non-ideal Reactor blocks.
% =========================================================================
% Javier Berenguer Sabater
% Created: November 3, 2026. Last update: November 4, 2026
% =========================================================================
    properties (SetAccess=private)
        BlockPath; Figure; NameField; StatusLabel; DataModel
        OriginDropDown; ModelDropDown; NField; NLabel; PeField; PeLabel
        BoundaryDropDown; BoundaryLabel
        DataTable; DataTimeUnitDropDown; SessionField; RTDAxes
        AddRowButton; RemoveRowButton; ImportButton; BrowseButton
        VField; VUnitDropDown; TauField; TauUnitDropDown
        SpaceVelocityField; SpaceVelocityUnitDropDown
        MicromixingDropDown; MicromixingDescription
        TemperatureModeDropDown; TemperatureField; TemperatureUnitDropDown
        ReactionsTable; HeatPortCheckBox; ResultsTable
    end
    properties (Access=private)
        DofOrigins=struct('V',"empty",'tau',"empty",'SV',"empty",'N',"empty",'Pe',"empty")
        Updating=false
        LastDof=[]
        RtdModelPanel; DataPanel; SessionPanel; TemperatureLabel
    end
    methods
        function obj=NonIdealReactorDialog(blockPath,varargin)
            p=inputParser;addParameter(p,'Visible','on');parse(p,varargin{:});
            obj.BlockPath=getfullname(blockPath);
            if string(get_param(obj.BlockPath,'System'))~="nirp.blocks.NonIdealReactor"
                error('nirp:flowsheet:invalidBlock', ...
                    'NonIdealReactorDialog requires a Non-ideal Reactor block.');
            end
            try,mask=Simulink.Mask.get(obj.BlockPath);parameter=mask.getParameter('Specifications');if ~isempty(parameter),parameter.Visible='off';end,catch,end
            obj.build(char(string(p.Results.Visible)));
            nirp.flowsheet.internal.formatNumericControls(obj.Figure);
            obj.load();obj.configurationChanged();
        end
        function delete(obj),if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure);end,end
        function values=getValues(obj),obj.closeDof();obj.captureModel();values=obj.DataModel;end
        function setValues(obj,varargin)
            if numel(varargin)==1&&isstruct(varargin{1}),s=varargin{1};n=fieldnames(s);args=cell(1,2*numel(n));for i=1:numel(n),args(2*i-1:2*i)={n{i},s.(n{i})};end
            else,args=varargin;end
            for i=1:2:numel(args),obj.setOne(args{i},args{i+1});end
            obj.configurationChanged();
        end
        function addDataRow(obj)
            data=obj.DataTable.Data;if isempty(data),data=zeros(0,2);end
            obj.DataTable.Data=[data;NaN NaN];obj.refreshRtdPlot();obj.closeDof();
        end
        function removeDataRow(obj)
            data=obj.DataTable.Data;if ~isempty(data),data(end,:)=[];obj.DataTable.Data=data;end
            obj.refreshRtdPlot();obj.closeDof();
        end
        function importData(obj,path)
            data=nirp.tracerflowsheet.readTwoColumnFile(path,'RTD');
            obj.DataTable.Data=data;obj.OriginDropDown.Value='Data';
            obj.configurationChanged();
        end
        function selectSession(obj,path)
            obj.SessionField.Value=char(string(path));obj.OriginDropDown.Value='Session';
            obj.configurationChanged();
        end
        function applied=apply(obj)
            applied=false;
            try
                result=obj.closeDof();if strcmp(result.status,'conflict'),return,end
                name=strtrim(obj.NameField.Value);if isempty(name),error('nirp:flowsheet:invalidName','Name cannot be empty.');end
                data=cleanData(obj.DataTable.Data);
                values={'RTDOrigin',obj.OriginDropDown.Value,'Model',obj.ModelDropDown.Value, ...
                    'SizeBasis',sizeBasis(obj.DofOrigins),'SizeSource','Dialog', ...
                    'V',numberText(obj.VField.Value),'VUnit',obj.VUnitDropDown.Value, ...
                    'Tau',numberText(obj.TauField.Value),'TauUnit',obj.TauUnitDropDown.Value, ...
                    'N',numberText(obj.NField.Value),'Pe',numberText(obj.PeField.Value), ...
                    'Boundary',obj.BoundaryDropDown.Value,'DataTime',mat2str(data(:,1).',17), ...
                    'DataE',mat2str(data(:,2).',17),'DataTimeUnit',obj.DataTimeUnitDropDown.Value, ...
                    'SessionFile',obj.SessionField.Value,'Micromixing',obj.MicromixingDropDown.Value, ...
                    'TemperatureMode',obj.TemperatureModeDropDown.Value, ...
                    'SpecifiedT',numberText(obj.TemperatureField.Value), ...
                    'SpecifiedTUnit',obj.TemperatureUnitDropDown.Value, ...
                    'Reactions',obj.selectedReactions(),'ShowHeatPort',onoff(obj.HeatPortCheckBox.Value)};
                set_param(obj.BlockPath,values{:});
                nirp.dof.writeSpecs(obj.BlockPath,obj.makeSpecs(result));
                if ~strcmp(name,get_param(obj.BlockPath,'Name'))
                    model=bdroot(obj.BlockPath);set_param(obj.BlockPath,'Name',name);obj.BlockPath=getfullname([model '/' name]);
                end
                obj.captureModel();nirp.flowsheet.afterApply(bdroot(obj.BlockPath),obj.StatusLabel);
                obj.refreshResults();obj.closeDof();applied=true;
            catch exception
                obj.StatusLabel.Text=erase(exception.message,newline);
            end
        end
        function accept(obj),if obj.apply(),delete(obj);else,nirp.flowsheet.internal.showDialogError(obj.Figure,obj.StatusLabel.Text,'Non-ideal Reactor');end,end
        function cancel(obj),delete(obj);end
    end
    methods (Static)
        function dialog=open(blockPath)
            if nirp.flowsheet.openLibraryBlockGuide(blockPath),dialog=[];return,end
            dialog=nirp.flowsheet.NonIdealReactorDialog(blockPath);
        end
    end
    methods (Access=private)
        function build(obj,visible)
            obj.Figure=uifigure('Name','Non-ideal Reactor','Tag','NirpNonIdealReactorDialog', ...
                'Visible',visible,'Position',[70 30 960 720],'WindowStyle','alwaysontop');
            main=uigridlayout(obj.Figure,[4 1],'RowHeight',{40,'1x',34,38},'Padding',[12 10 12 10]);
            head=uigridlayout(main,[1 4],'ColumnWidth',{160,60,'1x',180});
            uibutton(head,'Text','Unit conversion helper','ButtonPushedFcn',@(~,~)UnitConverterHelper.launch());
            uilabel(head,'Text','Name','HorizontalAlignment','right');obj.NameField=uieditfield(head,'text');
            tabs=uitabgroup(main);rtdTab=uitab(tabs,'Title','Residence time distribution');
            operationTab=uitab(tabs,'Title','Size and operation');reactionsTab=uitab(tabs,'Title','Reactions');resultsTab=uitab(tabs,'Title','Results');
            obj.buildRtdTab(rtdTab);obj.buildOperationTab(operationTab);obj.buildReactionsTab(reactionsTab);obj.buildResultsTab(resultsTab);
            obj.StatusLabel=uilabel(main,'Text','Ready.','FontAngle','italic','WordWrap','on');
            buttons=uigridlayout(main,[1 5],'ColumnWidth',{'1x',70,90,90,90});uilabel(buttons,'Text','');
            uibutton(buttons,'Text','Help','ButtonPushedFcn',@(~,~)openNirpGuide('guides/flowsheet-nonideal-reactor.html#non-ideal-reactor'));
            uibutton(buttons,'Text','OK','ButtonPushedFcn',@(~,~)obj.accept());
            uibutton(buttons,'Text','Cancel','ButtonPushedFcn',@(~,~)obj.cancel());
            uibutton(buttons,'Text','Apply','ButtonPushedFcn',@(~,~)obj.apply());
        end
        function buildRtdTab(obj,parent)
            grid=uigridlayout(parent,[2 2],'RowHeight',{40,'1x'},'ColumnWidth',{'1x',330});
            top=uigridlayout(grid,[1 4],'ColumnWidth',{80,180,80,'1x'});top.Layout.Column=[1 2];
            uilabel(top,'Text','Origin','HorizontalAlignment','right');
            obj.OriginDropDown=uidropdown(top,'Items',{'Select...','Model','Data','Session'});
            obj.OriginDropDown.ValueChangedFcn=@(~,~)obj.configurationChanged();
            obj.RtdModelPanel=uipanel(grid,'Title','Analytical model');obj.RtdModelPanel.Layout.Row=2;obj.RtdModelPanel.Layout.Column=1;
            g=uigridlayout(obj.RtdModelPanel,[4 3],'ColumnWidth',{145,'1x',100},'RowHeight',repmat({34},1,4));
            obj.ModelDropDown=dropRow(g,1,'Model',{'Select...','CSTR','PFR','Tanks in series','Dispersion'});
            obj.ModelDropDown.ValueChangedFcn=@(~,~)obj.configurationChanged();[obj.NField,obj.NLabel]=numericRow(g,2,'Number of tanks');
            [obj.PeField,obj.PeLabel]=numericRow(g,3,'Peclet number');[obj.BoundaryDropDown,obj.BoundaryLabel]=dropRow(g,4,'Boundary',{'open','closed'});obj.BoundaryDropDown.ValueChangedFcn=@(~,~)obj.configurationChanged();
            obj.DataPanel=uipanel(grid,'Title','Tabulated t-E data');obj.DataPanel.Layout.Row=2;obj.DataPanel.Layout.Column=1;
            dg=uigridlayout(obj.DataPanel,[2 4],'RowHeight',{'1x',34},'ColumnWidth',{'1x',95,95,110});
            obj.DataTable=uitable(dg,'Data',zeros(0,2),'ColumnName',{'t','E(t)'},'ColumnEditable',[true true],'RowName',{});
            obj.DataTable.Layout.Column=[1 4];obj.DataTable.CellEditCallback=@(~,~)obj.dataEdited();
            obj.AddRowButton=uibutton(dg,'Text','Add row','ButtonPushedFcn',@(~,~)obj.addDataRow());
            obj.RemoveRowButton=uibutton(dg,'Text','Remove','ButtonPushedFcn',@(~,~)obj.removeDataRow());
            obj.ImportButton=uibutton(dg,'Text','Import...','ButtonPushedFcn',@(~,~)obj.chooseImport());
            obj.DataTimeUnitDropDown=uidropdown(dg,'Items',{'s','min','h'},'ValueChangedFcn',@(~,~)obj.configurationChanged());
            obj.SessionPanel=uipanel(grid,'Title','Saved app session');obj.SessionPanel.Layout.Row=2;obj.SessionPanel.Layout.Column=1;
            sg=uigridlayout(obj.SessionPanel,[2 2],'RowHeight',{34,'1x'},'ColumnWidth',{'1x',100});
            obj.SessionField=uieditfield(sg,'text','ValueChangedFcn',@(~,~)obj.configurationChanged());
            obj.BrowseButton=uibutton(sg,'Text','Browse...','ButtonPushedFcn',@(~,~)obj.chooseSession());
            obj.RTDAxes=uiaxes(grid);obj.RTDAxes.Layout.Row=2;obj.RTDAxes.Layout.Column=2;
            title(obj.RTDAxes,'Normalised E(t)');xlabel(obj.RTDAxes,'t');ylabel(obj.RTDAxes,'E(t)');obj.RTDAxes.XGrid='on';obj.RTDAxes.YGrid='on';
        end
        function buildOperationTab(obj,parent)
            outer=uigridlayout(parent,[4 1],'RowHeight',{130,100,105,'1x'});
            sizePanel=uipanel(outer,'Title','Size');g=uigridlayout(sizePanel,[3 6],'ColumnWidth',{120,110,80,120,110,80});
            [obj.VField,obj.VUnitDropDown]=quantity(g,1,1,'Volume','Volume');
            [obj.TauField,obj.TauUnitDropDown]=quantity(g,2,1,'Residence time','Time');
            [obj.SpaceVelocityField,obj.SpaceVelocityUnitDropDown]=quantity(g,3,1,'Space velocity','TimeInverse');
            controls={obj.VField,'V';obj.TauField,'tau';obj.SpaceVelocityField,'SV';obj.NField,'N';obj.PeField,'Pe'};
            for i=1:size(controls,1),controls{i,1}.ValueChangedFcn=@(~,event)obj.dofEdited(controls{i,2},event);end
            for control={obj.VUnitDropDown,obj.TauUnitDropDown,obj.SpaceVelocityUnitDropDown},control{1}.ValueChangedFcn=@(~,~)obj.configurationChanged();end
            mixPanel=uipanel(outer,'Title','Micromixing');g=uigridlayout(mixPanel,[2 2],'ColumnWidth',{160,'1x'});
            uilabel(g,'Text','Model','HorizontalAlignment','right');obj.MicromixingDropDown=uidropdown(g,'Items',{'Select...','Segregation','Maximum mixedness'});
            obj.MicromixingDropDown.ValueChangedFcn=@(~,~)obj.micromixingChanged();
            obj.MicromixingDescription=uilabel(g,'Text','','FontAngle','italic');obj.MicromixingDescription.Layout.Row=2;obj.MicromixingDescription.Layout.Column=[1 2];
            tempPanel=uipanel(outer,'Title','Temperature');g=uigridlayout(tempPanel,[2 6],'ColumnWidth',{100,150,100,120,100,'1x'});
            obj.TemperatureModeDropDown=dropRow(g,1,'Mode',{'Inlet','Specified'});obj.TemperatureModeDropDown.ValueChangedFcn=@(~,~)obj.configurationChanged();
            [obj.TemperatureField,obj.TemperatureUnitDropDown,obj.TemperatureLabel]=quantity(g,1,4,'Value','Temperature');
            note=uilabel(g,'Text','Isothermal liquid; the heat duty keeps the reactor at this temperature.','FontAngle','italic');note.Layout.Row=2;note.Layout.Column=[1 6];
            obj.HeatPortCheckBox=uicheckbox(outer,'Text','Show heat port');
        end
        function buildReactionsTab(obj,parent)
            g=uigridlayout(parent,[2 1],'RowHeight',{30,'1x'});uilabel(g,'Text','Reactions that take place in this reactor (all by default)','FontWeight','bold');
            obj.ReactionsTable=uitable(g,'ColumnName',{'Use','Reaction'},'ColumnEditable',[true false],'ColumnWidth',{50,'auto'},'RowName',{});
        end
        function buildResultsTab(obj,parent)
            g=uigridlayout(parent,[2 1],'RowHeight',{30,'1x'});uilabel(g,'Text','Latest calculation','FontWeight','bold');
            obj.ResultsTable=uitable(g,'ColumnName',{'Result','Value'},'ColumnEditable',[false false],'RowName',{});
        end
        function load(obj)
            obj.NameField.Value=get_param(obj.BlockPath,'Name');obj.OriginDropDown.Value=get_param(obj.BlockPath,'RTDOrigin');
            obj.ModelDropDown.Value=get_param(obj.BlockPath,'Model');obj.BoundaryDropDown.Value=get_param(obj.BlockPath,'Boundary');
            setNumeric(obj.NField,get_param(obj.BlockPath,'N'));setNumeric(obj.PeField,get_param(obj.BlockPath,'Pe'));
            obj.DataTimeUnitDropDown.Value=get_param(obj.BlockPath,'DataTimeUnit');
            t=numericParameter(obj.BlockPath,'DataTime');e=numericParameter(obj.BlockPath,'DataE');
            if numel(t)==numel(e)&&~all(isnan(t))&&~all(isnan(e)),obj.DataTable.Data=[t(:) e(:)];end
            obj.SessionField.Value=get_param(obj.BlockPath,'SessionFile');
            obj.VUnitDropDown.Value=get_param(obj.BlockPath,'VUnit');obj.TauUnitDropDown.Value=get_param(obj.BlockPath,'TauUnit');
            setNumeric(obj.VField,get_param(obj.BlockPath,'V'));setNumeric(obj.TauField,get_param(obj.BlockPath,'Tau'));
            obj.SpaceVelocityUnitDropDown.Value='1/s';obj.MicromixingDropDown.Value=get_param(obj.BlockPath,'Micromixing');
            obj.TemperatureModeDropDown.Value=get_param(obj.BlockPath,'TemperatureMode');obj.TemperatureUnitDropDown.Value=get_param(obj.BlockPath,'SpecifiedTUnit');
            setNumeric(obj.TemperatureField,get_param(obj.BlockPath,'SpecifiedT'));obj.HeatPortCheckBox.Value=ison(get_param(obj.BlockPath,'ShowHeatPort'));
            obj.loadReactions();specText=get_param(obj.BlockPath,'Specifications');
            if isempty(strtrim(specText)),obj.loadLegacyOrigins();else,obj.loadSpecifications(nirp.dof.readSpecs(specText));end
            obj.micromixingChanged();obj.refreshResults();
        end
        function configurationChanged(obj)
            origin=string(obj.OriginDropDown.Value);obj.RtdModelPanel.Visible=onoff(origin=="Model");obj.DataPanel.Visible=onoff(origin=="Data");obj.SessionPanel.Visible=onoff(origin=="Session");
            obj.NField.Visible=onoff(origin=="Model"&&strcmp(obj.ModelDropDown.Value,'Tanks in series'));obj.NLabel.Visible=obj.NField.Visible;
            obj.PeField.Visible=onoff(origin=="Model"&&strcmp(obj.ModelDropDown.Value,'Dispersion'));obj.PeLabel.Visible=obj.PeField.Visible;
            obj.BoundaryDropDown.Visible=obj.PeField.Visible;obj.BoundaryLabel.Visible=obj.PeField.Visible;
            specified=strcmp(obj.TemperatureModeDropDown.Value,'Specified');obj.TemperatureField.Visible=onoff(specified);obj.TemperatureUnitDropDown.Visible=onoff(specified);obj.TemperatureLabel.Visible=onoff(specified);
            obj.refreshRtdPlot();obj.closeDof();obj.captureModel();
        end
        function result=closeDof(obj)
            if obj.Updating,result=emptyResult('missing');return,end
            obj.Updating=true;cleanup=onCleanup(@()obj.finishUpdate());
            origin=lower(string(obj.OriginDropDown.Value));modelName=string(obj.ModelDropDown.Value);
            values=struct();origins=struct('Q0','external');[inlet,source]=nirp.dof.knownInlet(obj.BlockPath);
            if isempty(inlet),values.Q0=NaN;else,values.Q0=inlet.Q;end
            context=struct('origin',char(origin),'model',char(modelName));externalTau=NaN;
            if any(origin==["data" "session"])
                try,descriptor=nirp.tracer.rtdDescriptor(obj.rtdSpec(),[]);externalTau=descriptor.tau;values.tau=externalTau;origins.tau='external';catch exception,result=emptyResult('missing');result.messages=string(exception.message);obj.LastDof=result;obj.showStatus(result,source,false);obj.captureModel();return,end
            end
            catalogue=nirp.dof.catalog.nonIdealReactor(context);names={catalogue.variables.name};
            for i=1:numel(names),name=names{i};if any(strcmp(name,{'Q0','tau'}))&&isfield(origins,name),continue,end
                if isfield(obj.DofOrigins,name)&&obj.DofOrigins.(name)=="specified",values.(name)=obj.toSI(name);origins.(name)='specified';end
            end
            result=nirp.dof.solve(catalogue,values,origins);
            if any(origin==["data" "session"]),result=obj.measuredConflicts(result,externalTau,values.Q0);end
            if isfield(result.values,'N')&&isfinite(result.values.N)&&abs(result.values.N-round(result.values.N))>1e-9,result=forceConflict(result,'N','Number of tanks must be an integer.');end
            required=obj.requiredConfiguration();if ~isempty(required)&&~strcmp(result.status,'conflict'),result.status='missing';result.missing=required;result.missingCount=numel(required);result.messages=string(sprintf('%d specification(s) missing: %s.',numel(required),char(strjoin(required,', '))));end
            if isempty(inlet)&&strcmp(result.status,'complete'),result.status='pending';result.messages="Closed, waiting for the inlet stream.";end
            for name={'V','tau','SV','N','Pe'},key=name{1};if isfield(result.values,key)&&isfield(obj.DofOrigins,key),obj.DofOrigins.(key)=string(result.origins.(key));obj.setCalculated(key,result.values.(key),result.origins.(key));styleDof(obj.field(key),result.states.(key),strjoin(result.messages,' '));end,end
            obj.LastDof=result;obj.showStatus(result,source,isempty(inlet));obj.captureModel();
        end
        function result=measuredConflicts(obj,result,tau,Q)
            expected=struct('tau',tau,'SV',1/tau,'V',tau*Q,'Q0',Q);
            result.values=expected;result.status='complete';result.conflicts=strings(0,1);result.messages=strings(0,1);
            result.origins=struct('V','calculated','tau','external','SV','calculated','Q0','external');
            result.states=result.origins;
            for name={'tau','SV','V'},key=name{1};if obj.DofOrigins.(key)~="specified",continue,end
                result.origins.(key)='specified';result.states.(key)='specified';
                if key=="V"&&~isfinite(Q),continue,end
                actual=obj.toSI(key);if relative(actual,expected.(key))>1e-6,result=forceConflict(result,key,'Specified size conflicts with the measured RTD mean.');end
            end
            if ~isfinite(Q)&&~strcmp(result.status,'conflict'),result.status='pending';result.messages="Closed, waiting for the inlet stream.";end
        end
        function showStatus(obj,result,source,pending)
            if nargin<4,pending=false;end
            if strcmp(result.status,'conflict'),message="Conflict: "+strjoin(result.messages,' ');
            elseif strcmp(result.status,'missing'),if isempty(result.messages),message="Select the RTD and its required specifications.";else,message=result.messages(end);end
            elseif pending,message="Closed, waiting for the inlet stream.";
            elseif strcmp(result.status,'complete'),message="Fully specified";if strlength(source)>0,message=message+" - "+source;end
            else,message=result.messages(end);end
            [~,~,runLabel]=nirp.flowsheet.blockStatus(obj.BlockPath);message=message+" - "+runLabel;
            nirp.flowsheet.internal.paintDofStatus(obj.StatusLabel,result.status,message);
        end
        function missing=requiredConfiguration(obj)
            missing=strings(0,1);origin=string(obj.OriginDropDown.Value);
            if origin=="Select...",missing(end+1)="RTD origin";end
            if origin=="Model"&&strcmp(obj.ModelDropDown.Value,'Select...'),missing(end+1)="RTD model";end
            if strcmp(obj.MicromixingDropDown.Value,'Select...'),missing(end+1)="micromixing model";end
            if strcmp(obj.TemperatureModeDropDown.Value,'Specified')&&~isfinite(fieldNumber(obj.TemperatureField)),missing(end+1)="temperature";end
        end
        function spec=rtdSpec(obj)
            origin=lower(string(obj.OriginDropDown.Value));spec=struct('origin',char(origin));
            if origin=="model"
                spec.model=modelCode(obj.ModelDropDown.Value);tau=obj.toSI('tau');V=obj.toSI('V');
                if isfinite(tau),spec.tau=tau;elseif isfinite(V),[inlet,~]=nirp.dof.knownInlet(obj.BlockPath);if ~isempty(inlet),spec.V=V;end,end
                if strcmp(obj.ModelDropDown.Value,'Tanks in series'),spec.N=fieldNumber(obj.NField);end
                if strcmp(obj.ModelDropDown.Value,'Dispersion'),spec.Pe=fieldNumber(obj.PeField);spec.boundary=obj.BoundaryDropDown.Value;end
            elseif origin=="data"
                data=cleanData(obj.DataTable.Data);factor=timeFactor(obj.DataTimeUnitDropDown.Value);spec.t=data(:,1).'*factor;spec.E=data(:,2).'/factor;
            elseif origin=="session",spec.file=resolveSessionFile(obj.BlockPath,obj.SessionField.Value);end
        end
        function refreshRtdPlot(obj)
            if isempty(obj.RTDAxes)||~isvalid(obj.RTDAxes),return,end
            cla(obj.RTDAxes);try,d=nirp.tracer.rtdDescriptor(obj.rtdSpec(),[]);area=trapz(d.t,d.E);if area<=0,return,end
                plot(obj.RTDAxes,d.t,d.E/area,'Color',[0.1 0.45 0.75],'LineWidth',1.3);hold(obj.RTDAxes,'on');xline(obj.RTDAxes,d.tau,'--','Mean','Color',[0.8 0.25 0.1]);hold(obj.RTDAxes,'off');
            catch
            end
        end
        function refreshResults(obj)
            rows=cell(0,2);try
                key=matlab.lang.makeValidName([bdroot(obj.BlockPath) '_' get_param(obj.BlockPath,'Name')]);
                if evalin('base','exist(''nirpResults'',''var'')'),allResults=evalin('base','nirpResults');if isfield(allResults,'Diagnostics')&&isfield(allResults.Diagnostics,key),item=allResults.Diagnostics.(key);if isfield(item,'lastInfo'),info=item.lastInfo;rows=resultRows(info);end,end,end
            catch
            end
            obj.ResultsTable.Data=rows;
        end
        function specs=makeSpecs(obj,result)
            specs=struct();for name={'V','tau','SV','N','Pe'},key=name{1};if isfield(result.values,key)&&obj.DofOrigins.(key)=="specified",specs.(key)=struct('si',obj.toSI(key),'unit',obj.unit(key));end,end
        end
        function value=toSI(obj,name)
            value=fieldNumber(obj.field(name));if ~isfinite(value),return,end;unit=obj.unit(name);
            switch name,case 'V',value=UnitConverterHelper.convertToSI('Volume',value,unit);case 'tau',value=UnitConverterHelper.convertToSI('Time',value,unit);case 'SV',value=UnitConverterHelper.convertToSI('TimeInverse',value,unit);end
        end
        function setCalculated(obj,name,value,origin)
            if strcmp(origin,'specified')||~isfinite(value),return,end
            unit=obj.unit(name);switch name,case 'V',value=UnitConverterHelper.convertFromSI('Volume',value,unit);case 'tau',value=UnitConverterHelper.convertFromSI('Time',value,unit);case 'SV',value=UnitConverterHelper.convertFromSI('TimeInverse',value,unit);end
            obj.field(name).Value=value;
        end
        function field=field(obj,name),map=struct('V','VField','tau','TauField','SV','SpaceVelocityField','N','NField','Pe','PeField');field=obj.(map.(name));end
        function value=unit(obj,name),map=struct('V','VUnitDropDown','tau','TauUnitDropDown','SV','SpaceVelocityUnitDropDown');if isfield(map,name),value=obj.(map.(name)).Value;else,value='1';end,end
        function loadLegacyOrigins(obj)
            if isfinite(fieldNumber(obj.VField)),obj.DofOrigins.V="specified";elseif isfinite(fieldNumber(obj.TauField)),obj.DofOrigins.tau="specified";end
            if isfinite(fieldNumber(obj.NField)),obj.DofOrigins.N="specified";end;if isfinite(fieldNumber(obj.PeField)),obj.DofOrigins.Pe="specified";end
        end
        function loadSpecifications(obj,specs)
            names=fieldnames(specs);for i=1:numel(names),name=names{i};if ~isfield(obj.DofOrigins,name),continue,end;obj.fromSI(name,specs.(name).si,specs.(name).unit);obj.DofOrigins.(name)="specified";end
        end
        function fromSI(obj,name,value,unit)
            if any(strcmp(name,{'V','tau','SV'}))&&~isempty(unit),drop=obj.unitField(name);if any(string(drop.Items)==string(unit)),drop.Value=unit;end,end
            switch name,case 'V',value=UnitConverterHelper.convertFromSI('Volume',value,obj.unit(name));case 'tau',value=UnitConverterHelper.convertFromSI('Time',value,obj.unit(name));case 'SV',value=UnitConverterHelper.convertFromSI('TimeInverse',value,obj.unit(name));end;obj.field(name).Value=value;
        end
        function drop=unitField(obj,name),map=struct('V','VUnitDropDown','tau','TauUnitDropDown','SV','SpaceVelocityUnitDropDown');drop=obj.(map.(name));end
        function dofEdited(obj,name,event),if obj.Updating,return,end;value=eventValue(event);if isempty(value)||~isfinite(value),obj.DofOrigins.(name)="empty";else,obj.DofOrigins.(name)="specified";end;obj.refreshRtdPlot();obj.closeDof();end
        function dataEdited(obj),obj.refreshRtdPlot();obj.closeDof();end
        function finishUpdate(obj),obj.Updating=false;end
        function micromixingChanged(obj)
            if strcmp(obj.MicromixingDropDown.Value,'Segregation'),obj.MicromixingDescription.Text='Segregated fluid elements, mixing only at the outlet.';
            elseif strcmp(obj.MicromixingDropDown.Value,'Maximum mixedness'),obj.MicromixingDescription.Text='Earliest possible mixing compatible with the RTD.';else,obj.MicromixingDescription.Text='Select a micromixing model.';end
            if ~obj.Updating,obj.closeDof();end
            obj.captureModel();
        end
        function chooseImport(obj),[file,folder]=uigetfile({'*.csv;*.txt;*.dat;*.xlsx','Two-column data'},'Import RTD data');if isequal(file,0),return,end;obj.importData(fullfile(folder,file));end
        function chooseSession(obj),[file,folder]=uigetfile({'*.mat','MATLAB session'},'Select RTD session');if isequal(file,0),return,end;obj.selectSession(fullfile(folder,file));end
        function loadReactions(obj)
            try,pkg=nirp.pkg.readDictionary(nirp.flowsheet.modelDictionary(bdroot(obj.BlockPath)));catch,obj.ReactionsTable.Data=cell(0,2);return,end
            names=string({pkg.components.name});stoich=pkg.reactions.stoich;nR=size(stoich,1);try,used=nirp.pkg.reactionIndices(pkg,get_param(obj.BlockPath,'Reactions'));catch,used=1:nR;end
            data=cell(nR,2);for i=1:nR,data{i,1}=any(used==i);data{i,2}=reactionLabel(i,stoich(i,:),names);end;obj.ReactionsTable.Data=data;
        end
        function text=selectedReactions(obj),data=obj.ReactionsTable.Data;if isempty(data),text='';return,end;used=find(cell2mat(data(:,1)))';if isempty(used),error('nirp:flowsheet:noReactions','Select at least one reaction.');end;if numel(used)==size(data,1),text='';else,text=['[' char(strjoin(string(used),' ')) ']'];end,end
        function setOne(obj,name,value)
            key=lower(char(string(name)));map=struct('origin','OriginDropDown','rtdorigin','OriginDropDown','model','ModelDropDown','n','NField','pe','PeField','boundary','BoundaryDropDown','v','VField','tau','TauField','sv','SpaceVelocityField','spacevelocity','SpaceVelocityField','micromixing','MicromixingDropDown','temperaturemode','TemperatureModeDropDown','specifiedt','TemperatureField','showheatport','HeatPortCheckBox','sessionfile','SessionField');
            if strcmp(key,'data'),obj.DataTable.Data=value;return,end;if ~isfield(map,key),error('nirp:flowsheet:unknownParameter','Unknown Non-ideal Reactor parameter "%s".',name);end;control=obj.(map.(key));if isa(control,'matlab.ui.control.CheckBox'),control.Value=ison(value);elseif isprop(control,'AllowEmpty')&&isnumeric(value)&&isscalar(value)&&isnan(value),control.Value=[];else,control.Value=value;end
            dof=struct('v','V','tau','tau','sv','SV','spacevelocity','SV','n','N','pe','Pe');if isfield(dof,key),obj.DofOrigins.(dof.(key))="specified";end
        end
        function captureModel(obj)
            q=@(field,unit,origin)struct('value',field.Value,'unit',string(unit.Value),'origin',string(origin));
            obj.DataModel=struct('Origin',string(obj.OriginDropDown.Value),'Model',string(obj.ModelDropDown.Value), ...
                'V',q(obj.VField,obj.VUnitDropDown,obj.DofOrigins.V), ...
                'Tau',q(obj.TauField,obj.TauUnitDropDown,obj.DofOrigins.tau), ...
                'SpaceVelocity',q(obj.SpaceVelocityField,obj.SpaceVelocityUnitDropDown,obj.DofOrigins.SV), ...
                'Micromixing',string(obj.MicromixingDropDown.Value), ...
                'TemperatureMode',string(obj.TemperatureModeDropDown.Value), ...
                'Specifications',obj.DofOrigins,'Data',obj.DataTable.Data,'Result',obj.LastDof);
        end
    end
end

function [value,text]=dropRow(grid,row,label,items),text=uilabel(grid,'Text',label,'HorizontalAlignment','right');text.Layout.Row=row;text.Layout.Column=1;value=uidropdown(grid,'Items',items);value.Layout.Row=row;value.Layout.Column=[2 3];end
function [value,text]=numericRow(grid,row,label),text=uilabel(grid,'Text',label,'HorizontalAlignment','right');text.Layout.Row=row;text.Layout.Column=1;value=uieditfield(grid,'numeric','AllowEmpty','on','Value',[]);value.Layout.Row=row;value.Layout.Column=2;end
function [field,units,label]=quantity(grid,row,column,text,category),label=uilabel(grid,'Text',text,'HorizontalAlignment','right');label.Layout.Row=row;label.Layout.Column=column;field=uieditfield(grid,'numeric','AllowEmpty','on','Value',[]);field.Layout.Row=row;field.Layout.Column=column+1;units=uidropdown(grid,'Items',UnitConverterHelper.getUnits(category));units.Layout.Row=row;units.Layout.Column=column+2;end
function setNumeric(field,text),value=str2double(text);if isfinite(value),field.Value=value;else,field.Value=[];end,end
function value=fieldNumber(field),value=field.Value;if isempty(value),value=NaN;end,end
function value=eventValue(event),try,value=event.Value;catch,value=event.NewData;end,end
function value=numberText(value),if isempty(value)||~isfinite(value),value='NaN';else,value=num2str(value,17);end,end
function value=onoff(flag),if flag,value='on';else,value='off';end,end
function flag=ison(value),if islogical(value)||isnumeric(value),flag=logical(value);else,flag=any(strcmp(value,{'on','1'}));end,end
function result=emptyResult(status),result=struct('values',struct(),'origins',struct(),'states',struct(),'messages',strings(0,1),'status',status,'missingCount',1,'missing',strings(0,1),'conflicts',strings(0,1));end
function result=forceConflict(result,name,message),result.status='conflict';result.conflicts=unique([result.conflicts string(name)],'stable');result.messages=unique([result.messages string(message)],'stable');result.states.(name)='conflict';end
function value=relative(a,b),value=abs(a-b)/max([abs(a) abs(b) realmin]);end
function value=sizeBasis(origins),if origins.tau=="specified"||origins.SV=="specified",value='Residence time';else,value='Volume';end,end
function factor=timeFactor(unit),switch char(string(unit)),case 's',factor=1;case 'min',factor=60;case 'h',factor=3600;otherwise,error('nirp:blocks:invalidUnit','Unknown time unit.');end,end
function data=cleanData(data),if isempty(data),data=zeros(0,2);return,end;if iscell(data),data=cell2mat(data);end;data=data(all(isfinite(data),2),1:2);end
function value=numericParameter(block,name),raw=get_param(block,name);if isnumeric(raw),value=raw;else,value=str2num(raw);end;if isempty(value),value=NaN;end,end %#ok<ST2NM>
function code=modelCode(model),switch char(string(model)),case 'CSTR',code='cstr';case 'PFR',code='pfr';case 'Tanks in series',code='tanks';otherwise,code='dispersion';end,end
function file=resolveSessionFile(block,file),file=char(string(file));if isfile(file),return,end;modelFile=get_param(bdroot(block),'FileName');if ~isempty(modelFile),candidate=fullfile(fileparts(modelFile),file);if isfile(candidate),file=candidate;end,end,end
function rows=resultRows(info),rows={'Space time (s)',valueText(info,'tau');'Mean RTD time (s)',valueText(info,'meanResidenceTime');'Key conversion',valueText(info,'conversion');'Heat duty (W)',valueText(info,'heatDuty');'Warnings',warningText(info)};end
function text=valueText(info,name),if isfield(info,name)&&isnumeric(info.(name))&&isscalar(info.(name))&&isfinite(info.(name)),text=sprintf('%.8g',info.(name));else,text='-';end,end
function text=warningText(info),if ~isfield(info,'warnings')||isempty(info.warnings),text='None';else,text=char(strjoin(string(info.warnings),'; '));end,end
function styleDof(field,state,message),field.BackgroundColor=[1 1 1];field.FontColor=[0 0 0];field.FontAngle='normal';field.Tooltip=char(message);switch char(state),case 'specified',field.FontColor=[0.15 0.25 0.55];case 'calculated',field.BackgroundColor=[0.92 0.92 0.92];field.FontAngle='italic';case 'empty',field.BackgroundColor=[1 0.90 0.90];case 'external',field.BackgroundColor=[0.88 0.88 0.88];case 'conflict',field.BackgroundColor=[1 0.72 0.72];end,end
function text=reactionLabel(index,coefficients,names),sides={'',''};for side=1:2,if side==1,c=-min(coefficients,0);else,c=max(coefficients,0);end;terms=strings(0,1);for k=find(c>0),if abs(c(k)-1)<1e-12,terms(end+1)=names(k);else,terms(end+1)=sprintf('%g %s',c(k),names(k));end,end;sides{side}=char(strjoin(terms,' + '));end;text=sprintf('R%d: %s %s %s',index,sides{1},char(8594),sides{2});end
