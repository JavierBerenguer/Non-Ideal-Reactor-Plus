classdef HeaterDialog < handle
%HEATERDIALOG Structured editor for Heater/Cooler Simulink blocks.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 7, 2026
% =========================================================================
    properties (SetAccess=private)
        BlockPath;Figure;NameField;ModeGroup;ToutField;ToutUnitDropDown
        DutyField;DutyUnitDropDown;PressureDropField;PressureDropUnitDropDown
        HeatPortCheckBox;ConnectionTable;StatusLabel;DataModel
    end
    properties (Access=private),GeneralGrid,end
    methods
        function obj=HeaterDialog(blockPath,varargin)
            p=inputParser;addParameter(p,'Visible','on');parse(p,varargin{:});obj.BlockPath=getfullname(blockPath);
            if string(get_param(obj.BlockPath,'System'))~="nirp.blocks.Heater",error('nirp:flowsheet:invalidBlock','HeaterDialog requires a Heater block.');end
            obj.build(char(string(p.Results.Visible)));obj.load();obj.refreshConnections();
        end
        function delete(obj),if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure);end,end
        function setMode(obj,mode),b=obj.ModeGroup.Children;i=find(strcmp({b.Text},char(string(mode))),1);if isempty(i),error('nirp:flowsheet:invalidMode','Unknown heater mode.');end;obj.ModeGroup.SelectedObject=b(i);obj.updateVisibility();obj.captureModel();end
        function setValues(obj,varargin),for i=1:2:numel(varargin),switch lower(char(string(varargin{i}))),case {'tout','temperature'},obj.ToutField.Value=varargin{i+1};case {'duty','q'},obj.DutyField.Value=varargin{i+1};case {'pressuredrop','dp'},obj.PressureDropField.Value=varargin{i+1};case 'mode',obj.setMode(varargin{i+1});otherwise,error('nirp:flowsheet:unknownParameter','Unknown heater parameter.');end,end;obj.captureModel();end
        function values=getValues(obj),obj.captureModel();values=obj.DataModel;end
        function applied=apply(obj)
            applied=false;try,name=strtrim(obj.NameField.Value);if isempty(name),error('nirp:flowsheet:invalidName','Name cannot be empty.');end
            set_param(obj.BlockPath,'Mode',obj.ModeGroup.SelectedObject.Text,'Tout',num2str(obj.ToutField.Value,17),'ToutUnit',obj.ToutUnitDropDown.Value,'Duty',num2str(obj.DutyField.Value,17),'DutyUnit',obj.DutyUnitDropDown.Value,'PressureDrop',num2str(obj.PressureDropField.Value,17),'PressureDropUnit',obj.PressureDropUnitDropDown.Value,'ShowHeatPort',onoff(obj.HeatPortCheckBox.Value));
            if ~strcmp(name,get_param(obj.BlockPath,'Name')),set_param(obj.BlockPath,'Name',name);obj.BlockPath=[bdroot(obj.BlockPath) '/' name];end;obj.StatusLabel.Text='Applied.';obj.captureModel();obj.refreshConnections();applied=true;catch exception,obj.StatusLabel.Text=exception.message;end
        end
        function accept(obj),if obj.apply(),delete(obj);end,end
        function cancel(obj),delete(obj);end
    end
    methods (Static),function dialog=open(blockPath),dialog=nirp.flowsheet.HeaterDialog(blockPath);end,end
    methods (Access=private)
        function build(obj,visible)
            obj.Figure=uifigure('Name','Heater / Cooler','Tag','NirpHeaterDialog','Visible',visible,'Position',[120 100 720 470],'WindowStyle','alwaysontop');main=uigridlayout(obj.Figure,[4 1],'RowHeight',{40,'1x',25,38},'Padding',[12 10 12 10]);
            h=uigridlayout(main,[1 4],'ColumnWidth',{160,60,'1x',180});uibutton(h,'Text','Unit conversion helper','ButtonPushedFcn',@(~,~) UnitConverterHelper.launch());uilabel(h,'Text','Name','HorizontalAlignment','right');obj.NameField=uieditfield(h,'text');
            tabs=uitabgroup(main);general=uitab(tabs,'Title','Heater / Cooler');connections=uitab(tabs,'Title','Connections');g=uigridlayout(general,[6 3],'ColumnWidth',{210,170,130},'RowHeight',{72,32,32,32,32,'1x'});obj.GeneralGrid=g;
            obj.ModeGroup=uibuttongroup(g,'Title','Mode','SelectionChangedFcn',@(~,~) obj.updateVisibility());obj.ModeGroup.Layout.Row=1;obj.ModeGroup.Layout.Column=[1 3];uiradiobutton(obj.ModeGroup,'Text','Outlet T','Position',[20 12 120 22]);uiradiobutton(obj.ModeGroup,'Text','Duty','Position',[180 12 120 22]);
            [obj.ToutField,obj.ToutUnitDropDown]=qrow(g,2,'Outlet T','Temperature');[obj.DutyField,obj.DutyUnitDropDown]=qrow(g,3,'Duty','Power');[obj.PressureDropField,obj.PressureDropUnitDropDown]=qrow(g,4,'Pressure drop','Pressure');obj.HeatPortCheckBox=uicheckbox(g,'Text','Show heat port');obj.HeatPortCheckBox.Layout.Row=5;obj.HeatPortCheckBox.Layout.Column=[2 3];
            cg=uigridlayout(connections,[2 1],'RowHeight',{30,'1x'});uilabel(cg,'Text','Connected material streams (read only)','FontWeight','bold');obj.ConnectionTable=uitable(cg,'ColumnName',{'Direction','Port','Stream'},'ColumnEditable',false);
            obj.StatusLabel=uilabel(main,'Text','Ready.','FontAngle','italic');buttons=uigridlayout(main,[1 4],'ColumnWidth',{'1x',90,90,90});uilabel(buttons,'Text','');uibutton(buttons,'Text','OK','ButtonPushedFcn',@(~,~) obj.accept());uibutton(buttons,'Text','Cancel','ButtonPushedFcn',@(~,~) obj.cancel());uibutton(buttons,'Text','Apply','ButtonPushedFcn',@(~,~) obj.apply());
        end
        function load(obj),obj.NameField.Value=get_param(obj.BlockPath,'Name');obj.ToutField.Value=str2double(get_param(obj.BlockPath,'Tout'));obj.ToutUnitDropDown.Value=get_param(obj.BlockPath,'ToutUnit');obj.DutyField.Value=str2double(get_param(obj.BlockPath,'Duty'));obj.DutyUnitDropDown.Value=get_param(obj.BlockPath,'DutyUnit');obj.PressureDropField.Value=str2double(get_param(obj.BlockPath,'PressureDrop'));obj.PressureDropUnitDropDown.Value=get_param(obj.BlockPath,'PressureDropUnit');obj.HeatPortCheckBox.Value=strcmp(get_param(obj.BlockPath,'ShowHeatPort'),'on');obj.setMode(get_param(obj.BlockPath,'Mode'));end
        function updateVisibility(obj),outlet=strcmp(obj.ModeGroup.SelectedObject.Text,'Outlet T');rowVisible(obj.GeneralGrid,2,outlet);rowVisible(obj.GeneralGrid,3,~outlet);end
        function refreshConnections(obj),graph=nirp.flowsheet.topology(bdroot(obj.BlockPath));key=matlab.lang.makeValidName(get_param(obj.BlockPath,'Name'));data=cell(0,3);if isfield(graph.Units,key),x=graph.Units.(key);for i=1:numel(x.Inputs),data(end+1,:)={'Input',i,names(x.Inputs{i})};end;for i=1:numel(x.Outputs),data(end+1,:)={'Output',i,names(x.Outputs{i})};end;end;obj.ConnectionTable.Data=data;end
        function captureModel(obj),q=@(v,u) struct('value',v,'unit',string(u),'origin',"specified");obj.DataModel=struct('Tout',q(obj.ToutField.Value,obj.ToutUnitDropDown.Value),'Duty',q(obj.DutyField.Value,obj.DutyUnitDropDown.Value),'PressureDrop',q(obj.PressureDropField.Value,obj.PressureDropUnitDropDown.Value));end
    end
end
function [f,u]=qrow(g,row,label,category),t=uilabel(g,'Text',label,'HorizontalAlignment','right');t.Layout.Row=row;t.Layout.Column=1;f=uieditfield(g,'numeric');f.Layout.Row=row;f.Layout.Column=2;u=uidropdown(g,'Items',UnitConverterHelper.getUnits(category));u.Layout.Row=row;u.Layout.Column=3;end
function s=onoff(v),if v,s='on';else,s='off';end,end
function s=names(v),if isempty(v),s='<missing>';else,s=char(strjoin(string(v),', '));end,end
function rowVisible(grid,row,flag),c=grid.Children;for i=1:numel(c),if any(c(i).Layout.Row==row),c(i).Visible=onoff(flag);end,end,end
