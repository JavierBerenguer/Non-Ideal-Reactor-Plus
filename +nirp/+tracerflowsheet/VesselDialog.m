classdef VesselDialog < handle
    % VesselDialog selects a model, data, or app session RTD.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 22, 2026. Last update: October 22, 2026
    % =========================================================================
    properties (SetAccess=private),BlockPath;Figure;OriginDropDown;ModelDropDown;BasisDropDown;TauField;VolumeField;NField;PeField;BoundaryDropDown;DataTable;SessionField;StatusLabel;end
    methods
        function obj=VesselDialog(block,varargin),p=inputParser;addParameter(p,'Visible','on');parse(p,varargin{:});obj.BlockPath=getfullname(block);assertSystem(obj.BlockPath,'nirp.tracerblocks.Vessel');obj.build(char(p.Results.Visible));obj.load();end
        function delete(obj),if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure),end,end
        function setModel(obj,model,varargin),obj.OriginDropDown.Value='Model';obj.ModelDropDown.Value=char(model);for k=1:2:numel(varargin),name=lower(varargin{k});value=varargin{k+1};switch name,case 'tau',obj.BasisDropDown.Value='Tau';obj.TauField.Value=value;case 'volume',obj.BasisDropDown.Value='Volume';obj.VolumeField.Value=value;case 'n',obj.NField.Value=value;case 'pe',obj.PeField.Value=value;case 'boundary',obj.BoundaryDropDown.Value=char(value);end,end,end
        function setData(obj,t,e),obj.OriginDropDown.Value='Data';obj.DataTable.Data=num2cell([t(:) e(:)]);end
        function setSession(obj,path),obj.OriginDropDown.Value='Session';obj.SessionField.Value=char(path);end
        function value=getValues(obj),value=struct('Origin',string(obj.OriginDropDown.Value),'Model',string(obj.ModelDropDown.Value),'Basis',string(obj.BasisDropDown.Value),'Tau',obj.TauField.Value,'Volume',obj.VolumeField.Value,'N',obj.NField.Value,'Pe',obj.PeField.Value,'Boundary',string(obj.BoundaryDropDown.Value),'Data',{obj.DataTable.Data},'Session',string(obj.SessionField.Value));end
        function ok=apply(obj)
            ok=false;try,nirp.tracerflowsheet.validateSeparation(bdroot(obj.BlockPath));grid=nirp.tracerflowsheet.gridForBlock(obj.BlockPath);origin=obj.OriginDropDown.Value;
                switch origin
                    case 'Model',if strcmp(obj.BasisDropDown.Value,'Volume'),parameters=struct('V',obj.VolumeField.Value);else,parameters=struct('tau',obj.TauField.Value);end;if strcmp(obj.ModelDropDown.Value,'Tanks'),parameters.N=obj.NField.Value;end;if strcmp(obj.ModelDropDown.Value,'Dispersion'),parameters.Pe=obj.PeField.Value;parameters.boundary=obj.BoundaryDropDown.Value;end;nirp.tracer.rtdModel(grid,obj.ModelDropDown.Value,parameters,1);set_param(obj.BlockPath,'Model',obj.ModelDropDown.Value,'ResidenceBasis',obj.BasisDropDown.Value,'Tau',num2str(obj.TauField.Value,17),'Volume',num2str(obj.VolumeField.Value,17),'N',num2str(obj.NField.Value,17),'Pe',num2str(obj.PeField.Value,17),'Boundary',obj.BoundaryDropDown.Value);
                    case 'Data',d=cell2mat(obj.DataTable.Data(:,1:2));nirp.tracer.rtdData(grid,d(:,1),d(:,2));set_param(obj.BlockPath,'DataTime',mat2str(d(:,1)',17),'DataE',mat2str(d(:,2)',17));
                    case 'Session',nirp.tracer.rtdSession(grid,obj.SessionField.Value);set_param(obj.BlockPath,'SessionFile',obj.SessionField.Value);
                end
                set_param(obj.BlockPath,'Origin',origin);obj.StatusLabel.Text='Fully specified';obj.StatusLabel.BackgroundColor=[.82 .94 .82];ok=true;
            catch e,obj.StatusLabel.Text=e.message;obj.StatusLabel.BackgroundColor=[1 .75 .75];end
        end
        function accept(obj),if obj.apply(),delete(obj),end,end
        function cancel(obj),delete(obj),end
    end
    methods (Static)
        function dialog=open(block)
            if nirp.tracerflowsheet.openLibraryBlockGuide(block),dialog=[];return,end
            dialog=nirp.tracerflowsheet.VesselDialog(block);
        end
    end
    methods (Access=private)
        function load(obj),obj.OriginDropDown.Value=get_param(obj.BlockPath,'Origin');obj.ModelDropDown.Value=get_param(obj.BlockPath,'Model');obj.BasisDropDown.Value=get_param(obj.BlockPath,'ResidenceBasis');obj.TauField.Value=str2double(get_param(obj.BlockPath,'Tau'));obj.VolumeField.Value=str2double(get_param(obj.BlockPath,'Volume'));obj.NField.Value=str2double(get_param(obj.BlockPath,'N'));obj.PeField.Value=str2double(get_param(obj.BlockPath,'Pe'));obj.BoundaryDropDown.Value=get_param(obj.BlockPath,'Boundary');obj.DataTable.Data=num2cell([str2num(get_param(obj.BlockPath,'DataTime'))' str2num(get_param(obj.BlockPath,'DataE'))']);obj.SessionField.Value=get_param(obj.BlockPath,'SessionFile');end %#ok<ST2NM>
        function build(obj,visible),obj.Figure=uifigure('Name','Non-ideal Vessel','Tag','NirpTracerVesselDialog','Visible',visible,'Position',[170 80 780 620]);g=uigridlayout(obj.Figure,[10 3],'RowHeight',{35,35,35,35,35,35,35,'1x',25,38},'ColumnWidth',{170,'1x',120});title=uilabel(g,'Text','$C_{out}(t)=C_{in}(t)*E_v(t)$','Interpreter','latex','FontWeight','bold');title.Layout.Column=[1 3];uilabel(g,'Text','RTD origin');obj.OriginDropDown=uidropdown(g,'Items',{'Model','Data','Session'});uilabel(g,'Text','');uilabel(g,'Text','Model');obj.ModelDropDown=uidropdown(g,'Items',{'CSTR','PFR','Tanks','Dispersion'});obj.BasisDropDown=uidropdown(g,'Items',{'Tau','Volume'});uilabel(g,'Text','Residence time, τ (s)');obj.TauField=uieditfield(g,'numeric');uilabel(g,'Text','');uilabel(g,'Text','Volume, V (m³)');obj.VolumeField=uieditfield(g,'numeric');uilabel(g,'Text','');uilabel(g,'Text','Tanks, N');obj.NField=uieditfield(g,'numeric');uilabel(g,'Text','');uilabel(g,'Text','Peclet number, Pe');obj.PeField=uieditfield(g,'numeric');obj.BoundaryDropDown=uidropdown(g,'Items',{'open','closed'});uilabel(g,'Text','Session (.mat)');obj.SessionField=uieditfield(g,'text');uilabel(g,'Text','');obj.DataTable=uitable(g,'ColumnName',{'t (s)','E (1/s)'},'ColumnEditable',true);obj.DataTable.Layout.Column=[1 3];obj.StatusLabel=uilabel(g,'Text','Ready.','WordWrap','on');obj.StatusLabel.Layout.Column=[1 3];buttons(obj,g,'vessel');end
    end
end
function assertSystem(block,expected),if string(get_param(block,'System'))~=expected,error('nirp:tracerflowsheet:InvalidBlock','Dialog received the wrong block type.'),end,end
function buttons(obj,g,anchor),b=uigridlayout(g,[1 5],'ColumnWidth',{'1x',65,65,65,65});b.Layout.Column=[1 3];uilabel(b,'Text','');uibutton(b,'Text','Help','ButtonPushedFcn',@(~,~)openNirpGuide(nirp.tracerflowsheet.helpTarget(anchor)));uibutton(b,'Text','OK','ButtonPushedFcn',@(~,~)obj.accept());uibutton(b,'Text','Cancel','ButtonPushedFcn',@(~,~)obj.cancel());uibutton(b,'Text','Apply','ButtonPushedFcn',@(~,~)obj.apply());end
