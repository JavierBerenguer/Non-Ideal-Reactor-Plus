classdef HeaterDialog < handle
%HEATERDIALOG Degree-of-freedom editor for Heater/Cooler blocks.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 14, 2026
% =========================================================================
    properties (SetAccess=private)
        BlockPath;Figure;NameField;ModeGroup;ToutField;ToutUnitDropDown
        TemperatureChangeField;TemperatureChangeUnitDropDown
        DutyField;DutyUnitDropDown;PressureDropField;PressureDropUnitDropDown
        OutletPressureField;OutletPressureUnitDropDown
        HeatPortCheckBox;ConnectionTable;StatusLabel;DataModel
    end
    properties (Access=private)
        Origins
        CompatibilityMode = ''
        CompatibilityModeExplicit = false
    end
    methods
        function obj=HeaterDialog(blockPath,varargin)
            p=inputParser;addParameter(p,'Visible','on');parse(p,varargin{:});obj.BlockPath=getfullname(blockPath);
            if string(get_param(obj.BlockPath,'System'))~="nirp.blocks.Heater",error('nirp:flowsheet:invalidBlock','HeaterDialog requires a Heater block.');end
            try,mask=Simulink.Mask.get(obj.BlockPath);parameter=mask.getParameter('Specifications');if ~isempty(parameter),parameter.Visible='off';end,catch,end
            obj.build(char(string(p.Results.Visible)));nirp.flowsheet.internal.formatNumericControls(obj.Figure);obj.load();obj.refreshConnections();
        end
        function delete(obj),if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure);end,end
        function setMode(obj,mode)
            mode=char(string(mode));buttons=obj.ModeGroup.Children;index=find(strcmp({buttons.Text},mode),1);if isempty(index),error('nirp:flowsheet:invalidMode','Unknown heater mode.');end
            obj.ModeGroup.SelectedObject=buttons(index);obj.CompatibilityMode=mode;obj.CompatibilityModeExplicit=true;
            if strcmp(mode,'Outlet T'),obj.Origins.T_out="specified";obj.Origins.Q="empty";elseif strcmp(mode,'Duty'),obj.Origins.Q="specified";obj.Origins.T_out="empty";end
            obj.updateCompatibilityVisibility();obj.closeDof();
        end
        function setValues(obj,varargin)
            for i=1:2:numel(varargin)
                key=lower(char(string(varargin{i})));value=varargin{i+1};
                switch key
                    case {'tout','temperature','t_out'},field=obj.ToutField;name='T_out';
                    case {'temperaturechange','dt'},field=obj.TemperatureChangeField;name='dT';
                    case {'duty','q'},field=obj.DutyField;name='Q';
                    case {'pressuredrop','dp'},field=obj.PressureDropField;name='dP';
                    case {'outletpressure','pout','p_out'},field=obj.OutletPressureField;name='P_out';
                    case 'mode',obj.setMode(value);continue
                    otherwise,error('nirp:flowsheet:unknownParameter','Unknown heater parameter.');
                end
                if ~obj.CompatibilityModeExplicit,obj.CompatibilityMode='';end
                if isempty(value)||(isnumeric(value)&&isscalar(value)&&isnan(value)),field.Value=[];obj.Origins.(name)="empty";else,field.Value=value;obj.Origins.(name)="specified";end
            end
            obj.updateCompatibilityVisibility();obj.closeDof();
        end
        function values=getValues(obj),obj.closeDof();values=obj.DataModel;end
        function applied=apply(obj)
            applied=false;result=obj.closeDof();if ~strcmp(result.status,'complete'),return,end
            try
                name=strtrim(obj.NameField.Value);if isempty(name),error('nirp:flowsheet:invalidName','Name cannot be empty.');end
                specs=obj.specifications(result);writeProducerSpecs(obj.BlockPath,specs);
                legacyMode='Outlet T';if isfield(specs,'Q'),legacyMode='Duty';end
                set_param(obj.BlockPath,'Mode',legacyMode,'Tout',number(obj.ToutField.Value), ...
                    'ToutUnit',obj.ToutUnitDropDown.Value,'Duty',number(obj.DutyField.Value), ...
                    'DutyUnit',obj.DutyUnitDropDown.Value,'PressureDrop',number(obj.PressureDropField.Value), ...
                    'PressureDropUnit',obj.PressureDropUnitDropDown.Value,'ShowHeatPort',onoff(obj.HeatPortCheckBox.Value));
                if ~strcmp(name,get_param(obj.BlockPath,'Name')),set_param(obj.BlockPath,'Name',name);obj.BlockPath=getfullname([bdroot(obj.BlockPath) '/' name]);end
                obj.refreshConnections();nirp.flowsheet.afterApply(bdroot(obj.BlockPath),obj.StatusLabel);applied=true;
            catch exception,obj.StatusLabel.Text=exception.message;end
        end
        function accept(obj),if obj.apply(),delete(obj);else,nirp.flowsheet.internal.showDialogError(obj.Figure,obj.StatusLabel.Text,'Heater / Cooler');end,end
        function cancel(obj),delete(obj);end
    end
    methods (Static),function dialog=open(blockPath),dialog=nirp.flowsheet.HeaterDialog(blockPath);end,end
    methods (Access=private)
        function build(obj,visible)
            obj.Figure=uifigure('Name','Heater / Cooler','Tag','NirpHeaterDialog','Visible',visible,'Position',[120 100 760 500],'WindowStyle','alwaysontop');main=uigridlayout(obj.Figure,[4 1],'RowHeight',{40,'1x',25,38},'Padding',[12 10 12 10]);
            head=uigridlayout(main,[1 4],'ColumnWidth',{160,60,'1x',180});uibutton(head,'Text','Unit conversion helper','ButtonPushedFcn',@(~,~)UnitConverterHelper.launch());uilabel(head,'Text','Name','HorizontalAlignment','right');obj.NameField=uieditfield(head,'text');
            tabs=uitabgroup(main);general=uitab(tabs,'Title','Heater / Cooler');connections=uitab(tabs,'Title','Connections');g=uigridlayout(general,[8 3],'ColumnWidth',{230,170,130},'RowHeight',{25,32,32,32,32,32,32,'1x'});
            tip=uilabel(g,'Text','Specify one thermal variable and one pressure variable.','FontAngle','italic');tip.Layout.Row=1;tip.Layout.Column=[1 3];
            [obj.ToutField,obj.ToutUnitDropDown]=qrow(g,2,'Outlet T','Temperature');
            [obj.TemperatureChangeField,obj.TemperatureChangeUnitDropDown]=simpleRow(g,3,'Temperature change',{'K',[char(176) 'C']});
            [obj.DutyField,obj.DutyUnitDropDown]=qrow(g,4,'Duty','Power');
            [obj.PressureDropField,obj.PressureDropUnitDropDown]=qrow(g,5,'Pressure drop','Pressure');
            [obj.OutletPressureField,obj.OutletPressureUnitDropDown]=qrow(g,6,'Outlet pressure','Pressure');
            obj.HeatPortCheckBox=uicheckbox(g,'Text','Show heat port');obj.HeatPortCheckBox.Layout.Row=7;obj.HeatPortCheckBox.Layout.Column=[2 3];
            obj.ModeGroup=uibuttongroup(g,'Title','Legacy mode','Visible','off');obj.ModeGroup.Layout.Row=8;obj.ModeGroup.Layout.Column=[1 3];uiradiobutton(obj.ModeGroup,'Text','Select...');uiradiobutton(obj.ModeGroup,'Text','Outlet T');uiradiobutton(obj.ModeGroup,'Text','Duty');
            fields={obj.ToutField,'T_out';obj.TemperatureChangeField,'dT';obj.DutyField,'Q';obj.PressureDropField,'dP';obj.OutletPressureField,'P_out'};for i=1:size(fields,1),fields{i,1}.ValueChangedFcn=@(~,event)obj.edited(fields{i,2},event);end
            cg=uigridlayout(connections,[2 1],'RowHeight',{30,'1x'});uilabel(cg,'Text','Connected material streams (read only)','FontWeight','bold');obj.ConnectionTable=uitable(cg,'ColumnName',{'Direction','Port','Stream'},'ColumnEditable',[false false false]);
            obj.StatusLabel=uilabel(main,'Text','Ready.','FontAngle','italic');buttons=uigridlayout(main,[1 4],'ColumnWidth',{'1x',90,90,90});uilabel(buttons,'Text','');uibutton(buttons,'Text','OK','ButtonPushedFcn',@(~,~)obj.accept());uibutton(buttons,'Text','Cancel','ButtonPushedFcn',@(~,~)obj.cancel());uibutton(buttons,'Text','Apply','ButtonPushedFcn',@(~,~)obj.apply());
        end
        function load(obj)
            obj.NameField.Value=get_param(obj.BlockPath,'Name');obj.ToutUnitDropDown.Value=get_param(obj.BlockPath,'ToutUnit');obj.DutyUnitDropDown.Value=get_param(obj.BlockPath,'DutyUnit');obj.PressureDropUnitDropDown.Value=get_param(obj.BlockPath,'PressureDropUnit');obj.OutletPressureUnitDropDown.Value=get_param(obj.BlockPath,'PressureDropUnit');obj.HeatPortCheckBox.Value=strcmp(get_param(obj.BlockPath,'ShowHeatPort'),'on');
            obj.Origins=struct('T_out',"empty",'dT',"empty",'Q',"empty",'dP',"empty",'P_out',"empty");specText=get_param(obj.BlockPath,'Specifications');
            if isempty(strtrim(specText))
                mode=get_param(obj.BlockPath,'Mode');
                if strcmp(mode,'Duty')&&isfinite(str2double(get_param(obj.BlockPath,'Duty'))),setNumeric(obj.DutyField,get_param(obj.BlockPath,'Duty'));obj.Origins.Q="specified";
                elseif strcmp(mode,'Outlet T')&&isfinite(str2double(get_param(obj.BlockPath,'Tout'))),setNumeric(obj.ToutField,get_param(obj.BlockPath,'Tout'));obj.Origins.T_out="specified";end
                if isfinite(str2double(get_param(obj.BlockPath,'PressureDrop'))),setNumeric(obj.PressureDropField,get_param(obj.BlockPath,'PressureDrop'));obj.Origins.dP="specified";end
                obj.CompatibilityMode=mode;obj.CompatibilityModeExplicit=false;selectMode(obj.ModeGroup,mode);
            else
                specs=nirp.dof.readSpecs(specText);names=fieldnames(specs);for i=1:numel(names),obj.setFromSI(names{i},specs.(names{i}).si,specs.(names{i}).unit);obj.Origins.(names{i})="specified";end
            end
            obj.updateCompatibilityVisibility();obj.closeDof();
        end
        function edited(obj,name,event)
            value=changedValue(event);if isempty(value)||(isnumeric(value)&&isscalar(value)&&isnan(value)),obj.Origins.(name)="empty";else,obj.Origins.(name)="specified";end
            obj.CompatibilityMode='';obj.CompatibilityModeExplicit=false;obj.updateCompatibilityVisibility();obj.closeDof();
        end
        function result=closeDof(obj)
            names={'T_out','dT','Q','dP','P_out'};specs=struct();for i=1:numel(names),if obj.Origins.(names{i})=="specified",specs.(names{i})=struct('si',obj.toSI(names{i}),'unit',char(obj.unitField(names{i}).Value));end,end
            try,state=nirp.dof.producerState(obj.BlockPath,'InternalSpecifications',specs);result=state.Result;source=state.InletSource;catch exception,result=failure(names,exception.message);source="";state=struct('Output',struct('sources',struct()));end
            waiting=~isfield(state,'Inlet')||isempty(state.Inlet);for i=1:numel(names),name=names{i};if isfield(result.values,name),obj.setCalculated(name,result.values.(name),result.origins.(name));tip=strjoin(result.messages,' ');if isfield(state.Output.sources,name),tip=string(state.Output.sources.(name))+". "+tip;end;fieldState=result.states.(name);if waiting&&strcmp(result.status,'complete')&&strcmp(fieldState,'empty'),fieldState='external';tip='needs a run or a defined feed';end;styleField(obj.field(name),fieldState,tip);end,end
            obj.DataModel=struct();for i=1:numel(names),name=names{i};obj.DataModel.(name)=struct('value',obj.field(name).Value,'unit',string(obj.unitField(name).Value),'origin',string(result.origins.(name)));end;obj.DataModel.Tout=obj.DataModel.T_out;obj.DataModel.Duty=obj.DataModel.Q;obj.DataModel.PressureDrop=obj.DataModel.dP;obj.DataModel.Result=result;
            if strcmp(result.status,'complete'),message="Fully specified";if strlength(source)>0,message=message+" - "+source;end;elseif strcmp(result.status,'conflict'),message="Conflict: "+strjoin(result.messages,' ');else,message=result.messages(end);end
            [~,~,runLabel]=nirp.flowsheet.blockStatus(obj.BlockPath);message=message+" - "+runLabel;if waiting,message=message+"; inlet-dependent values need a run or a defined feed";end;nirp.flowsheet.internal.paintDofStatus(obj.StatusLabel,result.status,message);
        end
        function specs=specifications(obj,result)
            specs=struct();names={'T_out','dT','Q','dP','P_out'};for i=1:numel(names),name=names{i};if obj.Origins.(name)=="specified",specs.(name)=struct('si',result.values.(name),'unit',char(obj.unitField(name).Value));end,end
        end
        function value=toSI(obj,name)
            value=obj.field(name).Value;unit=obj.unitField(name).Value;switch name,case 'T_out',value=UnitConverterHelper.convertToSI('Temperature',value,unit);case 'dT',value=double(value);case 'Q',value=UnitConverterHelper.convertToSI('Power',value,unit);otherwise,value=UnitConverterHelper.convertToSI('Pressure',value,unit);end
        end
        function setCalculated(obj,name,value,origin)
            if strcmp(origin,'specified')||~(isnumeric(value)&&isscalar(value)&&isfinite(value)),return,end;field=obj.field(name);unit=obj.unitField(name).Value;switch name,case 'T_out',value=UnitConverterHelper.convertFromSI('Temperature',value,unit);case 'dT',value=double(value);case 'Q',value=UnitConverterHelper.convertFromSI('Power',value,unit);otherwise,value=UnitConverterHelper.convertFromSI('Pressure',value,unit);end;field.Value=value;
        end
        function setFromSI(obj,name,value,unit),dropdown=obj.unitField(name);if ~isempty(unit)&&any(string(dropdown.Items)==string(unit)),dropdown.Value=unit;end;obj.setCalculated(name,value,'calculated');end
        function value=field(obj,name),map=struct('T_out','ToutField','dT','TemperatureChangeField','Q','DutyField','dP','PressureDropField','P_out','OutletPressureField');value=obj.(map.(name));end
        function value=unitField(obj,name),map=struct('T_out','ToutUnitDropDown','dT','TemperatureChangeUnitDropDown','Q','DutyUnitDropDown','dP','PressureDropUnitDropDown','P_out','OutletPressureUnitDropDown');value=obj.(map.(name));end
        function updateCompatibilityVisibility(obj),obj.ToutField.Visible='on';obj.ToutUnitDropDown.Visible='on';obj.DutyField.Visible='on';obj.DutyUnitDropDown.Visible='on';end
        function refreshConnections(obj),graph=nirp.flowsheet.topology(bdroot(obj.BlockPath));key=matlab.lang.makeValidName(get_param(obj.BlockPath,'Name'));data=cell(0,3);if isfield(graph.Units,key),x=graph.Units.(key);for i=1:numel(x.Inputs),data(end+1,:)={'Input',i,label(x.Inputs{i})};end;for i=1:numel(x.Outputs),data(end+1,:)={'Output',i,label(x.Outputs{i})};end;end;obj.ConnectionTable.Data=data;end
    end
end
function [f,u]=qrow(g,row,labelText,category),t=uilabel(g,'Text',labelText,'HorizontalAlignment','right');t.Layout.Row=row;t.Layout.Column=1;f=uieditfield(g,'numeric','AllowEmpty','on','Value',[]);f.Layout.Row=row;f.Layout.Column=2;u=uidropdown(g,'Items',UnitConverterHelper.getUnits(category));u.Layout.Row=row;u.Layout.Column=3;end
function [f,u]=simpleRow(g,row,labelText,items),t=uilabel(g,'Text',labelText,'HorizontalAlignment','right');t.Layout.Row=row;t.Layout.Column=1;f=uieditfield(g,'numeric','AllowEmpty','on','Value',[]);f.Layout.Row=row;f.Layout.Column=2;u=uidropdown(g,'Items',items);u.Layout.Row=row;u.Layout.Column=3;end
function setNumeric(field,text),value=str2double(text);if isfinite(value),field.Value=value;else,field.Value=[];end,end
function value=changedValue(event),if (isstruct(event)&&isfield(event,'NewData'))||(~isstruct(event)&&isprop(event,'NewData')),value=event.NewData;else,value=event.Value;end,end
function selectMode(group,value),buttons=group.Children;index=find(strcmp({buttons.Text},value),1);if ~isempty(index),group.SelectedObject=buttons(index);end,end
function styleField(field,state,message),field.BackgroundColor=[1 1 1];field.FontColor=[0 0 0];field.FontAngle='normal';field.Tooltip=char(message);switch char(state),case 'specified',field.FontColor=[0.15 0.25 0.55];case 'calculated',field.BackgroundColor=[0.92 0.92 0.92];field.FontAngle='italic';case 'empty',field.BackgroundColor=[1 0.90 0.90];case 'external',field.BackgroundColor=[0.88 0.88 0.88];case 'conflict',field.BackgroundColor=[1 0.72 0.72];end,end
function result=failure(names,message),values=struct();origins=struct();states=struct();for i=1:numel(names),values.(names{i})=NaN;origins.(names{i})='empty';states.(names{i})='conflict';end;result=struct('values',values,'origins',origins,'states',states,'messages',string(message),'status','conflict','missingCount',0,'missing',strings(0,1),'conflicts',string(names));end
function value=number(x),if isempty(x),value='NaN';else,value=num2str(x,17);end,end
function value=onoff(flag),if flag,value='on';else,value='off';end,end
function value=label(names),if isempty(names),value='<missing>';else,value=char(strjoin(string(names),', '));end,end
function writeProducerSpecs(block,specs),if isempty(fieldnames(specs)),set_param(block,'Specifications','{}');else,nirp.dof.writeSpecs(block,specs);end,end
