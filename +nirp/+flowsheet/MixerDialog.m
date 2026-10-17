classdef MixerDialog < handle
%MIXERDIALOG Edit Mixer ports and display its known outlet result.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 14, 2026
% =========================================================================
    properties (SetAccess=private)
        BlockPath;Figure;NameField;ConnectionTable;ResultTable;StatusLabel;DataModel
    end
    methods
        function obj=MixerDialog(blockPath,varargin)
            p=inputParser;addParameter(p,'Visible','on');parse(p,varargin{:});obj.BlockPath=getfullname(blockPath);
            if string(get_param(obj.BlockPath,'System'))~="nirp.blocks.Mixer",error('nirp:flowsheet:invalidBlock','MixerDialog requires a Mixer block.');end
            obj.build(char(string(p.Results.Visible)));nirp.flowsheet.internal.formatNumericControls(obj.Figure);obj.refreshConnections();obj.refreshResult();
        end
        function delete(obj),if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure);end,end
        function setNumInputs(obj,count),if count<2||count>20||count~=fix(count),error('nirp:flowsheet:invalidPorts','A Mixer requires 2 to 20 inputs.');end;obj.DataModel.NumInputs.value=count;obj.rebuildRows(count);end
        function addInput(obj),obj.setNumInputs(obj.DataModel.NumInputs.value+1);end
        function removeInput(obj),obj.setNumInputs(obj.DataModel.NumInputs.value-1);end
        function values=getValues(obj),values=obj.DataModel;end
        function applied=apply(obj)
            applied=false;try,set_param(obj.BlockPath,'NumInputs',num2str(obj.DataModel.NumInputs.value));set_param(bdroot(obj.BlockPath),'SimulationCommand','update');obj.refreshConnections();nirp.flowsheet.afterApply(bdroot(obj.BlockPath),obj.StatusLabel);obj.refreshResult();applied=true;catch exception,obj.StatusLabel.Text=exception.message;end
        end
        function accept(obj),if obj.apply(),delete(obj);else,nirp.flowsheet.internal.showDialogError(obj.Figure,obj.StatusLabel.Text,'Mixer');end,end
        function cancel(obj),delete(obj);end
    end
    methods (Static),function dialog=open(blockPath),dialog=nirp.flowsheet.MixerDialog(blockPath);end,end
    methods (Access=private)
        function build(obj,visible)
            obj.Figure=uifigure('Name','Mixer','Tag','NirpMixerDialog','Visible',visible,'Position',[120 90 760 560],'WindowStyle','alwaysontop');main=uigridlayout(obj.Figure,[4 1],'RowHeight',{38,'1x',25,38},'Padding',[12 10 12 10]);
            h=uigridlayout(main,[1 3],'ColumnWidth',{60,'1x',160});uilabel(h,'Text','Name','HorizontalAlignment','right');obj.NameField=uieditfield(h,'text','Editable','off','Value',get_param(obj.BlockPath,'Name'));uibutton(h,'Text','Unit conversion helper','ButtonPushedFcn',@(~,~)UnitConverterHelper.launch());
            tabs=uitabgroup(main);ports=uitab(tabs,'Title','Connections');results=uitab(tabs,'Title','Outlet result');
            g=uigridlayout(ports,[2 3],'RowHeight',{'1x',32},'ColumnWidth',{90,90,'1x'});obj.ConnectionTable=uitable(g,'ColumnName',{'Direction','Port','Stream'},'ColumnEditable',[false false false]);obj.ConnectionTable.Layout.Row=1;obj.ConnectionTable.Layout.Column=[1 3];add=uibutton(g,'Text','Add inlet','ButtonPushedFcn',@(~,~)obj.addInput());add.Layout.Row=2;add.Layout.Column=1;remove=uibutton(g,'Text','Remove','ButtonPushedFcn',@(~,~)obj.removeInput());remove.Layout.Row=2;remove.Layout.Column=2;
            rg=uigridlayout(results,[2 1],'RowHeight',{28,'1x'});uilabel(rg,'Text','Known inlets determine the outlet; Mixer has no specifications.','FontAngle','italic');obj.ResultTable=uitable(rg,'ColumnName',{'Component','F out (mol/s)','Mole fraction','P out (Pa)'},'ColumnEditable',[false false false false],'RowName',{});
            obj.StatusLabel=uilabel(main,'Text','Fully specified','FontAngle','italic');b=uigridlayout(main,[1 5],'ColumnWidth',{'1x',70,90,90,90});uilabel(b,'Text','');uibutton(b,'Text','Help','ButtonPushedFcn',@(~,~)openNirpGuide('guides/flowsheet-units.html#mixer'));uibutton(b,'Text','OK','ButtonPushedFcn',@(~,~)obj.accept());uibutton(b,'Text','Cancel','ButtonPushedFcn',@(~,~)obj.cancel());uibutton(b,'Text','Apply','ButtonPushedFcn',@(~,~)obj.apply());
            obj.DataModel=struct('NumInputs',struct('value',str2double(get_param(obj.BlockPath,'NumInputs')),'unit',"1",'origin',"specified"));
        end
        function rebuildRows(obj,count)
            old=obj.ConnectionTable.Data;data=cell(count+1,3);for i=1:count,data(i,:)={'Input',i,'<missing>'};end;data(end,:)={'Output',1,'<missing>'};for i=1:min(size(old,1),size(data,1)),if strcmp(old{i,1},data{i,1}),data{i,3}=old{i,3};end,end;obj.ConnectionTable.Data=data;
        end
        function refreshConnections(obj)
            count=str2double(get_param(obj.BlockPath,'NumInputs'));obj.DataModel=struct('NumInputs',struct('value',count,'unit',"1",'origin',"specified"));obj.rebuildRows(count);graph=nirp.flowsheet.topology(bdroot(obj.BlockPath));key=matlab.lang.makeValidName(get_param(obj.BlockPath,'Name'));data=obj.ConnectionTable.Data;if isfield(graph.Units,key),x=graph.Units.(key);for i=1:min(numel(x.Inputs),count),data{i,3}=label(x.Inputs{i});end;if ~isempty(x.Outputs),data{end,3}=label(x.Outputs{1});end;end;obj.ConnectionTable.Data=data;
        end
        function refreshResult(obj)
            pkg=nirp.pkg.readDictionary(nirp.flowsheet.modelDictionary(bdroot(obj.BlockPath)));names=string({pkg.components.name});streams=obj.knownInputs();data=[cellstr(names(:)) repmat({[]},numel(names),3)];
            if isempty(streams)
                obj.ResultTable.Data=data;obj.StatusLabel.Text='Fully specified - results need a run or defined feeds';obj.StatusLabel.BackgroundColor=[0.82 0.94 0.82];obj.DataModel.Result=[];return
            end
            try
                rs=nirp.pkg.toReactionSys(pkg);[out,~]=nirp.units.mixer(struct(),streams,rs);total=sum(out.F);for i=1:numel(names),data{i,2}=out.F(i);if total>0,data{i,3}=out.F(i)/total;end;data{i,4}=out.P;end
                obj.ResultTable.Data=data;obj.StatusLabel.Text='Fully specified';obj.StatusLabel.BackgroundColor=[0.82 0.94 0.82];obj.DataModel.Result=out;
            catch exception,obj.ResultTable.Data=data;obj.StatusLabel.Text=exception.message;obj.StatusLabel.BackgroundColor=[1 0.75 0.75];obj.DataModel.Result=[];end
        end
        function streams=knownInputs(obj)
            streams={};model=bdroot(obj.BlockPath);graph=nirp.flowsheet.topology(model);key=matlab.lang.makeValidName(get_param(obj.BlockPath,'Name'));if ~isfield(graph.Units,key),return,end
            pkg=nirp.pkg.readDictionary(nirp.flowsheet.modelDictionary(model));results=[];if evalin('base','exist(''nirpResults'',''var'')'),results=evalin('base','nirpResults');end
            inputs=graph.Units.(key).Inputs;for i=1:numel(inputs),if isempty(inputs{i}),streams={};return,end;name=string(inputs{i});name=name(1);skey=matlab.lang.makeValidName(name);stream=[];if isfield(graph.Streams,skey)&&graph.Streams.(skey).Role=="Feed",try,stream=nirp.pkg.feedStream(pkg,name);catch,end;end;if isempty(stream)&&isstruct(results)&&isfield(results,'Streams')&&isfield(results.Streams,skey),stream=results.Streams.(skey).streamSI;end;if isempty(stream),streams={};return,end;streams{end+1}=stream;end
        end
    end
end
function s=label(v),if isempty(v),s='<missing>';else,s=char(strjoin(string(v),', '));end,end
