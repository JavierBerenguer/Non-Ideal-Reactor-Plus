classdef JacketDialog < handle
%JACKETDIALOG Structured editor for Jacket Simulink blocks.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 8, 2026. Last update: October 14, 2026
% =========================================================================
    properties (SetAccess=private)
        BlockPath; Figure; NameField; UField; UUnitDropDown; UAField
        AField; AUnitDropDown; ASourceDropDown; APortLabel
        UtilityTinField; UtilityTinUnitDropDown; UtilityTinSourceDropDown
        UtilityTinPortLabel; UtilityToutField; UtilityToutUnitDropDown
        UtilityCpField; CondensesCheckBox; LatentHeatField
        ConnectionTable; StatusLabel; DataModel
        ModeDropDown; SpecifiedTField; SpecifiedTUnitDropDown; SpecifiedQField; SpecifiedQUnitDropDown
        ServiceFlowField; ReactorDutyField
    end
    properties (Access=private),Origins,end
    methods
        function obj=JacketDialog(blockPath,varargin)
            p=inputParser;addParameter(p,'Visible','on');parse(p,varargin{:});
            obj.BlockPath=getfullname(blockPath);
            if string(get_param(obj.BlockPath,'System'))~="nirp.blocks.Jacket"
                error('nirp:flowsheet:invalidBlock','JacketDialog requires a Jacket block.');
            end
            try,mask=Simulink.Mask.get(obj.BlockPath);parameter=mask.getParameter('Specifications');if ~isempty(parameter),parameter.Visible='off';end,catch,end
            obj.build(char(string(p.Results.Visible)));nirp.flowsheet.internal.formatNumericControls(obj.Figure);obj.load();obj.refreshConnections();
            [~,~,label]=nirp.flowsheet.blockStatus(obj.BlockPath);obj.StatusLabel.Text=char(label);
        end
        function delete(obj),if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure);end,end
        function setValues(obj,varargin)
            for i=1:2:numel(varargin)
                key=lower(char(string(varargin{i})));value=varargin{i+1};
                map=struct('u','UField','a','AField','utilitytin','UtilityTinField', ...
                    'utilitytout','UtilityToutField','utilitycp','UtilityCpField', ...
                    'latentheat','LatentHeatField','ua','UAField','specifiedt','SpecifiedTField','specifiedq','SpecifiedQField','asource','ASourceDropDown', ...
                    'utilitytinsource','UtilityTinSourceDropDown','condenses','CondensesCheckBox');
                if ~isfield(map,key),error('nirp:flowsheet:unknownParameter','Unknown jacket parameter "%s".',key);end
                field=obj.(map.(key));
                if isprop(field,'AllowEmpty')&&(isempty(value)||(isnumeric(value)&&isscalar(value)&&isnan(value))),field.Value=[];elseif isa(field,'matlab.ui.control.EditField'),field.Value=char(string(value));elseif isa(field,'matlab.ui.control.CheckBox'),field.Value=ison(value);else,field.Value=value;end
            end
            obj.updateVisibility();obj.markSetValues(varargin{:});obj.closeDof();obj.captureModel();
        end
        function values=getValues(obj),obj.captureModel();values=obj.DataModel;end
        function connections=getConnections(obj),connections=obj.ConnectionTable.Data;end
        function applied=apply(obj)
            applied=false;
            try
                name=strtrim(obj.NameField.Value);if isempty(name),error('nirp:flowsheet:invalidName','Name cannot be empty.');end
                result=obj.closeDof();if strcmp(result.status,'conflict'),return,end
                set_param(obj.BlockPath,'Mode',obj.ModeDropDown.Value, ...
                    'SpecifiedT',n(obj.SpecifiedTField.Value),'SpecifiedTUnit',obj.SpecifiedTUnitDropDown.Value, ...
                    'SpecifiedQ',n(obj.SpecifiedQField.Value),'SpecifiedQUnit',obj.SpecifiedQUnitDropDown.Value);
                set_param(obj.BlockPath,'U',n(obj.UField.Value),'UUnit',obj.UUnitDropDown.Value, ...
                    'ASource',obj.ASourceDropDown.Value,'A',n(obj.AField.Value),'AUnit',obj.AUnitDropDown.Value, ...
                    'UtilityTinSource',obj.UtilityTinSourceDropDown.Value, ...
                    'UtilityTin',n(obj.UtilityTinField.Value),'UtilityTinUnit',obj.UtilityTinUnitDropDown.Value, ...
                    'UtilityTout',obj.UtilityToutField.Value,'UtilityToutUnit',obj.UtilityToutUnitDropDown.Value, ...
                    'UtilityCp',obj.UtilityCpField.Value,'Condenses',onoff(obj.CondensesCheckBox.Value), ...
                    'LatentHeat',obj.LatentHeatField.Value);
                nirp.dof.writeSpecs(obj.BlockPath,obj.makeSpecs(result));
                if ~strcmp(name,get_param(obj.BlockPath,'Name')),set_param(obj.BlockPath,'Name',name);obj.BlockPath=[bdroot(obj.BlockPath) '/' name];end
                obj.StatusLabel.Text='Applied.';obj.captureModel();obj.refreshConnections();nirp.flowsheet.afterApply(bdroot(obj.BlockPath),obj.StatusLabel);applied=true;
            catch exception,obj.StatusLabel.Text=exception.message;end
        end
        function accept(obj),if obj.apply(),delete(obj);else,nirp.flowsheet.internal.showDialogError(obj.Figure,obj.StatusLabel.Text,'Jacket');end,end
        function cancel(obj),delete(obj);end
    end
    methods (Static)
        function dialog=open(blockPath),dialog=nirp.flowsheet.JacketDialog(blockPath);end
    end
    methods (Access=private)
        function build(obj,visible)
            obj.Figure=uifigure('Name','Jacket','Tag','NirpJacketDialog','Visible',visible, ...
                'Position',[120 120 900 480],'WindowStyle','alwaysontop');
            main=uigridlayout(obj.Figure,[4 1],'RowHeight',{42,'1x',26,38},'Padding',[12 10 12 10]);
            head=uigridlayout(main,[1 5],'ColumnWidth',{55,'1x',50,190,160});uilabel(head,'Text','Name','HorizontalAlignment','right');obj.NameField=uieditfield(head,'text');
            uilabel(head,'Text','Mode','HorizontalAlignment','right');obj.ModeDropDown=uidropdown(head,'Items',{'Select...','Utility (U*A)','Specified reactor T','Specified Q'},'ItemsData',{'Select...','Utility','Specified T','Specified Q'},'ValueChangedFcn',@(~,~) obj.configurationChanged());uibutton(head,'Text','Unit conversion helper','ButtonPushedFcn',@(~,~) UnitConverterHelper.launch());
            tabs=uitabgroup(main);general=uitab(tabs,'Title','Jacket');connections=uitab(tabs,'Title','Connections');
            grid=uigridlayout(general,[9 6],'ColumnWidth',{175,135,110,175,110,'1x'},'RowHeight',repmat({30},1,9),'RowSpacing',2,'Padding',[5 5 5 5]);
            [obj.UField,obj.UUnitDropDown]=qty(grid,1,'U','HeatTransferCoefficient');
            [obj.SpecifiedTField,obj.SpecifiedTUnitDropDown]=qty(grid,1,'Reactor temperature','Temperature');obj.SpecifiedTUnitDropDown.Items={'K',[char(176) 'C']};
            [obj.SpecifiedQField,obj.SpecifiedQUnitDropDown]=qty(grid,1,'Heat duty (Q > 0 heats)','Power');
            [obj.AField,obj.AUnitDropDown]=qty(grid,2,'Area','Area');obj.APortLabel=portLabel(grid,2);
            [obj.UtilityTinField,obj.UtilityTinUnitDropDown]=qty(grid,3,'Utility inlet T','Temperature');obj.UtilityTinPortLabel=portLabel(grid,3);
            [obj.UtilityToutField,obj.UtilityToutUnitDropDown]=textqty(grid,4,'Utility outlet T (optional)','Temperature');
            obj.UtilityCpField=textfield(grid,5,'Utility Cp (J/(kg*K), optional)');
            obj.CondensesCheckBox=uicheckbox(grid,'Text','Utility condenses','ValueChangedFcn',@(~,~) obj.configurationChanged());obj.CondensesCheckBox.Layout.Row=6;obj.CondensesCheckBox.Layout.Column=[1 2];
            obj.LatentHeatField=textfield(grid,7,'Latent heat (J/kg)');
            obj.UAField=textfield(grid,8,'UA (W/K)');
            dutyLabel=uilabel(grid,'Text','Reactor duty Q (W)','HorizontalAlignment','right');dutyLabel.Layout.Row=8;dutyLabel.Layout.Column=4;obj.ReactorDutyField=uieditfield(grid,'text','Editable','off');obj.ReactorDutyField.Layout.Row=8;obj.ReactorDutyField.Layout.Column=[5 6];
            obj.ServiceFlowField=textfield(grid,9,'Service flow (kg/s)');obj.ServiceFlowField.Editable='off';
            obj.ASourceDropDown=drop(grid,1,'Area source',{'Dialog','Input port'});obj.UtilityTinSourceDropDown=drop(grid,2,'Utility inlet T source',{'Dialog','Input port'});obj.ASourceDropDown.ValueChangedFcn=@(~,~) obj.configurationChanged();obj.UtilityTinSourceDropDown.ValueChangedFcn=@(~,~) obj.configurationChanged();
            fields={obj.UField,'U';obj.AField,'A';obj.UtilityTinField,'T_in_s';obj.UtilityToutField,'T_out_s';obj.UtilityCpField,'Cp_s';obj.LatentHeatField,'lambda';obj.UAField,'UA';obj.SpecifiedTField,'T_reactor';obj.SpecifiedQField,'Q'};for i=1:size(fields,1),fields{i,1}.ValueChangedFcn=@(~,event)obj.fieldEdited(fields{i,2},event);end
            cgrid=uigridlayout(connections,[2 1],'RowHeight',{30,'1x'});uilabel(cgrid,'Text','Connected signals (read only)','FontWeight','bold');obj.ConnectionTable=uitable(cgrid,'ColumnName',{'Direction','Port','Signal'},'ColumnEditable',[false false false]);
            obj.StatusLabel=uilabel(main,'Text','Ready.','FontAngle','italic');buttons=uigridlayout(main,[1 5],'ColumnWidth',{'1x',70,90,90,90});uilabel(buttons,'Text','');uibutton(buttons,'Text','Help','ButtonPushedFcn',@(~,~) openNirpGuide('guides/flowsheet-reactors.html#jacket'));uibutton(buttons,'Text','OK','ButtonPushedFcn',@(~,~) obj.accept());uibutton(buttons,'Text','Cancel','ButtonPushedFcn',@(~,~) obj.cancel());uibutton(buttons,'Text','Apply','ButtonPushedFcn',@(~,~) obj.apply());
        end
        function load(obj)
            obj.Origins=struct('U',"empty",'A',"empty",'UA',"empty",'T_in_s',"empty",'T_out_s',"empty",'Cp_s',"empty",'lambda',"empty",'T_reactor',"empty",'Q',"empty");
            obj.NameField.Value=get_param(obj.BlockPath,'Name');
            numeric={'U',obj.UField;'A',obj.AField;'UtilityTin',obj.UtilityTinField};for i=1:size(numeric,1),value=str2double(get_param(obj.BlockPath,numeric{i,1}));if isfinite(value),numeric{i,2}.Value=value;else,numeric{i,2}.Value=[];end,end
            text={'UtilityTout',obj.UtilityToutField;'UtilityCp',obj.UtilityCpField;'LatentHeat',obj.LatentHeatField};for i=1:size(text,1),text{i,2}.Value=get_param(obj.BlockPath,text{i,1});end
            values={'UUnit',obj.UUnitDropDown;'AUnit',obj.AUnitDropDown;'ASource',obj.ASourceDropDown;'UtilityTinUnit',obj.UtilityTinUnitDropDown;'UtilityTinSource',obj.UtilityTinSourceDropDown;'UtilityToutUnit',obj.UtilityToutUnitDropDown};for i=1:size(values,1),values{i,2}.Value=get_param(obj.BlockPath,values{i,1});end
            obj.ModeDropDown.Value=get_param(obj.BlockPath,'Mode');value=str2double(get_param(obj.BlockPath,'SpecifiedT'));if isfinite(value),obj.SpecifiedTField.Value=value;else,obj.SpecifiedTField.Value=[];end;value=str2double(get_param(obj.BlockPath,'SpecifiedQ'));if isfinite(value),obj.SpecifiedQField.Value=value;else,obj.SpecifiedQField.Value=[];end
            obj.SpecifiedTUnitDropDown.Value=get_param(obj.BlockPath,'SpecifiedTUnit');obj.SpecifiedQUnitDropDown.Value=get_param(obj.BlockPath,'SpecifiedQUnit');
            obj.CondensesCheckBox.Value=ison(get_param(obj.BlockPath,'Condenses'));obj.updateVisibility();obj.captureModel();
            specText=get_param(obj.BlockPath,'Specifications');if isempty(strtrim(specText)),obj.loadLegacyOrigins();else,obj.loadSpecs(nirp.dof.readSpecs(specText));end;obj.closeDof();
        end
        function updateVisibility(obj)
            % T-146: only the controls of the selected Jacket mode are shown.
            mode=obj.ModeDropDown.Value;utility=strcmp(mode,'Utility');children=obj.UField.Parent.Children;
            for i=1:numel(children),children(i).Visible=onoff(utility);end
            specT={'Reactor temperature'};specQ={'Heat duty (Q > 0 heats)'};
            labels=findobj(obj.UField.Parent,'Type','uilabel');
            for i=1:numel(labels),if strcmp(labels(i).Text,specT{1}),labels(i).Visible=onoff(strcmp(mode,'Specified T'));elseif strcmp(labels(i).Text,specQ{1}),labels(i).Visible=onoff(strcmp(mode,'Specified Q'));end,end
            set([obj.SpecifiedTField obj.SpecifiedTUnitDropDown],'Visible',onoff(strcmp(mode,'Specified T')));
            set([obj.SpecifiedQField obj.SpecifiedQUnitDropDown],'Visible',onoff(strcmp(mode,'Specified Q')));
            if ~utility,return,end
            inputA=strcmp(obj.ASourceDropDown.Value,'Input port');obj.AField.Visible=onoff(~inputA);obj.AField.Editable=onoff(~inputA);obj.APortLabel.Visible=onoff(inputA);if inputA,obj.APortLabel.Text=nirp.flowsheet.receivedValue(obj.BlockPath,'A','Area',obj.AUnitDropDown.Value,1);end
            inputTin=strcmp(obj.UtilityTinSourceDropDown.Value,'Input port');obj.UtilityTinField.Visible=onoff(~inputTin);obj.UtilityTinField.Editable=onoff(~inputTin);obj.UtilityTinPortLabel.Visible=onoff(inputTin);if inputTin,obj.UtilityTinPortLabel.Text=nirp.flowsheet.receivedValue(obj.BlockPath,'utilityTin','Temperature',obj.UtilityTinUnitDropDown.Value,1+inputA);end
            obj.LatentHeatField.Enable=onoff(obj.CondensesCheckBox.Value);
        end
        function refreshConnections(obj)
            ports=get_param(obj.BlockPath,'PortHandles');data=cell(0,3);
            for i=1:numel(ports.Inport),data(end+1,:)={'Input',i,signalName(ports.Inport(i))};end
            for i=1:numel(ports.Outport),data(end+1,:)={'Output',i,signalDestinations(ports.Outport(i))};end
            obj.ConnectionTable.Data=data;
        end
        function captureModel(obj)
            q=@(v,u) struct('value',v,'unit',string(u),'origin',"specified");
            obj.DataModel=struct('U',q(obj.UField.Value,obj.UUnitDropDown.Value), ...
                'A',q(obj.AField.Value,obj.AUnitDropDown.Value), ...
                'UtilityTin',q(obj.UtilityTinField.Value,obj.UtilityTinUnitDropDown.Value), ...
                'UtilityTout',q(str2double(obj.UtilityToutField.Value),obj.UtilityToutUnitDropDown.Value), ...
                'UtilityCp',q(str2double(obj.UtilityCpField.Value),'J/(kg*K)'), ...
                'LatentHeat',q(str2double(obj.LatentHeatField.Value),'J/kg'), ...
                'Condenses',struct('value',obj.CondensesCheckBox.Value, ...
                'unit',"1",'origin',"specified"));
        end
        function markSetValues(obj,varargin)
            for i=1:2:numel(varargin),key=lower(char(string(varargin{i})));map=struct('u','U','a','A','ua','UA','utilitytin','T_in_s','utilitytout','T_out_s','utilitycp','Cp_s','latentheat','lambda','specifiedt','T_reactor','specifiedq','Q');if isfield(map,key),value=varargin{i+1};if isempty(value)||(isnumeric(value)&&isscalar(value)&&isnan(value)),obj.Origins.(map.(key))="empty";else,obj.Origins.(map.(key))="specified";end,end,end
        end
        function fieldEdited(obj,name,event),value=changedValue(event);if isempty(value)||(isnumeric(value)&&isscalar(value)&&isnan(value))||((ischar(value)||isstring(value))&&~isfinite(str2double(value))),obj.Origins.(name)="empty";else,obj.Origins.(name)="specified";end;obj.closeDof();end
        function configurationChanged(obj),obj.updateVisibility();if ~isempty(obj.Origins),obj.closeDof();end,end
        function loadLegacyOrigins(obj)
            mode=obj.ModeDropDown.Value;if strcmp(mode,'Specified T'),obj.Origins.T_reactor="specified";elseif strcmp(mode,'Specified Q'),obj.Origins.Q="specified";elseif strcmp(mode,'Utility'),obj.Origins.U="specified";if strcmp(obj.ASourceDropDown.Value,'Input port'),obj.Origins.A="external";else,obj.Origins.A="specified";end;if strcmp(obj.UtilityTinSourceDropDown.Value,'Input port'),obj.Origins.T_in_s="external";else,obj.Origins.T_in_s="specified";end;if isfinite(str2double(obj.UtilityToutField.Value)),obj.Origins.T_out_s="specified";end;if isfinite(str2double(obj.UtilityCpField.Value)),obj.Origins.Cp_s="specified";end;if isfinite(str2double(obj.LatentHeatField.Value)),obj.Origins.lambda="specified";end;end
        end
        function loadSpecs(obj,specs),names=fieldnames(specs);for i=1:numel(names),name=names{i};if ~isfield(obj.Origins,name),continue,end;obj.setFromSI(name,specs.(name).si);obj.Origins.(name)="specified";end,end
        function result=closeDof(obj)
            if strcmp(obj.ModeDropDown.Value,'Select...'),result=emptyResult();nirp.flowsheet.internal.paintDofStatus(obj.StatusLabel,'missing','1 specification missing: mode.');return,end
            model=nirp.dof.catalog.jacket(struct('mode',obj.ModeDropDown.Value,'condenses',obj.CondensesCheckBox.Value));values=struct();origins=struct();if strcmp(obj.ModeDropDown.Value,'Utility'),values.Q=obj.lastDuty();origins.Q='external';if strcmp(obj.ASourceDropDown.Value,'Input port'),values.A=NaN;origins.A='external';end;if strcmp(obj.UtilityTinSourceDropDown.Value,'Input port'),values.T_in_s=NaN;origins.T_in_s='external';end;end
            names={model.variables.name};for i=1:numel(names),name=names{i};if isfield(obj.Origins,name)&&obj.Origins.(name)=="specified",values.(name)=obj.toSI(name);origins.(name)='specified';end,end
            result=nirp.dof.solve(model,values,origins);for i=1:numel(names),name=names{i};if isfield(obj.Origins,name),obj.Origins.(name)=string(result.origins.(name));obj.setCalculated(name,result.values.(name),result.origins.(name));end,end
            if isfield(result.values,'Q')&&isfinite(result.values.Q),obj.ReactorDutyField.Value=num2str(result.values.Q,8);else,obj.ReactorDutyField.Value='';end;if isfield(result.values,'mdot_s')&&isfinite(result.values.mdot_s),obj.ServiceFlowField.Value=num2str(result.values.mdot_s,8);else,obj.ServiceFlowField.Value='';end
            obj.captureModel();obj.DataModel.Result=result;if strcmp(result.status,'complete'),message="Fully specified";elseif strcmp(result.status,'conflict'),message="Conflict: "+strjoin(result.messages,' ');else,message=result.messages(end);end;nirp.flowsheet.internal.paintDofStatus(obj.StatusLabel,result.status,message);
        end
        function specs=makeSpecs(obj,result),specs=struct();names=fieldnames(result.values);for i=1:numel(names),name=names{i};if isfield(obj.Origins,name)&&obj.Origins.(name)=="specified",specs.(name)=struct('si',result.values.(name),'unit',obj.unit(name));end,end,end
        function value=toSI(obj,name),switch name,case 'U',value=UnitConverterHelper.convertToSI('HeatTransferCoefficient',obj.UField.Value,obj.UUnitDropDown.Value);case 'A',value=UnitConverterHelper.convertToSI('Area',obj.AField.Value,obj.AUnitDropDown.Value);case 'UA',value=str2double(obj.UAField.Value);case 'T_in_s',value=UnitConverterHelper.convertToSI('Temperature',obj.UtilityTinField.Value,obj.UtilityTinUnitDropDown.Value);case 'T_out_s',value=UnitConverterHelper.convertToSI('Temperature',str2double(obj.UtilityToutField.Value),obj.UtilityToutUnitDropDown.Value);case 'Cp_s',value=str2double(obj.UtilityCpField.Value);case 'lambda',value=str2double(obj.LatentHeatField.Value);case 'T_reactor',value=UnitConverterHelper.convertToSI('Temperature',obj.SpecifiedTField.Value,obj.SpecifiedTUnitDropDown.Value);case 'Q',value=UnitConverterHelper.convertToSI('Power',obj.SpecifiedQField.Value,obj.SpecifiedQUnitDropDown.Value);end,end
        function setCalculated(obj,name,value,origin),if strcmp(origin,'specified')||strcmp(origin,'external')||~isfinite(value),return,end;obj.setFromSI(name,value);end
        function setFromSI(obj,name,value),switch name,case 'U',obj.UField.Value=UnitConverterHelper.convertFromSI('HeatTransferCoefficient',value,obj.UUnitDropDown.Value);case 'A',obj.AField.Value=UnitConverterHelper.convertFromSI('Area',value,obj.AUnitDropDown.Value);case 'UA',obj.UAField.Value=num2str(value,17);case 'T_in_s',obj.UtilityTinField.Value=UnitConverterHelper.convertFromSI('Temperature',value,obj.UtilityTinUnitDropDown.Value);case 'T_out_s',obj.UtilityToutField.Value=num2str(UnitConverterHelper.convertFromSI('Temperature',value,obj.UtilityToutUnitDropDown.Value),17);case 'Cp_s',obj.UtilityCpField.Value=num2str(value,17);case 'lambda',obj.LatentHeatField.Value=num2str(value,17);case 'T_reactor',obj.SpecifiedTField.Value=UnitConverterHelper.convertFromSI('Temperature',value,obj.SpecifiedTUnitDropDown.Value);case 'Q',obj.SpecifiedQField.Value=UnitConverterHelper.convertFromSI('Power',value,obj.SpecifiedQUnitDropDown.Value);end,end
        function value=unit(obj,name),switch name,case 'U',value=obj.UUnitDropDown.Value;case 'A',value=obj.AUnitDropDown.Value;case 'UA',value='W/K';case 'T_in_s',value=obj.UtilityTinUnitDropDown.Value;case 'T_out_s',value=obj.UtilityToutUnitDropDown.Value;case 'Cp_s',value='J/(kg*K)';case 'lambda',value='J/kg';case 'T_reactor',value=obj.SpecifiedTUnitDropDown.Value;case 'Q',value=obj.SpecifiedQUnitDropDown.Value;otherwise,value='';end,end
        function value=lastDuty(obj),value=NaN;if ~evalin('base','exist(''nirpResults'',''var'')'),return,end;results=evalin('base','nirpResults');if ~isstruct(results)||~isfield(results,'Diagnostics'),return,end;try,ports=get_param(obj.BlockPath,'PortHandles');line=get_param(ports.Outport(1),'Line');dest=get_param(line,'DstBlockHandle');for h=reshape(dest,1,[]),key=matlab.lang.makeValidName([bdroot(obj.BlockPath) '_' get_param(h,'Name')]);if isfield(results.Diagnostics,key)&&isfield(results.Diagnostics.(key),'lastInfo')&&isfield(results.Diagnostics.(key).lastInfo,'heatDuty'),value=results.Diagnostics.(key).lastInfo.heatDuty;return,end,end,catch,end,end
    end
end
function [field,units]=qty(grid,row,label,category),text=uilabel(grid,'Text',label,'HorizontalAlignment','right');text.Layout.Row=row;text.Layout.Column=1;field=uieditfield(grid,'numeric','AllowEmpty','on','Value',[]);field.Layout.Row=row;field.Layout.Column=2;units=uidropdown(grid,'Items',UnitConverterHelper.getUnits(category));units.Layout.Row=row;units.Layout.Column=3;end
function [field,units]=textqty(grid,row,label,category),text=uilabel(grid,'Text',label,'HorizontalAlignment','right');text.Layout.Row=row;text.Layout.Column=1;field=uieditfield(grid,'text');field.Layout.Row=row;field.Layout.Column=2;units=uidropdown(grid,'Items',UnitConverterHelper.getUnits(category));units.Layout.Row=row;units.Layout.Column=3;end
function field=textfield(grid,row,label),text=uilabel(grid,'Text',label,'HorizontalAlignment','right');text.Layout.Row=row;text.Layout.Column=1;field=uieditfield(grid,'text');field.Layout.Row=row;field.Layout.Column=[2 3];end
function field=drop(grid,row,label,items),text=uilabel(grid,'Text',label,'HorizontalAlignment','right');text.Layout.Row=row;text.Layout.Column=4;field=uidropdown(grid,'Items',items);field.Layout.Row=row;field.Layout.Column=[5 6];end
function label=portLabel(grid,row),label=uilabel(grid,'Text','From input port','FontAngle','italic','Visible','off');label.Layout.Row=row;label.Layout.Column=2;end
function value=onoff(flag),if flag,value='on';else,value='off';end,end
function flag=ison(value),if islogical(value)||isnumeric(value),flag=logical(value);else,flag=strcmp(value,'on')||strcmp(value,'1');end,end
function value=n(x),if isempty(x),value='NaN';else,value=num2str(x,17);end,end
function value=changedValue(event),if (isstruct(event)&&isfield(event,'NewData'))||(~isstruct(event)&&isprop(event,'NewData')),value=event.NewData;else,value=event.Value;end,end
function value=signalName(port),value='<missing>';line=get_param(port,'Line');if line==-1,return,end;source=get_param(line,'SrcBlockHandle');if source~=-1,value=get_param(source,'Name');end,end
function value=signalDestinations(port),value='<missing>';line=get_param(port,'Line');if line==-1,return,end;dest=get_param(line,'DstBlockHandle');dest=dest(dest~=-1);if ~isempty(dest),value=char(strjoin(string(arrayfun(@(h)get_param(h,'Name'),dest,'UniformOutput',false)),', '));end,end
function result=emptyResult(),result=struct('values',struct(),'origins',struct(),'states',struct(),'messages',"Mode is required.",'status','missing','missingCount',1,'missing',"mode",'conflicts',strings(0,1));end
