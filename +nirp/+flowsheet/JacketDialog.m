classdef JacketDialog < handle
%JACKETDIALOG Structured editor for Jacket Simulink blocks.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 8, 2026. Last update: October 8, 2026
% =========================================================================
    properties (SetAccess=private)
        BlockPath; Figure; NameField; UField; UUnitDropDown
        AField; AUnitDropDown; ASourceDropDown; APortLabel
        UtilityTinField; UtilityTinUnitDropDown; UtilityTinSourceDropDown
        UtilityTinPortLabel; UtilityToutField; UtilityToutUnitDropDown
        UtilityCpField; CondensesCheckBox; LatentHeatField
        ConnectionTable; StatusLabel; DataModel
    end
    methods
        function obj=JacketDialog(blockPath,varargin)
            p=inputParser;addParameter(p,'Visible','on');parse(p,varargin{:});
            obj.BlockPath=getfullname(blockPath);
            if string(get_param(obj.BlockPath,'System'))~="nirp.blocks.Jacket"
                error('nirp:flowsheet:invalidBlock','JacketDialog requires a Jacket block.');
            end
            obj.build(char(string(p.Results.Visible)));obj.load();obj.refreshConnections();
        end
        function delete(obj),if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure);end,end
        function setValues(obj,varargin)
            for i=1:2:numel(varargin)
                key=lower(char(string(varargin{i})));value=varargin{i+1};
                map=struct('u','UField','a','AField','utilitytin','UtilityTinField', ...
                    'utilitytout','UtilityToutField','utilitycp','UtilityCpField', ...
                    'latentheat','LatentHeatField','asource','ASourceDropDown', ...
                    'utilitytinsource','UtilityTinSourceDropDown','condenses','CondensesCheckBox');
                if ~isfield(map,key),error('nirp:flowsheet:unknownParameter','Unknown jacket parameter "%s".',key);end
                field=obj.(map.(key));
                if isa(field,'matlab.ui.control.EditField'),field.Value=char(string(value));elseif isa(field,'matlab.ui.control.CheckBox'),field.Value=ison(value);else,field.Value=value;end
            end
            obj.updateVisibility();obj.captureModel();
        end
        function values=getValues(obj),obj.captureModel();values=obj.DataModel;end
        function connections=getConnections(obj),connections=obj.ConnectionTable.Data;end
        function applied=apply(obj)
            applied=false;
            try
                name=strtrim(obj.NameField.Value);if isempty(name),error('nirp:flowsheet:invalidName','Name cannot be empty.');end
                set_param(obj.BlockPath,'U',n(obj.UField.Value),'UUnit',obj.UUnitDropDown.Value, ...
                    'ASource',obj.ASourceDropDown.Value,'A',n(obj.AField.Value),'AUnit',obj.AUnitDropDown.Value, ...
                    'UtilityTinSource',obj.UtilityTinSourceDropDown.Value, ...
                    'UtilityTin',n(obj.UtilityTinField.Value),'UtilityTinUnit',obj.UtilityTinUnitDropDown.Value, ...
                    'UtilityTout',obj.UtilityToutField.Value,'UtilityToutUnit',obj.UtilityToutUnitDropDown.Value, ...
                    'UtilityCp',obj.UtilityCpField.Value,'Condenses',onoff(obj.CondensesCheckBox.Value), ...
                    'LatentHeat',obj.LatentHeatField.Value);
                if ~strcmp(name,get_param(obj.BlockPath,'Name')),set_param(obj.BlockPath,'Name',name);obj.BlockPath=[bdroot(obj.BlockPath) '/' name];end
                obj.StatusLabel.Text='Applied.';obj.captureModel();obj.refreshConnections();applied=true;
            catch exception,obj.StatusLabel.Text=exception.message;end
        end
        function accept(obj),if obj.apply(),delete(obj);end,end
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
            head=uigridlayout(main,[1 3],'ColumnWidth',{55,'1x',160});uilabel(head,'Text','Name','HorizontalAlignment','right');obj.NameField=uieditfield(head,'text');uibutton(head,'Text','Unit conversion helper','ButtonPushedFcn',@(~,~) UnitConverterHelper.launch());
            tabs=uitabgroup(main);general=uitab(tabs,'Title','Jacket');connections=uitab(tabs,'Title','Connections');
            grid=uigridlayout(general,[7 6],'ColumnWidth',{175,135,110,175,110,'1x'},'RowHeight',repmat({30},1,7));
            [obj.UField,obj.UUnitDropDown]=qty(grid,1,'U','HeatTransferCoefficient');
            [obj.AField,obj.AUnitDropDown]=qty(grid,2,'Area','Area');obj.APortLabel=portLabel(grid,2);
            [obj.UtilityTinField,obj.UtilityTinUnitDropDown]=qty(grid,3,'Utility inlet T','Temperature');obj.UtilityTinPortLabel=portLabel(grid,3);
            [obj.UtilityToutField,obj.UtilityToutUnitDropDown]=textqty(grid,4,'Utility outlet T (optional)','Temperature');
            obj.UtilityCpField=textfield(grid,5,'Utility Cp (J/(kg*K), optional)');
            obj.CondensesCheckBox=uicheckbox(grid,'Text','Utility condenses','ValueChangedFcn',@(~,~) obj.updateVisibility());obj.CondensesCheckBox.Layout.Row=6;obj.CondensesCheckBox.Layout.Column=[1 2];
            obj.LatentHeatField=textfield(grid,7,'Latent heat (J/kg)');
            obj.ASourceDropDown=drop(grid,1,'Area source',{'Dialog','Input port'});obj.UtilityTinSourceDropDown=drop(grid,2,'Utility inlet T source',{'Dialog','Input port'});obj.ASourceDropDown.ValueChangedFcn=@(~,~) obj.updateVisibility();obj.UtilityTinSourceDropDown.ValueChangedFcn=@(~,~) obj.updateVisibility();
            cgrid=uigridlayout(connections,[2 1],'RowHeight',{30,'1x'});uilabel(cgrid,'Text','Connected signals (read only)','FontWeight','bold');obj.ConnectionTable=uitable(cgrid,'ColumnName',{'Direction','Port','Signal'},'ColumnEditable',false);
            obj.StatusLabel=uilabel(main,'Text','Ready.','FontAngle','italic');buttons=uigridlayout(main,[1 4],'ColumnWidth',{'1x',90,90,90});uilabel(buttons,'Text','');uibutton(buttons,'Text','OK','ButtonPushedFcn',@(~,~) obj.accept());uibutton(buttons,'Text','Cancel','ButtonPushedFcn',@(~,~) obj.cancel());uibutton(buttons,'Text','Apply','ButtonPushedFcn',@(~,~) obj.apply());
        end
        function load(obj)
            obj.NameField.Value=get_param(obj.BlockPath,'Name');
            numeric={'U',obj.UField;'A',obj.AField;'UtilityTin',obj.UtilityTinField};for i=1:size(numeric,1),numeric{i,2}.Value=str2double(get_param(obj.BlockPath,numeric{i,1}));end
            text={'UtilityTout',obj.UtilityToutField;'UtilityCp',obj.UtilityCpField;'LatentHeat',obj.LatentHeatField};for i=1:size(text,1),text{i,2}.Value=get_param(obj.BlockPath,text{i,1});end
            values={'UUnit',obj.UUnitDropDown;'AUnit',obj.AUnitDropDown;'ASource',obj.ASourceDropDown;'UtilityTinUnit',obj.UtilityTinUnitDropDown;'UtilityTinSource',obj.UtilityTinSourceDropDown;'UtilityToutUnit',obj.UtilityToutUnitDropDown};for i=1:size(values,1),values{i,2}.Value=get_param(obj.BlockPath,values{i,1});end
            obj.CondensesCheckBox.Value=ison(get_param(obj.BlockPath,'Condenses'));obj.updateVisibility();obj.captureModel();
        end
        function updateVisibility(obj)
            inputA=strcmp(obj.ASourceDropDown.Value,'Input port');obj.AField.Visible=onoff(~inputA);obj.AField.Editable=onoff(~inputA);obj.APortLabel.Visible=onoff(inputA);
            inputTin=strcmp(obj.UtilityTinSourceDropDown.Value,'Input port');obj.UtilityTinField.Visible=onoff(~inputTin);obj.UtilityTinField.Editable=onoff(~inputTin);obj.UtilityTinPortLabel.Visible=onoff(inputTin);
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
    end
end
function [field,units]=qty(grid,row,label,category),text=uilabel(grid,'Text',label,'HorizontalAlignment','right');text.Layout.Row=row;text.Layout.Column=1;field=uieditfield(grid,'numeric');field.Layout.Row=row;field.Layout.Column=2;units=uidropdown(grid,'Items',UnitConverterHelper.getUnits(category));units.Layout.Row=row;units.Layout.Column=3;end
function [field,units]=textqty(grid,row,label,category),text=uilabel(grid,'Text',label,'HorizontalAlignment','right');text.Layout.Row=row;text.Layout.Column=1;field=uieditfield(grid,'text');field.Layout.Row=row;field.Layout.Column=2;units=uidropdown(grid,'Items',UnitConverterHelper.getUnits(category));units.Layout.Row=row;units.Layout.Column=3;end
function field=textfield(grid,row,label),text=uilabel(grid,'Text',label,'HorizontalAlignment','right');text.Layout.Row=row;text.Layout.Column=1;field=uieditfield(grid,'text');field.Layout.Row=row;field.Layout.Column=[2 3];end
function field=drop(grid,row,label,items),text=uilabel(grid,'Text',label,'HorizontalAlignment','right');text.Layout.Row=row;text.Layout.Column=4;field=uidropdown(grid,'Items',items);field.Layout.Row=row;field.Layout.Column=[5 6];end
function label=portLabel(grid,row),label=uilabel(grid,'Text','From input port','FontAngle','italic','Visible','off');label.Layout.Row=row;label.Layout.Column=2;end
function value=onoff(flag),if flag,value='on';else,value='off';end,end
function flag=ison(value),if islogical(value)||isnumeric(value),flag=logical(value);else,flag=strcmp(value,'on')||strcmp(value,'1');end,end
function value=n(x),value=num2str(x,17);end
function value=signalName(port),value='<missing>';line=get_param(port,'Line');if line==-1,return,end;source=get_param(line,'SrcBlockHandle');if source~=-1,value=get_param(source,'Name');end,end
function value=signalDestinations(port),value='<missing>';line=get_param(port,'Line');if line==-1,return,end;dest=get_param(line,'DstBlockHandle');dest=dest(dest~=-1);if ~isempty(dest),value=char(strjoin(string(arrayfun(@(h)get_param(h,'Name'),dest,'UniformOutput',false)),', '));end,end
