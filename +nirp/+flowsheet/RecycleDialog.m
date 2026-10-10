classdef RecycleDialog < handle
%RECYCLEDIALOG Structured editor for Recycle (tear stream) blocks (T-142).
% =========================================================================
% Javier Berenguer Sabater
% Created: October 10, 2026. Last update: October 10, 2026
% =========================================================================
    properties (SetAccess=private)
        BlockPath; Figure; NameField; TearInLabel; TearOutLabel
        MethodDropDown; QMinField; QMaxField; AccelerationField; WegsteinHelp
        ToleranceField; MaxIterationsLabel; InitialGuessDropDown; FeedDropDown
        InitialTField; InitialTUnitDropDown; InitialPField; InitialPUnitDropDown
        StatusLabel; DataModel
    end
    methods
        function obj=RecycleDialog(blockPath,varargin)
            p=inputParser;addParameter(p,'Visible','on');parse(p,varargin{:});
            obj.BlockPath=getfullname(blockPath);
            if string(get_param(obj.BlockPath,'System'))~="nirp.blocks.Recycle"
                error('nirp:flowsheet:invalidBlock','RecycleDialog requires a Recycle block.');
            end
            obj.build(char(string(p.Results.Visible)));obj.load();
            [~,~,label]=nirp.flowsheet.blockStatus(obj.BlockPath);obj.StatusLabel.Text=char(label);
        end
        function delete(obj),if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure);end,end
        function setValues(obj,varargin)
            map=struct('method','MethodDropDown','qmin','QMinField','qmax','QMaxField', ...
                'accelerationevery','AccelerationField','tolerance','ToleranceField', ...
                'initialguess','InitialGuessDropDown','initialfeedname','FeedDropDown', ...
                'initialt','InitialTField','initialtunit','InitialTUnitDropDown', ...
                'initialp','InitialPField','initialpunit','InitialPUnitDropDown');
            for i=1:2:numel(varargin)
                key=lower(char(string(varargin{i})));
                if ~isfield(map,key),error('nirp:flowsheet:unknownParameter','Unknown Recycle parameter "%s".',key);end
                obj.(map.(key)).Value=varargin{i+1};
            end
            obj.updateVisibility();obj.captureModel();
        end
        function values=getValues(obj),obj.captureModel();values=obj.DataModel;end
        function applied=apply(obj)
            applied=false;
            try
                if ~(obj.ToleranceField.Value>0),error('nirp:flowsheet:invalidParameter','Tolerance must be positive.');end
                if obj.QMinField.Value>obj.QMaxField.Value||obj.QMaxField.Value>0,error('nirp:flowsheet:invalidParameter','Wegstein bounds need QMin <= QMax <= 0.');end
                args={'Method',obj.MethodDropDown.Value,'Tolerance',n(obj.ToleranceField.Value), ...
                    'QMin',n(obj.QMinField.Value),'QMax',n(obj.QMaxField.Value), ...
                    'AccelerationEvery',n(obj.AccelerationField.Value), ...
                    'InitialGuess',obj.InitialGuessDropDown.Value, ...
                    'InitialT',n(obj.InitialTField.Value),'InitialTUnit',obj.InitialTUnitDropDown.Value, ...
                    'InitialP',n(obj.InitialPField.Value),'InitialPUnit',obj.InitialPUnitDropDown.Value};
                if ~isempty(obj.FeedDropDown.Items),args=[args {'InitialFeedName',obj.FeedDropDown.Value}];end
                set_param(obj.BlockPath,args{:});
                obj.StatusLabel.Text='Applied.';obj.captureModel();applied=true;
            catch exception,obj.StatusLabel.Text=exception.message;end
        end
        function accept(obj),if obj.apply(),block=obj.BlockPath;delete(obj);nirp.flowsheet.autoRun(block);end,end
        function cancel(obj),delete(obj);end
    end
    methods (Static)
        function dialog=open(blockPath),dialog=nirp.flowsheet.RecycleDialog(blockPath);end
    end
    methods (Access=private)
        function build(obj,visible)
            obj.Figure=uifigure('Name','Recycle','Tag','NirpRecycleDialog','Visible',visible, ...
                'Position',[140 110 760 470],'WindowStyle','alwaysontop');
            main=uigridlayout(obj.Figure,[3 1],'RowHeight',{'1x',26,38},'Padding',[12 10 12 10]);
            grid=uigridlayout(main,[11 4],'ColumnWidth',{190,140,110,'1x'},'RowHeight',repmat({26},1,11));
            label(grid,1,'Name');obj.NameField=uieditfield(grid,'text','Editable','off');place(obj.NameField,1,[2 3]);
            heading(grid,2,'Tear stream');
            label(grid,3,'Calculated stream (input)');obj.TearInLabel=uilabel(grid,'Text','<missing>');place(obj.TearInLabel,3,[2 4]);
            label(grid,4,'Estimate sent to (output)');obj.TearOutLabel=uilabel(grid,'Text','<missing>');place(obj.TearOutLabel,4,[2 4]);
            heading(grid,5,'Method and convergence');
            label(grid,6,'Method');obj.MethodDropDown=uidropdown(grid,'Items',{'Direct','Wegstein'},'ValueChangedFcn',@(~,~) obj.updateVisibility());place(obj.MethodDropDown,6,2);
            label(grid,7,'Tolerance (relative)');obj.ToleranceField=uieditfield(grid,'numeric');place(obj.ToleranceField,7,2);
            obj.MaxIterationsLabel=uilabel(grid,'Text','Maximum iterations: -');place(obj.MaxIterationsLabel,7,3);
            settings=uibutton(grid,'Text','Flowsheet settings...','ButtonPushedFcn',@(~,~) nirp.flowsheet.ReactiveSystemDialog.openForModel(bdroot(obj.BlockPath)));place(settings,7,4);
            label(grid,8,'QMin / QMax');obj.QMinField=uieditfield(grid,'numeric');place(obj.QMinField,8,2);obj.QMaxField=uieditfield(grid,'numeric');place(obj.QMaxField,8,3);
            obj.AccelerationField=uieditfield(grid,'numeric','Limits',[1 Inf],'RoundFractionalValues','on');label(grid,9,'Accelerate every N iterations');place(obj.AccelerationField,9,2);
            obj.WegsteinHelp=uilabel(grid,'Text','Wegstein accelerates convergence; q is bounded in [QMin, QMax].','FontAngle','italic');place(obj.WegsteinHelp,9,[3 4]);
            label(grid,10,'Initial estimate');obj.InitialGuessDropDown=uidropdown(grid,'Items',{'Empty stream','Feed'},'ValueChangedFcn',@(~,~) obj.updateVisibility());place(obj.InitialGuessDropDown,10,2);
            obj.FeedDropDown=uidropdown(grid,'Items',{});place(obj.FeedDropDown,10,3);
            label(grid,11,'Initial T / P');
            tGrid=uigridlayout(grid,[1 2],'ColumnWidth',{'1x',50},'Padding',[0 0 0 0]);place(tGrid,11,2);
            obj.InitialTField=uieditfield(tGrid,'numeric');obj.InitialTUnitDropDown=uidropdown(tGrid,'Items',{'K',[char(176) 'C']});
            pGrid=uigridlayout(grid,[1 2],'ColumnWidth',{'1x',60},'Padding',[0 0 0 0]);place(pGrid,11,[3 4]);
            obj.InitialPField=uieditfield(pGrid,'numeric');obj.InitialPUnitDropDown=uidropdown(pGrid,'Items',UnitConverterHelper.getUnits('Pressure'));
            obj.StatusLabel=uilabel(main,'Text','Ready.','FontAngle','italic');
            b=uigridlayout(main,[1 4],'ColumnWidth',{'1x',90,90,90});uilabel(b,'Text','');
            uibutton(b,'Text','OK','ButtonPushedFcn',@(~,~) obj.accept());uibutton(b,'Text','Cancel','ButtonPushedFcn',@(~,~) obj.cancel());uibutton(b,'Text','Apply','ButtonPushedFcn',@(~,~) obj.apply());
        end
        function load(obj)
            block=obj.BlockPath;obj.NameField.Value=get_param(block,'Name');
            obj.MethodDropDown.Value=get_param(block,'Method');obj.InitialGuessDropDown.Value=get_param(block,'InitialGuess');
            numeric={'Tolerance',obj.ToleranceField;'QMin',obj.QMinField;'QMax',obj.QMaxField;'AccelerationEvery',obj.AccelerationField;'InitialT',obj.InitialTField;'InitialP',obj.InitialPField};
            for i=1:size(numeric,1),value=str2double(get_param(block,numeric{i,1}));if isfinite(value),numeric{i,2}.Value=value;end,end
            obj.InitialTUnitDropDown.Value=get_param(block,'InitialTUnit');obj.InitialPUnitDropDown.Value=get_param(block,'InitialPUnit');
            try
                pkg=nirp.pkg.readDictionary(nirp.flowsheet.modelDictionary(bdroot(block)));feeds=cellstr(string({pkg.feeds.name}));
            catch
                feeds={};
            end
            obj.FeedDropDown.Items=feeds;feed=char(string(get_param(block,'InitialFeedName')));
            if any(strcmp(feeds,feed)),obj.FeedDropDown.Value=feed;end
            ports=get_param(block,'PortConnectivity');inNames=strings(0,1);outNames=strings(0,1);
            for i=1:numel(ports)
                if ~isempty(ports(i).SrcBlock)&&all(ports(i).SrcBlock~=-1),inNames=[inNames;string(get_param(ports(i).SrcBlock,'Name'))];end %#ok<AGROW>
                for h=ports(i).DstBlock(:)',outNames=[outNames;string(get_param(h,'Name'))];end %#ok<AGROW>
            end
            if ~isempty(inNames),obj.TearInLabel.Text=char(strjoin(inNames,', '));end
            if ~isempty(outNames),obj.TearOutLabel.Text=char(strjoin(outNames,', '));end
            flowsheets=find_system(bdroot(block),'SearchDepth',1,'BlockType','SubSystem','Mask','on');
            for i=1:numel(flowsheets)
                if any(strcmp(get_param(flowsheets{i},'MaskNames'),'MaxIterations'))
                    obj.MaxIterationsLabel.Text=['Maximum iterations: ' get_param(flowsheets{i},'MaxIterations')];break
                end
            end
            obj.updateVisibility();obj.captureModel();
        end
        function updateVisibility(obj)
            wegstein=onoff(strcmp(obj.MethodDropDown.Value,'Wegstein'));
            set([obj.QMinField obj.QMaxField obj.AccelerationField obj.WegsteinHelp],'Enable',wegstein);
            obj.FeedDropDown.Visible=onoff(strcmp(obj.InitialGuessDropDown.Value,'Feed'));
        end
        function captureModel(obj)
            q=@(v,u) struct('value',v,'unit',string(u),'origin',"specified");
            obj.DataModel=struct('Method',string(obj.MethodDropDown.Value),'Tolerance',q(obj.ToleranceField.Value,'1'), ...
                'QMin',q(obj.QMinField.Value,'1'),'QMax',q(obj.QMaxField.Value,'1'), ...
                'AccelerationEvery',q(obj.AccelerationField.Value,'1'),'InitialGuess',string(obj.InitialGuessDropDown.Value), ...
                'InitialT',q(obj.InitialTField.Value,obj.InitialTUnitDropDown.Value),'InitialP',q(obj.InitialPField.Value,obj.InitialPUnitDropDown.Value), ...
                'TearStream',string(obj.TearInLabel.Text)+" -> "+string(obj.TearOutLabel.Text));
        end
    end
end
function label(grid,row,text),l=uilabel(grid,'Text',text,'HorizontalAlignment','right');place(l,row,1);end
function heading(grid,row,text),l=uilabel(grid,'Text',text,'FontWeight','bold');place(l,row,[1 4]);end
function place(item,row,column),item.Layout.Row=row;item.Layout.Column=column;end
function value=onoff(flag),if flag,value='on';else,value='off';end,end
function value=n(x),value=num2str(x,17);end
