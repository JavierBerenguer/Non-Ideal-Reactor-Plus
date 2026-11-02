classdef VesselDialog < handle
    % VesselDialog selects a model, data, or app session RTD.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 22, 2026. Last update: October 23, 2026
    % =========================================================================
    properties (SetAccess=private)
        BlockPath; Figure; OriginDropDown; ModelDropDown; BasisDropDown;
        TauField; VolumeField; NField; PeField; BoundaryDropDown;
        DataTable; SessionField; StatusLabel;
        AddRowButton; RemoveRowButton; ImportButton; BrowseButton;
    end
    methods
        function obj=VesselDialog(block,varargin)
            p=inputParser;addParameter(p,'Visible','on');parse(p,varargin{:});
            obj.BlockPath=getfullname(block);assertSystem(obj.BlockPath,'nirp.tracerblocks.Vessel');
            obj.build(char(p.Results.Visible));obj.load();
        end
        function delete(obj),if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure),end,end
        function setModel(obj,model,varargin)
            obj.OriginDropDown.Value='Model';obj.ModelDropDown.Value=char(model);
            for k=1:2:numel(varargin)
                name=lower(varargin{k});value=varargin{k+1};
                switch name
                    case 'tau',obj.BasisDropDown.Value='Tau';obj.TauField.Value=value;
                    case 'volume',obj.BasisDropDown.Value='Volume';obj.VolumeField.Value=value;
                    case 'n',obj.NField.Value=value;
                    case 'pe',obj.PeField.Value=value;
                    case 'boundary',obj.BoundaryDropDown.Value=char(value);
                end
            end
            obj.refreshControls();
        end
        function setData(obj,t,e)
            obj.OriginDropDown.Value='Data';obj.DataTable.Data=num2cell([t(:) e(:)]);obj.refreshControls();
        end
        function addRow(obj)
            data=obj.DataTable.Data;data(end+1,:)={0,0};obj.DataTable.Data=data;
        end
        function removeRow(obj)
            data=obj.DataTable.Data;if size(data,1)>1,data(end,:)=[];obj.DataTable.Data=data;end
        end
        function importFile(obj,path)
            data=nirp.tracerflowsheet.readTwoColumnFile(path,'RTD');obj.setData(data(:,1),data(:,2));
        end
        function importInteractive(obj)
            [file,folder]=uigetfile({'*.csv;*.txt;*.xlsx','RTD data'},'Import RTD data');
            if isequal(file,0),return,end
            obj.importFile(fullfile(folder,file));
        end
        function setSession(obj,path),obj.setSessionFile(path);end
        function setSessionFile(obj,path)
            obj.OriginDropDown.Value='Session';obj.SessionField.Value=char(path);obj.refreshControls();
        end
        function browseSession(obj)
            [file,folder]=uigetfile({'*.mat','MATLAB session (*.mat)'},'Select analysis session');
            if isequal(file,0),return,end
            obj.setSessionFile(fullfile(folder,file));
        end
        function value=getValues(obj)
            value=struct('Origin',string(obj.OriginDropDown.Value),'Model',string(obj.ModelDropDown.Value), ...
                'Basis',string(obj.BasisDropDown.Value),'Tau',obj.TauField.Value, ...
                'Volume',obj.VolumeField.Value,'N',obj.NField.Value,'Pe',obj.PeField.Value, ...
                'Boundary',string(obj.BoundaryDropDown.Value),'Data',{obj.DataTable.Data}, ...
                'Session',string(obj.SessionField.Value));
        end
        function ok=apply(obj)
            ok=false;
            try
                nirp.tracerflowsheet.validateSeparation(bdroot(obj.BlockPath));
                grid=nirp.tracerflowsheet.gridForBlock(obj.BlockPath);origin=obj.OriginDropDown.Value;
                switch origin
                    case 'Model'
                        if strcmp(obj.BasisDropDown.Value,'Volume'),parameters=struct('V',obj.VolumeField.Value);else,parameters=struct('tau',obj.TauField.Value);end
                        if strcmp(obj.ModelDropDown.Value,'Tanks'),parameters.N=obj.NField.Value;end
                        if strcmp(obj.ModelDropDown.Value,'Dispersion'),parameters.Pe=obj.PeField.Value;parameters.boundary=obj.BoundaryDropDown.Value;end
                        nirp.tracer.rtdModel(grid,obj.ModelDropDown.Value,parameters,1);
                        set_param(obj.BlockPath,'Model',obj.ModelDropDown.Value,'ResidenceBasis',obj.BasisDropDown.Value, ...
                            'Tau',num2str(obj.TauField.Value,17),'Volume',num2str(obj.VolumeField.Value,17), ...
                            'N',num2str(obj.NField.Value,17),'Pe',num2str(obj.PeField.Value,17), ...
                            'Boundary',obj.BoundaryDropDown.Value);
                    case 'Data'
                        data=cell2mat(obj.DataTable.Data(:,1:2));nirp.tracer.rtdData(grid,data(:,1),data(:,2));
                        set_param(obj.BlockPath,'DataTime',mat2str(data(:,1)',17),'DataE',mat2str(data(:,2)',17));
                    case 'Session'
                        nirp.tracer.rtdSession(grid,obj.SessionField.Value);
                        set_param(obj.BlockPath,'SessionFile',obj.SessionField.Value);
                end
                set_param(obj.BlockPath,'Origin',origin);obj.StatusLabel.Text='Fully specified';
                obj.StatusLabel.BackgroundColor=[.82 .94 .82];ok=true;
            catch exception
                obj.StatusLabel.Text=exception.message;obj.StatusLabel.BackgroundColor=[1 .75 .75];
            end
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
        function load(obj)
            obj.OriginDropDown.Value=get_param(obj.BlockPath,'Origin');
            obj.ModelDropDown.Value=get_param(obj.BlockPath,'Model');
            obj.BasisDropDown.Value=get_param(obj.BlockPath,'ResidenceBasis');
            obj.TauField.Value=str2double(get_param(obj.BlockPath,'Tau'));
            obj.VolumeField.Value=str2double(get_param(obj.BlockPath,'Volume'));
            obj.NField.Value=str2double(get_param(obj.BlockPath,'N'));
            obj.PeField.Value=str2double(get_param(obj.BlockPath,'Pe'));
            obj.BoundaryDropDown.Value=get_param(obj.BlockPath,'Boundary');
            obj.DataTable.Data=num2cell([str2num(get_param(obj.BlockPath,'DataTime'))' str2num(get_param(obj.BlockPath,'DataE'))']); %#ok<ST2NM>
            obj.SessionField.Value=get_param(obj.BlockPath,'SessionFile');obj.refreshControls();
        end
        function refreshControls(obj)
            model=strcmp(obj.OriginDropDown.Value,'Model');data=strcmp(obj.OriginDropDown.Value,'Data');session=strcmp(obj.OriginDropDown.Value,'Session');
            obj.ModelDropDown.Enable=onoff(model);obj.BasisDropDown.Enable=onoff(model);
            obj.TauField.Enable=onoff(model&&strcmp(obj.BasisDropDown.Value,'Tau'));
            obj.VolumeField.Enable=onoff(model&&strcmp(obj.BasisDropDown.Value,'Volume'));
            obj.NField.Enable=onoff(model&&strcmp(obj.ModelDropDown.Value,'Tanks'));
            dispersion=model&&strcmp(obj.ModelDropDown.Value,'Dispersion');
            obj.PeField.Enable=onoff(dispersion);obj.BoundaryDropDown.Enable=onoff(dispersion);
            obj.DataTable.Enable=onoff(data);obj.AddRowButton.Enable=onoff(data);
            obj.RemoveRowButton.Enable=onoff(data);obj.ImportButton.Enable=onoff(data);
            obj.SessionField.Enable=onoff(session);obj.BrowseButton.Enable=onoff(session);
        end
        function build(obj,visible)
            obj.Figure=uifigure('Name','Non-ideal Vessel','Tag','NirpTracerVesselDialog', ...
                'Visible',visible,'Position',[170 80 780 620]);
            grid=uigridlayout(obj.Figure,[12 3],'RowHeight',{35,35,35,35,35,35,35,35,'1x',35,25,38}, ...
                'ColumnWidth',{170,'1x',120});
            title=uilabel(grid,'Text','$C_{out}(t)=C_{in}(t)*E_v(t)$','Interpreter','latex','FontWeight','bold');place(title,1,[1 3]);
            place(uilabel(grid,'Text','RTD origin'),2,1);obj.OriginDropDown=uidropdown(grid,'Items',{'Model','Data','Session'},'ValueChangedFcn',@(~,~)obj.refreshControls());place(obj.OriginDropDown,2,2);
            place(uilabel(grid,'Text','Model'),3,1);obj.ModelDropDown=uidropdown(grid,'Items',{'CSTR','PFR','Tanks','Dispersion'},'ValueChangedFcn',@(~,~)obj.refreshControls());place(obj.ModelDropDown,3,2);
            obj.BasisDropDown=uidropdown(grid,'Items',{'Tau','Volume'},'ValueChangedFcn',@(~,~)obj.refreshControls());place(obj.BasisDropDown,3,3);
            place(uilabel(grid,'Text','Residence time, τ (s)'),4,1);obj.TauField=uieditfield(grid,'numeric');place(obj.TauField,4,2);
            place(uilabel(grid,'Text','Volume, V (m³)'),5,1);obj.VolumeField=uieditfield(grid,'numeric');place(obj.VolumeField,5,2);
            place(uilabel(grid,'Text','Tanks, N'),6,1);obj.NField=uieditfield(grid,'numeric');place(obj.NField,6,2);
            place(uilabel(grid,'Text','Peclet number, Pe'),7,1);obj.PeField=uieditfield(grid,'numeric');place(obj.PeField,7,2);
            obj.BoundaryDropDown=uidropdown(grid,'Items',{'open','closed'});place(obj.BoundaryDropDown,7,3);
            place(uilabel(grid,'Text','Session (.mat)'),8,1);obj.SessionField=uieditfield(grid,'text');place(obj.SessionField,8,2);
            obj.BrowseButton=uibutton(grid,'Text','Browse...','ButtonPushedFcn',@(~,~)obj.browseSession());place(obj.BrowseButton,8,3);
            obj.DataTable=uitable(grid,'ColumnName',{'t (s)','E (1/s)'},'ColumnEditable',true);place(obj.DataTable,9,[1 3]);
            dataButtons=uigridlayout(grid,[1 4],'ColumnWidth',{75,75,75,'1x'},'Padding',[0 0 0 0]);place(dataButtons,10,[1 3]);
            obj.AddRowButton=uibutton(dataButtons,'Text','Add row','ButtonPushedFcn',@(~,~)obj.addRow());
            obj.RemoveRowButton=uibutton(dataButtons,'Text','Remove','ButtonPushedFcn',@(~,~)obj.removeRow());
            obj.ImportButton=uibutton(dataButtons,'Text','Import...','ButtonPushedFcn',@(~,~)obj.importInteractive());
            obj.StatusLabel=uilabel(grid,'Text','Ready.','WordWrap','on');place(obj.StatusLabel,11,[1 3]);
            buttonRow(obj,grid,'vessel',12);
        end
    end
end
function value=onoff(condition),if condition,value='on';else,value='off';end,end
function place(control,row,column),control.Layout.Row=row;control.Layout.Column=column;end
function assertSystem(block,expected),if string(get_param(block,'System'))~=expected,error('nirp:tracerflowsheet:InvalidBlock','Dialog received the wrong block type.'),end,end
function buttonRow(obj,grid,anchor,row),buttons=uigridlayout(grid,[1 5],'ColumnWidth',{'1x',65,65,65,65},'Padding',[0 0 0 0]);place(buttons,row,[1 3]);uilabel(buttons,'Text','');uibutton(buttons,'Text','Help','ButtonPushedFcn',@(~,~)openNirpGuide(nirp.tracerflowsheet.helpTarget(anchor)));uibutton(buttons,'Text','OK','ButtonPushedFcn',@(~,~)obj.accept());uibutton(buttons,'Text','Cancel','ButtonPushedFcn',@(~,~)obj.cancel());uibutton(buttons,'Text','Apply','ButtonPushedFcn',@(~,~)obj.apply());end
