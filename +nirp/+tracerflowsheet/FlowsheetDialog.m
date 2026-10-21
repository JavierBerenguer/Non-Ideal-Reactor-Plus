classdef FlowsheetDialog < handle
    % FlowsheetDialog edits the diagram-wide time grid.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 22, 2026. Last update: October 22, 2026
    % =========================================================================
    properties (SetAccess=private),BlockPath;Figure;DtField;TFinalField;UnitDropDown;StatusLabel;end
    methods
        function obj=FlowsheetDialog(block,varargin)
            p=inputParser;addParameter(p,'Visible','on');parse(p,varargin{:});obj.BlockPath=getfullname(block);assertSystem(obj.BlockPath,'nirp.tracerblocks.Flowsheet');obj.build(char(p.Results.Visible));obj.load();
        end
        function delete(obj),if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure),end,end
        function setValues(obj,dt,tFinal,unit),obj.DtField.Value=dt;obj.TFinalField.Value=tFinal;obj.UnitDropDown.Value=char(unit);end
        function value=getValues(obj),value=struct('dt',obj.DtField.Value,'tFinal',obj.TFinalField.Value,'unit',string(obj.UnitDropDown.Value));end
        function ok=apply(obj)
            ok=false;try,nirp.tracerflowsheet.validateSeparation(bdroot(obj.BlockPath));factor=nirp.tracerflowsheet.timeFactor(obj.UnitDropDown.Value);dt=obj.DtField.Value*factor;final=obj.TFinalField.Value*factor;nirp.tracerflowsheet.applyGrid(obj.BlockPath,dt,final);set_param(obj.BlockPath,'TimeUnit',obj.UnitDropDown.Value);obj.StatusLabel.Text='Fully specified';obj.StatusLabel.BackgroundColor=[.82 .94 .82];ok=true;catch e,obj.StatusLabel.Text=e.message;obj.StatusLabel.BackgroundColor=[1 .75 .75];end
        end
        function accept(obj),if obj.apply(),delete(obj),end,end
        function cancel(obj),delete(obj),end
    end
    methods (Static),function dialog=open(block),dialog=nirp.tracerflowsheet.FlowsheetDialog(block);end,end
    methods (Access=private)
        function load(obj),unit=get_param(obj.BlockPath,'TimeUnit');factor=nirp.tracerflowsheet.timeFactor(unit);obj.UnitDropDown.Value=unit;obj.DtField.Value=str2double(get_param(obj.BlockPath,'Dt'))/factor;obj.TFinalField.Value=str2double(get_param(obj.BlockPath,'TFinal'))/factor;end
        function build(obj,visible)
            obj.Figure=uifigure('Name','Tracer Flowsheet','Tag','NirpTracerFlowsheetDialog','Visible',visible,'Position',[200 150 560 330]);g=uigridlayout(obj.Figure,[6 3],'RowHeight',{35,35,35,45,25,38},'ColumnWidth',{150,'1x',90});
            title=uilabel(g,'Text','Common tracer time grid','FontWeight','bold','FontSize',15);title.Layout.Column=[1 3];uilabel(g,'Text','Time step, \Deltat','Interpreter','latex');obj.DtField=uieditfield(g,'numeric');obj.UnitDropDown=uidropdown(g,'Items',{'s','min','h'});uilabel(g,'Text','Final time, t_{final}','Interpreter','latex');obj.TFinalField=uieditfield(g,'numeric');uilabel(g,'Text','');
            note=uilabel(g,'Text','All NirpTracer vectors use t = 0:\Deltat:t_{final}; values beyond t_{final} are truncated.','Interpreter','latex','WordWrap','on');note.Layout.Column=[1 3];obj.StatusLabel=uilabel(g,'Text','Ready.','WordWrap','on');obj.StatusLabel.Layout.Column=[1 3];buttons(obj,g,'flowsheet');
        end
    end
end
function assertSystem(block,expected),if string(get_param(block,'System'))~=expected,error('nirp:tracerflowsheet:InvalidBlock','Dialog received the wrong block type.'),end,end
function buttons(obj,g,anchor),b=uigridlayout(g,[1 5],'ColumnWidth',{'1x',65,65,65,65});b.Layout.Column=[1 3];uilabel(b,'Text','');uibutton(b,'Text','Help','ButtonPushedFcn',@(~,~)openNirpGuide(nirp.tracerflowsheet.helpTarget(anchor)));uibutton(b,'Text','OK','ButtonPushedFcn',@(~,~)obj.accept());uibutton(b,'Text','Cancel','ButtonPushedFcn',@(~,~)obj.cancel());uibutton(b,'Text','Apply','ButtonPushedFcn',@(~,~)obj.apply());end
