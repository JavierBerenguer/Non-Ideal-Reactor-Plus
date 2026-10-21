classdef SourceDialog < handle
    % SourceDialog edits flow and a piecewise-function or tabular signal.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 22, 2026. Last update: October 22, 2026
    % =========================================================================
    properties (SetAccess=private),BlockPath;Figure;QField;QUnitDropDown;ModeDropDown;SignalTable;StatusLabel;end
    methods
        function obj=SourceDialog(block,varargin),p=inputParser;addParameter(p,'Visible','on');parse(p,varargin{:});obj.BlockPath=getfullname(block);assertSystem(obj.BlockPath,'nirp.tracerblocks.Source');obj.build(char(p.Results.Visible));obj.load();end
        function delete(obj),if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure),end,end
        function setFlow(obj,value,unit),obj.QField.Value=value;obj.QUnitDropDown.Value=char(unit);end
        function setData(obj,t,c),obj.ModeDropDown.Value='Data';obj.SignalTable.ColumnName={'t (s)','C (mol/m^3)'};obj.SignalTable.Data=num2cell([t(:) c(:)]);end
        function setFunction(obj,edges,expressions),obj.ModeDropDown.Value='Function';expressions=cellstr(string(expressions));obj.SignalTable.ColumnName={'Start t (s)','End t (s)','C(t) expression'};obj.SignalTable.Data=[num2cell([edges(1:end-1)' edges(2:end)']) expressions(:)];end
        function addRow(obj),d=obj.SignalTable.Data;if strcmp(obj.ModeDropDown.Value,'Data'),d(end+1,:)={0,0};else,d(end+1,:)={0,1,'0'};end;obj.SignalTable.Data=d;end
        function removeRow(obj),d=obj.SignalTable.Data;if size(d,1)>1,d(end,:)=[];obj.SignalTable.Data=d;end,end
        function importFile(obj,path),data=readmatrix(path);if size(data,2)<2,error('nirp:tracerflowsheet:InvalidImport','Imported signal needs time and concentration columns.'),end;obj.setData(data(:,1),data(:,2));end
        function importInteractive(obj),[file,folder]=uigetfile({'*.csv;*.txt;*.xlsx','Signal data'},'Import tracer signal');if isequal(file,0),return,end;obj.importFile(fullfile(folder,file));end
        function value=getValues(obj),value=struct('Q',obj.QField.Value,'QUnit',string(obj.QUnitDropDown.Value),'Mode',string(obj.ModeDropDown.Value),'Data',{obj.SignalTable.Data});end
        function ok=apply(obj)
            ok=false;try,nirp.tracerflowsheet.validateSeparation(bdroot(obj.BlockPath));q=UnitConverterHelper.convertToSI('VolumetricFlow',obj.QField.Value,obj.QUnitDropDown.Value);d=obj.SignalTable.Data;
                if strcmp(obj.ModeDropDown.Value,'Data'),values=cell2mat(d(:,1:2));nirp.tracer.sourceData(nirp.tracerflowsheet.gridForBlock(obj.BlockPath),q,values(:,1),values(:,2),1);set_param(obj.BlockPath,'DataTime',mat2str(values(:,1)',17),'DataConcentration',mat2str(values(:,2)',17));
                else,starts=cell2mat(d(:,1));ends=cell2mat(d(:,2));if any(abs(starts(2:end)-ends(1:end-1))>1e-12),error('nirp:tracerflowsheet:InvalidFunction','Function intervals must be contiguous.'),end;edges=[starts(1);ends];expressions=string(d(:,3));functions=cellstr("@(t)"+expressions);for k=1:numel(functions),functions{k}=str2func(functions{k});end;nirp.tracer.sourceFunction(nirp.tracerflowsheet.gridForBlock(obj.BlockPath),q,edges,functions,1);set_param(obj.BlockPath,'FunctionEdges',mat2str(edges',17),'FunctionExpressions',cellLiteral(expressions));end
                set_param(obj.BlockPath,'Q',num2str(q,17),'QUnit',obj.QUnitDropDown.Value,'SignalMode',obj.ModeDropDown.Value);obj.StatusLabel.Text='Fully specified';obj.StatusLabel.BackgroundColor=[.82 .94 .82];ok=true;
            catch e,obj.StatusLabel.Text=e.message;obj.StatusLabel.BackgroundColor=[1 .75 .75];end
        end
        function accept(obj),if obj.apply(),delete(obj),end,end
        function cancel(obj),delete(obj),end
    end
    methods (Static),function dialog=open(block),dialog=nirp.tracerflowsheet.SourceDialog(block);end,end
    methods (Access=private)
        function load(obj),obj.QUnitDropDown.Value=get_param(obj.BlockPath,'QUnit');obj.QField.Value=UnitConverterHelper.convertFromSI('VolumetricFlow',str2double(get_param(obj.BlockPath,'Q')),obj.QUnitDropDown.Value);mode=get_param(obj.BlockPath,'SignalMode');if strcmpi(mode,'Data'),obj.setData(str2num(get_param(obj.BlockPath,'DataTime')),str2num(get_param(obj.BlockPath,'DataConcentration')));else,obj.setFunction(str2num(get_param(obj.BlockPath,'FunctionEdges')),eval(get_param(obj.BlockPath,'FunctionExpressions')));end,end %#ok<ST2NM,EVLDIR>
        function build(obj,visible),obj.Figure=uifigure('Name','Tracer Source','Tag','NirpTracerSourceDialog','Visible',visible,'Position',[180 100 720 520]);g=uigridlayout(obj.Figure,[6 3],'RowHeight',{35,35,35,'1x',25,38},'ColumnWidth',{150,'1x',230});t=uilabel(g,'Text','Tracer inlet, C_{in}(t)','Interpreter','latex','FontWeight','bold');t.Layout.Column=[1 3];uilabel(g,'Text','Volumetric flow, Q');obj.QField=uieditfield(g,'numeric');obj.QUnitDropDown=uidropdown(g,'Items',UnitConverterHelper.getUnits('VolumetricFlow'));uilabel(g,'Text','Signal definition');obj.ModeDropDown=uidropdown(g,'Items',{'Data','Function'});panel=uigridlayout(g,[1 3],'ColumnWidth',{65,75,75});uibutton(panel,'Text','Add row','ButtonPushedFcn',@(~,~)obj.addRow());uibutton(panel,'Text','Remove','ButtonPushedFcn',@(~,~)obj.removeRow());uibutton(panel,'Text','Import...','ButtonPushedFcn',@(~,~)obj.importInteractive());obj.SignalTable=uitable(g,'ColumnEditable',true);obj.SignalTable.Layout.Column=[1 3];obj.StatusLabel=uilabel(g,'Text','Ready.','WordWrap','on');obj.StatusLabel.Layout.Column=[1 3];buttons(obj,g,'source');end
    end
end
function text=cellLiteral(values),quoted="'"+replace(values,"'","''")+"'";text=['{' char(strjoin(quoted,',')) '}'];end
function assertSystem(block,expected),if string(get_param(block,'System'))~=expected,error('nirp:tracerflowsheet:InvalidBlock','Dialog received the wrong block type.'),end,end
function buttons(obj,g,anchor),b=uigridlayout(g,[1 5],'ColumnWidth',{'1x',65,65,65,65});b.Layout.Column=[1 3];uilabel(b,'Text','');uibutton(b,'Text','Help','ButtonPushedFcn',@(~,~)openNirpGuide(nirp.tracerflowsheet.helpTarget(anchor)));uibutton(b,'Text','OK','ButtonPushedFcn',@(~,~)obj.accept());uibutton(b,'Text','Cancel','ButtonPushedFcn',@(~,~)obj.cancel());uibutton(b,'Text','Apply','ButtonPushedFcn',@(~,~)obj.apply());end
