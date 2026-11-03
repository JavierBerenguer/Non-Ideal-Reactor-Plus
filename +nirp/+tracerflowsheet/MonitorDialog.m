classdef MonitorDialog < handle
    % MonitorDialog configures tracer lost-area warnings.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 22, 2026. Last update: November 3, 2026
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
        function dialog=open(block),if nirp.tracerflowsheet.openLibraryBlockGuide(block),dialog=[];return,end;dialog=nirp.tracerflowsheet.MonitorDialog(block);end
    end
    methods (Access=private)
        function build(obj,visible)
            obj.Figure=uifigure('Name','Tracer Monitor','Tag','NirpTracerMonitorDialog','Visible',visible,'Position',[180 80 620 250]);
            g=uigridlayout(obj.Figure,[4 2],'RowHeight',{45,35,55,38},'ColumnWidth',{220,'1x'});
            t=uilabel(g,'Text','Network RTD monitor','FontWeight','bold','FontSize',15);t.Layout.Column=[1 2];
            uilabel(g,'Text','Lost-area warning (%)');obj.WarningField=uieditfield(g,'numeric');
            obj.StatusLabel=uilabel(g,'Text','Ready.','WordWrap','on');obj.StatusLabel.Layout.Column=[1 2];buttons(obj,g);
        end
    end
end
function buttons(obj,g),b=uigridlayout(g,[1 5],'ColumnWidth',{'1x',65,65,65,65});b.Layout.Column=[1 2];uilabel(b,'Text','');uibutton(b,'Text','Help','ButtonPushedFcn',@(~,~)openNirpGuide(nirp.tracerflowsheet.helpTarget('monitor')));uibutton(b,'Text','OK','ButtonPushedFcn',@(~,~)obj.accept());uibutton(b,'Text','Cancel','ButtonPushedFcn',@(~,~)obj.cancel());uibutton(b,'Text','Apply','ButtonPushedFcn',@(~,~)obj.apply());end
