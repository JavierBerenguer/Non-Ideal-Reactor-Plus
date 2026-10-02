classdef SplitterDialog < handle
%SPLITTERDIALOG Edit arbitrary Splitter outlets and their fractions.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================
    properties (SetAccess=private)
        BlockPath;Figure;NameField;FractionTable;ConnectionTable;StatusLabel;DataModel
    end
    methods
        function obj=SplitterDialog(blockPath,varargin),p=inputParser;addParameter(p,'Visible','on');parse(p,varargin{:});obj.BlockPath=getfullname(blockPath);if string(get_param(obj.BlockPath,'System'))~="nirp.blocks.Splitter",error('nirp:flowsheet:invalidBlock','SplitterDialog requires a Splitter block.');end;obj.build(char(string(p.Results.Visible)));obj.load();end
        function delete(obj),if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure);end,end
        function addOutlet(obj,fraction),if nargin<2,fraction=0;end;if size(obj.FractionTable.Data,1)>=20,error('nirp:flowsheet:portLimit','At most 20 outlets are supported.');end;d=obj.FractionTable.Data;d(end+1,:)={sprintf('<missing>'),fraction};obj.FractionTable.Data=d;obj.captureModel();end
        function removeOutlet(obj),d=obj.FractionTable.Data;if size(d,1)<=2,error('nirp:flowsheet:invalidPorts','A Splitter requires at least two outlets.');end;d(end,:)=[];obj.FractionTable.Data=d;obj.captureModel();end
        function setFractions(obj,fractions),fractions=fractions(:);if numel(fractions)<2||numel(fractions)>20,error('nirp:flowsheet:invalidPorts','A Splitter requires 2 to 20 outlets.');end;d=cell(numel(fractions),2);old=obj.FractionTable.Data;for i=1:numel(fractions),if i<=size(old,1),d{i,1}=old{i,1};else,d{i,1}='<missing>';end;d{i,2}=fractions(i);end;obj.FractionTable.Data=d;obj.captureModel();end
        function values=getValues(obj),obj.captureModel();values=obj.DataModel;end
        function apply(obj),fractions=cell2mat(obj.FractionTable.Data(:,2))';if any(~isfinite(fractions))||any(fractions<0)||any(fractions>1)||abs(sum(fractions)-1)>1e-12,error('nirp:flowsheet:invalidFractions','Fractions must be in [0,1] and sum to one within 1e-12.');end;set_param(obj.BlockPath,'Fractions',mat2str(fractions,17));set_param(bdroot(obj.BlockPath),'SimulationCommand','update');obj.StatusLabel.Text='Applied.';obj.refreshConnections();obj.captureModel();end
        function accept(obj),obj.apply();delete(obj);end
        function cancel(obj),delete(obj);end
    end
    methods (Static),function dialog=open(blockPath),dialog=nirp.flowsheet.SplitterDialog(blockPath);end,end
    methods (Access=private)
        function build(obj,visible),obj.Figure=uifigure('Name','Splitter','Tag','NirpSplitterDialog','Visible',visible,'Position',[130 90 720 520]);main=uigridlayout(obj.Figure,[4 1],'RowHeight',{38,'1x',25,38},'Padding',[12 10 12 10]);h=uigridlayout(main,[1 3],'ColumnWidth',{60,'1x',160});uilabel(h,'Text','Name','HorizontalAlignment','right');obj.NameField=uieditfield(h,'text','Editable','off');uibutton(h,'Text','Unit conversion helper','ButtonPushedFcn',@(~,~) UnitConverterHelper.launch());tabs=uitabgroup(main);split=uitab(tabs,'Title','Split fractions');connections=uitab(tabs,'Title','Connections');g=uigridlayout(split,[2 2],'RowHeight',{'1x',32},'ColumnWidth',{'1x',90});obj.FractionTable=uitable(g,'ColumnName',{'Outlet stream','Fraction'},'ColumnEditable',[false true]);obj.FractionTable.Layout.Row=1;obj.FractionTable.Layout.Column=[1 2];uibutton(g,'Text','Add outlet','ButtonPushedFcn',@(~,~) obj.addOutlet());uibutton(g,'Text','Remove','ButtonPushedFcn',@(~,~) obj.removeOutlet());cg=uigridlayout(connections,[2 1],'RowHeight',{30,'1x'});uilabel(cg,'Text','Connected material streams (read only)','FontWeight','bold');obj.ConnectionTable=uitable(cg,'ColumnName',{'Direction','Port','Stream'});obj.StatusLabel=uilabel(main,'Text','Ready.','FontAngle','italic');b=uigridlayout(main,[1 4],'ColumnWidth',{'1x',90,90,90});uibutton(b,'Text','OK','ButtonPushedFcn',@(~,~) obj.accept());uibutton(b,'Text','Apply','ButtonPushedFcn',@(~,~) obj.apply());uibutton(b,'Text','Cancel','ButtonPushedFcn',@(~,~) obj.cancel());end
        function load(obj),obj.NameField.Value=get_param(obj.BlockPath,'Name');fractions=str2num(get_param(obj.BlockPath,'Fractions'));obj.setFractions(fractions);obj.refreshConnections();end %#ok<ST2NM>
        function refreshConnections(obj),graph=nirp.flowsheet.topology(bdroot(obj.BlockPath));key=matlab.lang.makeValidName(get_param(obj.BlockPath,'Name'));data=cell(0,3);namesOut=strings(0,1);if isfield(graph.Units,key),x=graph.Units.(key);for i=1:numel(x.Inputs),data(end+1,:)={'Input',i,label(x.Inputs{i})};end;for i=1:numel(x.Outputs),name=label(x.Outputs{i});data(end+1,:)={'Output',i,name};namesOut(i)=string(name);end;end;obj.ConnectionTable.Data=data;table=obj.FractionTable.Data;for i=1:size(table,1),if i<=numel(namesOut),table{i,1}=char(namesOut(i));else,table{i,1}='<missing>';end;end;obj.FractionTable.Data=table;end
        function captureModel(obj),values=cell2mat(obj.FractionTable.Data(:,2))';obj.DataModel=struct('Fractions',struct('value',values,'unit',"1",'origin',"specified"));end
    end
end
function s=label(v),if isempty(v),s='<missing>';else,s=char(strjoin(string(v),', '));end,end
