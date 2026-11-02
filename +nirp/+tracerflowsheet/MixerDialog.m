classdef MixerDialog < handle
    % MixerDialog edits inlet count and explains source-aware RTD mixing.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 22, 2026. Last update: October 22, 2026
    % =========================================================================
    properties (SetAccess=private),BlockPath;Figure;NumInputsField;StatusLabel;end
    methods
        function obj=MixerDialog(block,varargin),p=inputParser;addParameter(p,'Visible','on');parse(p,varargin{:});obj.BlockPath=getfullname(block);obj.build(char(p.Results.Visible));obj.NumInputsField.Value=str2double(get_param(obj.BlockPath,'NumInputs'));end
        function delete(obj),if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure),end,end
        function setNumInputs(obj,n),obj.NumInputsField.Value=n;end
        function value=getValues(obj),value=obj.NumInputsField.Value;end
        function ok=apply(obj),ok=false;try,nirp.tracerflowsheet.validateSeparation(bdroot(obj.BlockPath));n=obj.NumInputsField.Value;if n<2||n~=fix(n),error('nirp:tracerblocks:InvalidPorts','Mixer requires 2 or more integer inputs.'),end;set_param(obj.BlockPath,'NumInputs',num2str(n));obj.StatusLabel.Text='Fully specified';ok=true;catch e,obj.StatusLabel.Text=e.message;end,end
        function accept(obj),if obj.apply(),delete(obj),end,end
        function cancel(obj),delete(obj),end
    end
    methods (Static)
        function dialog=open(block)
            if nirp.tracerflowsheet.openLibraryBlockGuide(block),dialog=[];return,end
            dialog=nirp.tracerflowsheet.MixerDialog(block);
        end
    end
    methods (Access=private),function build(obj,visible),obj.Figure=uifigure('Name','Tracer Mixer','Tag','NirpTracerMixerDialog','Visible',visible,'Position',[240 180 520 290]);g=uigridlayout(obj.Figure,[5 2],'RowHeight',{35,35,65,25,38},'ColumnWidth',{170,'1x'});t=uilabel(g,'Text','$Q=\sum Q_i,\quad C=\sum Q_i C_i/Q$','Interpreter','latex','FontWeight','bold');t.Layout.Column=[1 2];uilabel(g,'Text','Number of inlets');obj.NumInputsField=uieditfield(g,'numeric');note=uilabel(g,'Text','Path RTD is defined only when all inlets share one source.','WordWrap','on');note.Layout.Column=[1 2];obj.StatusLabel=uilabel(g,'Text','Ready.');obj.StatusLabel.Layout.Column=[1 2];buttons(obj,g,'mixer');end,end
end
function buttons(obj,g,anchor),b=uigridlayout(g,[1 5],'ColumnWidth',{'1x',65,65,65,65});b.Layout.Column=[1 2];uilabel(b,'Text','');uibutton(b,'Text','Help','ButtonPushedFcn',@(~,~)openNirpGuide(nirp.tracerflowsheet.helpTarget(anchor)));uibutton(b,'Text','OK','ButtonPushedFcn',@(~,~)obj.accept());uibutton(b,'Text','Cancel','ButtonPushedFcn',@(~,~)obj.cancel());uibutton(b,'Text','Apply','ButtonPushedFcn',@(~,~)obj.apply());end
