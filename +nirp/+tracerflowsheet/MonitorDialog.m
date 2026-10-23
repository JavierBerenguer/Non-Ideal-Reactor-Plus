classdef MonitorDialog < handle
    % MonitorDialog configures truncation warning and describes outputs.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 22, 2026. Last update: October 23, 2026
    % =========================================================================
    properties (SetAccess=private),BlockPath;Figure;WarningField;StatusLabel;end
    methods
        function obj=MonitorDialog(block,varargin),p=inputParser;addParameter(p,'Visible','on');parse(p,varargin{:});obj.BlockPath=getfullname(block);obj.build(char(p.Results.Visible));obj.WarningField.Value=100*str2double(get_param(obj.BlockPath,'LostAreaWarning'));end
        function delete(obj),if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure),end,end
        function value=getValues(obj),value=obj.WarningField.Value/100;end
        function ok=apply(obj),ok=false;try,nirp.tracerflowsheet.validateSeparation(bdroot(obj.BlockPath));value=obj.getValues();if value<0||value>=1,error('nirp:tracerflowsheet:InvalidThreshold','Lost-area threshold must be in [0, 100).'),end;set_param(obj.BlockPath,'LostAreaWarning',num2str(value,17));obj.StatusLabel.Text='Fully specified';ok=true;catch e,obj.StatusLabel.Text=e.message;end,end
        function accept(obj),if obj.apply(),delete(obj),end,end
        function cancel(obj),delete(obj),end
    end
    methods (Static)
        function dialog=open(block)
            if nirp.tracerflowsheet.openLibraryBlockGuide(block),dialog=[];return,end
            dialog=nirp.tracerflowsheet.MonitorDialog(block);
        end
    end
    methods (Access=private),function build(obj,visible),obj.Figure=uifigure('Name','Tracer Monitor','Tag','NirpTracerMonitorDialog','Visible',visible,'Position',[230 140 600 340]);g=uigridlayout(obj.Figure,[6 2],'RowHeight',{35,55,35,55,25,38},'ColumnWidth',{220,'1x'});t=uilabel(g,'Text','C(t), τ, σ², σ²θ, N ≈ 1/σ²θ','FontWeight','bold');t.Layout.Column=[1 2];note=uilabel(g,'Text','The inlet signal of the source is shown for comparison; the accumulated E(t) is the network RTD.','WordWrap','on');note.Layout.Column=[1 2];uilabel(g,'Text','Lost-area warning (%)');obj.WarningField=uieditfield(g,'numeric');use=uilabel(g,'Text','Use as RTD in Tab 1 is disabled when status indicates multiple sources.','WordWrap','on');use.Layout.Column=[1 2];obj.StatusLabel=uilabel(g,'Text','Ready.');obj.StatusLabel.Layout.Column=[1 2];buttons(obj,g,'monitor');end,end
end
function buttons(obj,g,anchor),b=uigridlayout(g,[1 5],'ColumnWidth',{'1x',65,65,65,65});b.Layout.Column=[1 2];uilabel(b,'Text','');uibutton(b,'Text','Help','ButtonPushedFcn',@(~,~)openNirpGuide(nirp.tracerflowsheet.helpTarget(anchor)));uibutton(b,'Text','OK','ButtonPushedFcn',@(~,~)obj.accept());uibutton(b,'Text','Cancel','ButtonPushedFcn',@(~,~)obj.cancel());uibutton(b,'Text','Apply','ButtonPushedFcn',@(~,~)obj.apply());end
