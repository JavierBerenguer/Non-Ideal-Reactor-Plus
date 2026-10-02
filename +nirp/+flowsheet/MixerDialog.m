classdef MixerDialog < handle
%MIXERDIALOG Edit an arbitrary number of Mixer inlet streams.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================
    properties (SetAccess=private)
        BlockPath;Figure;NameField;ConnectionTable;StatusLabel;DataModel
    end
    methods
        function obj=MixerDialog(blockPath,varargin),p=inputParser;addParameter(p,'Visible','on');parse(p,varargin{:});obj.BlockPath=getfullname(blockPath);if string(get_param(obj.BlockPath,'System'))~="nirp.blocks.Mixer",error('nirp:flowsheet:invalidBlock','MixerDialog requires a Mixer block.');end;obj.build(char(string(p.Results.Visible)));obj.refreshConnections();end
        function delete(obj),if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure);end,end
        function setNumInputs(obj,count),if count<2||count>20||count~=fix(count),error('nirp:flowsheet:invalidPorts','A Mixer requires 2 to 20 inputs.');end;obj.DataModel.NumInputs.value=count;obj.rebuildRows(count);end
        function addInput(obj),obj.setNumInputs(obj.DataModel.NumInputs.value+1);end
        function removeInput(obj),obj.setNumInputs(obj.DataModel.NumInputs.value-1);end
        function values=getValues(obj),values=obj.DataModel;end
        function apply(obj),set_param(obj.BlockPath,'NumInputs',num2str(obj.DataModel.NumInputs.value));set_param(bdroot(obj.BlockPath),'SimulationCommand','update');obj.StatusLabel.Text='Applied.';obj.refreshConnections();end
        function accept(obj),obj.apply();delete(obj);end
        function cancel(obj),delete(obj);end
    end
    methods (Static),function dialog=open(blockPath),dialog=nirp.flowsheet.MixerDialog(blockPath);end,end
    methods (Access=private)
        function build(obj,visible),obj.Figure=uifigure('Name','Mixer','Tag','NirpMixerDialog','Visible',visible,'Position',[150 120 650 450]);main=uigridlayout(obj.Figure,[4 1],'RowHeight',{38,'1x',25,38},'Padding',[12 10 12 10]);h=uigridlayout(main,[1 3],'ColumnWidth',{60,'1x',160});uilabel(h,'Text','Name','HorizontalAlignment','right');obj.NameField=uieditfield(h,'text','Editable','off','Value',get_param(obj.BlockPath,'Name'));uibutton(h,'Text','Unit conversion helper','ButtonPushedFcn',@(~,~) UnitConverterHelper.launch());g=uigridlayout(main,[2 2],'RowHeight',{'1x',32},'ColumnWidth',{'1x',90});obj.ConnectionTable=uitable(g,'ColumnName',{'Direction','Port','Stream'});obj.ConnectionTable.Layout.Row=1;obj.ConnectionTable.Layout.Column=[1 2];uibutton(g,'Text','Add inlet','ButtonPushedFcn',@(~,~) obj.addInput());uibutton(g,'Text','Remove','ButtonPushedFcn',@(~,~) obj.removeInput());obj.StatusLabel=uilabel(main,'Text','Ready.','FontAngle','italic');b=uigridlayout(main,[1 4],'ColumnWidth',{'1x',90,90,90});uibutton(b,'Text','OK','ButtonPushedFcn',@(~,~) obj.accept());uibutton(b,'Text','Apply','ButtonPushedFcn',@(~,~) obj.apply());uibutton(b,'Text','Cancel','ButtonPushedFcn',@(~,~) obj.cancel());obj.DataModel=struct('NumInputs',struct('value',str2double(get_param(obj.BlockPath,'NumInputs')),'unit',"1",'origin',"specified"));end
        function rebuildRows(obj,count),old=obj.ConnectionTable.Data;data=cell(count+1,3);for i=1:count,data(i,:)={'Input',i,'<missing>'};end;data(end,:)={'Output',1,'<missing>'};for i=1:min(size(old,1),size(data,1)),if strcmp(old{i,1},data{i,1}),data{i,3}=old{i,3};end;end;obj.ConnectionTable.Data=data;end
        function refreshConnections(obj),count=str2double(get_param(obj.BlockPath,'NumInputs'));obj.DataModel=struct('NumInputs',struct('value',count,'unit',"1",'origin',"specified"));obj.rebuildRows(count);graph=nirp.flowsheet.topology(bdroot(obj.BlockPath));key=matlab.lang.makeValidName(get_param(obj.BlockPath,'Name'));data=obj.ConnectionTable.Data;if isfield(graph.Units,key),x=graph.Units.(key);for i=1:min(numel(x.Inputs),count),data{i,3}=label(x.Inputs{i});end;if ~isempty(x.Outputs),data{end,3}=label(x.Outputs{1});end;end;obj.ConnectionTable.Data=data;end
    end
end
function s=label(v),if isempty(v),s='<missing>';else,s=char(strjoin(string(v),', '));end,end
