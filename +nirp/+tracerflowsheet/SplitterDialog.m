classdef SplitterDialog < handle
    % SplitterDialog edits N-1 specified fractions and shows the remainder.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 22, 2026. Last update: October 22, 2026
    % =========================================================================
    properties (SetAccess=private),BlockPath;Figure;FractionTable;StatusLabel;end
    methods
        function obj=SplitterDialog(block,varargin),p=inputParser;addParameter(p,'Visible','on');parse(p,varargin{:});obj.BlockPath=getfullname(block);assertSystem(obj.BlockPath,'nirp.tracerblocks.Splitter');obj.build(char(p.Results.Visible));obj.setFractions(str2num(get_param(obj.BlockPath,'Fractions')));end %#ok<ST2NM>
        function delete(obj),if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure),end,end
        function setFractions(obj,f),f=reshape(f,1,[]);remainder=1-sum(f);outlets=cellstr(string((1:numel(f)+1)'));obj.FractionTable.Data=[outlets num2cell([f remainder]')];end
        function addRow(obj),d=obj.FractionTable.Data;specified=cell2mat(d(1:end-1,2));specified(end+1)=0;obj.setFractions(specified);end
        function removeRow(obj),d=obj.FractionTable.Data;if size(d,1)>2,obj.setFractions(cell2mat(d(1:end-2,2)));end,end
        function value=getValues(obj),d=obj.FractionTable.Data;value=cell2mat(d(:,2))';end
        function ok=apply(obj),ok=false;try,nirp.tracerflowsheet.validateSeparation(bdroot(obj.BlockPath));values=obj.getValues();specified=values(1:end-1);[~,closed]=nirp.tracer.splitter(nirp.tracerflowsheet.gridForBlock(obj.BlockPath),nirp.tracer.source(nirp.tracerflowsheet.gridForBlock(obj.BlockPath),1,ones(1,nirp.tracerflowsheet.gridForBlock(obj.BlockPath).length),1),specified);obj.setFractions(specified);set_param(obj.BlockPath,'Fractions',mat2str(specified,17));set_param(bdroot(obj.BlockPath),'SimulationCommand','update');obj.StatusLabel.Text=sprintf('Fully specified; calculated final fraction = %.6g',closed(end));obj.StatusLabel.BackgroundColor=[.82 .94 .82];ok=true;catch e,obj.StatusLabel.Text=e.message;obj.StatusLabel.BackgroundColor=[1 .75 .75];end,end
        function accept(obj),if obj.apply(),delete(obj),end,end
        function cancel(obj),delete(obj),end
    end
    methods (Static)
        function dialog=open(block)
            if nirp.tracerflowsheet.openLibraryBlockGuide(block),dialog=[];return,end
            dialog=nirp.tracerflowsheet.SplitterDialog(block);
        end
    end
    methods (Access=private),function build(obj,visible),obj.Figure=uifigure('Name','Tracer Splitter','Tag','NirpTracerSplitterDialog','Visible',visible,'Position',[220 120 560 430]);g=uigridlayout(obj.Figure,[5 3],'RowHeight',{45,'1x',32,25,38},'ColumnWidth',{90,90,'1x'});note=uilabel(g,'Text','Specify N-1 fractions; the last outlet is calculated so all fractions sum to 1.');note.Layout.Row=1;note.Layout.Column=[1 3];obj.FractionTable=uitable(g,'ColumnName',{'Outlet','Fraction'},'ColumnEditable',[false true]);obj.FractionTable.Layout.Row=2;obj.FractionTable.Layout.Column=[1 3];add=uibutton(g,'Text','Add outlet','ButtonPushedFcn',@(~,~)obj.addRow());add.Layout.Row=3;add.Layout.Column=1;remove=uibutton(g,'Text','Remove','ButtonPushedFcn',@(~,~)obj.removeRow());remove.Layout.Row=3;remove.Layout.Column=2;obj.StatusLabel=uilabel(g,'Text','Ready.','WordWrap','on');obj.StatusLabel.Layout.Row=4;obj.StatusLabel.Layout.Column=[1 3];buttons(obj,g,'splitter');end,end
end
function assertSystem(block,expected),if string(get_param(block,'System'))~=expected,error('nirp:tracerflowsheet:InvalidBlock','Dialog received the wrong block type.'),end,end
function buttons(obj,g,anchor),b=uigridlayout(g,[1 5],'ColumnWidth',{'1x',65,65,65,65});b.Layout.Row=5;b.Layout.Column=[1 3];uilabel(b,'Text','');uibutton(b,'Text','Help','ButtonPushedFcn',@(~,~)openNirpGuide(nirp.tracerflowsheet.helpTarget(anchor)));uibutton(b,'Text','OK','ButtonPushedFcn',@(~,~)obj.accept());uibutton(b,'Text','Cancel','ButtonPushedFcn',@(~,~)obj.cancel());uibutton(b,'Text','Apply','ButtonPushedFcn',@(~,~)obj.apply());end
