classdef AdjustDialog < handle
%ADJUSTDIALOG Structured editor for Adjust Simulink blocks.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 9, 2026. Last update: October 9, 2026
% =========================================================================
    properties (SetAccess=private)
        BlockPath;Figure;NameField;TargetLabel;TargetDropDown;ConnectButton
        TargetVariableDropDown;KeyComponentField;ReferenceFeedField
        TargetValueField;TargetUnitDropDown;InitialValueField;MinValueField
        MaxValueField;ParameterUnitDropDown;ToleranceField;DampingField
        StrategyDropDown;StatusLabel;DataModel
    end
    properties (Access=private)
        CandidateTargets
    end
    methods
        function obj=AdjustDialog(blockPath,varargin)
            p=inputParser;addParameter(p,'Visible','on');parse(p,varargin{:});
            obj.BlockPath=getfullname(blockPath);
            if string(get_param(obj.BlockPath,'System'))~="nirp.blocks.Adjust"
                error('nirp:flowsheet:invalidBlock', ...
                    'AdjustDialog requires an Adjust block.');
            end
            obj.build(char(string(p.Results.Visible)));obj.load();obj.refreshTargets();
            [~,~,label]=nirp.flowsheet.blockStatus(obj.BlockPath);
            obj.StatusLabel.Text=char(label);
        end
        function delete(obj)
            if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure);end
        end
        function values=getValues(obj),obj.captureModel();values=obj.DataModel;end
        function setValues(obj,varargin)
            for i=1:2:numel(varargin)
                name=char(string(varargin{i}));value=varargin{i+1};
                switch lower(name)
                    case 'targetvariable',obj.TargetVariableDropDown.Value=char(string(value));
                    case 'keycomponent',obj.KeyComponentField.Value=char(string(value));
                    case 'referencefeed',obj.ReferenceFeedField.Value=char(string(value));
                    case 'targetvalue',obj.TargetValueField.Value=value;
                    case 'targetunit',obj.TargetUnitDropDown.Value=char(string(value));
                    case 'initialvalue',obj.InitialValueField.Value=value;
                    case 'minvalue',obj.MinValueField.Value=value;
                    case 'maxvalue',obj.MaxValueField.Value=value;
                    case 'parameterunit',obj.ParameterUnitDropDown.Value=char(string(value));
                    case 'tolerance',obj.ToleranceField.Value=value;
                    case 'damping',obj.DampingField.Value=value;
                    case 'strategy',obj.StrategyDropDown.Value=char(string(value));
                    otherwise,error('nirp:flowsheet:unknownParameter','Unknown Adjust parameter.');
                end
            end
            obj.captureModel();
        end
        function applied=apply(obj)
            applied=false;
            try
                name=strtrim(obj.NameField.Value);
                if isempty(name),error('nirp:flowsheet:invalidName','Name cannot be empty.');end
                set_param(obj.BlockPath, ...
                    'TargetVariable',obj.TargetVariableDropDown.Value, ...
                    'KeyComponent',obj.KeyComponentField.Value, ...
                    'ReferenceFeed',obj.ReferenceFeedField.Value, ...
                    'TargetValue',numberText(obj.TargetValueField.Value), ...
                    'TargetUnit',obj.TargetUnitDropDown.Value, ...
                    'InitialValue',numberText(obj.InitialValueField.Value), ...
                    'MinValue',numberText(obj.MinValueField.Value), ...
                    'MaxValue',numberText(obj.MaxValueField.Value), ...
                    'ParameterUnit',obj.ParameterUnitDropDown.Value, ...
                    'Tolerance',numberText(obj.ToleranceField.Value), ...
                    'Damping',numberText(obj.DampingField.Value), ...
                    'Strategy',obj.StrategyDropDown.Value);
                if ~strcmp(name,get_param(obj.BlockPath,'Name'))
                    model=bdroot(obj.BlockPath);set_param(obj.BlockPath,'Name',name);
                    obj.BlockPath=[model '/' name];
                end
                obj.StatusLabel.Text='Applied.';obj.captureModel();
                obj.refreshTargets();applied=true;
            catch exception
                obj.StatusLabel.Text=exception.message;
            end
        end
        function accept(obj),if obj.apply(),delete(obj);end,end
        function cancel(obj),delete(obj);end
        function connect(obj)
            if isempty(obj.CandidateTargets),return,end
            index=find(string({obj.CandidateTargets.Label})==string(obj.TargetDropDown.Value),1);
            if isempty(index),return,end
            candidate=obj.CandidateTargets(index);
            try
                sourcePorts=get_param(obj.BlockPath,'PortHandles');
                oldLine=get_param(sourcePorts.Outport(1),'Line');
                if oldLine~=-1,delete_line(oldLine);end
                destinationPorts=get_param(char(candidate.Block),'PortHandles');
                add_line(bdroot(obj.BlockPath),sourcePorts.Outport(1), ...
                    destinationPorts.Inport(candidate.Port),'autorouting','smart');
                obj.limitParameterUnits(candidate.Category);
                obj.StatusLabel.Text=['Connected to ' char(candidate.Label) '.'];
                obj.refreshTargets();obj.captureModel();
            catch exception
                obj.StatusLabel.Text=exception.message;
            end
        end
    end
    methods (Static)
        function dialog=open(blockPath),dialog=nirp.flowsheet.AdjustDialog(blockPath);end
    end
    methods (Access=private)
        function build(obj,visible)
            obj.Figure=uifigure('Name','Adjust','Tag','NirpAdjustDialog', ...
                'Visible',visible,'Position',[120 40 760 720], ...
                'WindowStyle','alwaysontop');
            main=uigridlayout(obj.Figure,[6 1], ...
                'RowHeight',{40,125,245,190,25,38},'Padding',[12 10 12 10]);
            header=uigridlayout(main,[1 4],'ColumnWidth',{160,60,'1x',180});
            uibutton(header,'Text','Unit conversion helper', ...
                'ButtonPushedFcn',@(~,~) UnitConverterHelper.launch());
            uilabel(header,'Text','Name','HorizontalAlignment','right');
            obj.NameField=uieditfield(header,'text');

            adjusted=uipanel(main,'Title','Adjusted variable');
            grid=uigridlayout(adjusted,[2 3], ...
                'ColumnWidth',{150,'1x',100},'RowHeight',{30,30});
            uilabel(grid,'Text','Current destination','HorizontalAlignment','right');
            obj.TargetLabel=uilabel(grid,'Text','<not connected>','FontWeight','bold');
            obj.TargetLabel.Layout.Column=[2 3];
            uilabel(grid,'Text','Free parameter port','HorizontalAlignment','right');
            obj.TargetDropDown=uidropdown(grid);
            obj.ConnectButton=uibutton(grid,'Text','Connect', ...
                'ButtonPushedFcn',@(~,~) obj.connect());

            target=uipanel(main,'Title','Target');
            grid=uigridlayout(target,[5 3], ...
                'ColumnWidth',{190,'1x',130},'RowHeight',repmat({32},1,5));
            obj.TargetVariableDropDown=dropRow(grid,1,'Target variable', ...
                {'Conversion','Component molar flow','Temperature','Component concentration'});
            obj.KeyComponentField=textRow(grid,2,'Key component');
            obj.ReferenceFeedField=textRow(grid,3,'Reference feed');
            obj.TargetValueField=numericRow(grid,4,'Target value');
            targetUnitLabel=uilabel(grid,'Text','Target unit','HorizontalAlignment','right');
            targetUnitLabel.Layout.Row=5;targetUnitLabel.Layout.Column=1;
            obj.TargetUnitDropDown=uidropdown(grid,'Items',targetUnits());
            obj.TargetUnitDropDown.Layout.Row=5;obj.TargetUnitDropDown.Layout.Column=2;

            solver=uipanel(main,'Title','Solver');
            grid=uigridlayout(solver,[4 6], ...
                'ColumnWidth',{95,100,75,100,90,'1x'}, ...
                'RowHeight',repmat({32},1,4));
            obj.InitialValueField=numericPair(grid,1,1,'Initial value');
            obj.MinValueField=numericPair(grid,1,3,'Minimum');
            obj.MaxValueField=numericPair(grid,1,5,'Maximum');
            label=uilabel(grid,'Text','Parameter unit','HorizontalAlignment','right');
            label.Layout.Row=2;label.Layout.Column=1;
            obj.ParameterUnitDropDown=uidropdown(grid,'Items',parameterUnits());
            obj.ParameterUnitDropDown.Layout.Row=2;obj.ParameterUnitDropDown.Layout.Column=[2 3];
            obj.ToleranceField=numericPair(grid,3,1,'Tolerance');
            obj.DampingField=numericPair(grid,3,3,'Damping');
            label=uilabel(grid,'Text','Strategy','HorizontalAlignment','right');
            label.Layout.Row=4;label.Layout.Column=1;
            obj.StrategyDropDown=uidropdown(grid,'Items',{'Simultaneous','Nested'});
            obj.StrategyDropDown.Layout.Row=4;obj.StrategyDropDown.Layout.Column=[2 3];

            obj.StatusLabel=uilabel(main,'Text','Ready.','FontAngle','italic');
            buttons=uigridlayout(main,[1 4],'ColumnWidth',{'1x',90,90,90});
            uilabel(buttons,'Text','');
            uibutton(buttons,'Text','OK','ButtonPushedFcn',@(~,~) obj.accept());
            uibutton(buttons,'Text','Cancel','ButtonPushedFcn',@(~,~) obj.cancel());
            uibutton(buttons,'Text','Apply','ButtonPushedFcn',@(~,~) obj.apply());
        end
        function load(obj)
            obj.NameField.Value=get_param(obj.BlockPath,'Name');
            obj.TargetVariableDropDown.Value=get_param(obj.BlockPath,'TargetVariable');
            obj.KeyComponentField.Value=get_param(obj.BlockPath,'KeyComponent');
            obj.ReferenceFeedField.Value=get_param(obj.BlockPath,'ReferenceFeed');
            obj.TargetValueField.Value=str2double(get_param(obj.BlockPath,'TargetValue'));
            obj.TargetUnitDropDown.Value=get_param(obj.BlockPath,'TargetUnit');
            obj.InitialValueField.Value=str2double(get_param(obj.BlockPath,'InitialValue'));
            obj.MinValueField.Value=str2double(get_param(obj.BlockPath,'MinValue'));
            obj.MaxValueField.Value=str2double(get_param(obj.BlockPath,'MaxValue'));
            obj.ToleranceField.Value=str2double(get_param(obj.BlockPath,'Tolerance'));
            obj.DampingField.Value=str2double(get_param(obj.BlockPath,'Damping'));
            obj.StrategyDropDown.Value=get_param(obj.BlockPath,'Strategy');
            obj.ParameterUnitDropDown.Value=get_param(obj.BlockPath,'ParameterUnit');
            obj.captureModel();
        end
        function refreshTargets(obj)
            current=nirp.flowsheet.adjustTarget(obj.BlockPath);
            obj.TargetLabel.Text=char(current.Label);
            if current.Label~="<not connected>",obj.limitParameterUnits(current.Category);end
            obj.CandidateTargets=freeParameterPorts(bdroot(obj.BlockPath));
            if isempty(obj.CandidateTargets)
                obj.TargetDropDown.Items={'<no free parameter ports>'};
                obj.TargetDropDown.Enable='off';obj.ConnectButton.Enable='off';
            else
                obj.TargetDropDown.Items=cellstr(string({obj.CandidateTargets.Label}));
                obj.TargetDropDown.Enable='on';obj.ConnectButton.Enable='on';
            end
        end
        function limitParameterUnits(obj,category)
            items=UnitConverterHelper.getUnits(char(category));
            old=string(obj.ParameterUnitDropDown.Value);
            obj.ParameterUnitDropDown.Items=items;
            if any(string(items)==old),obj.ParameterUnitDropDown.Value=char(old);
            else,obj.ParameterUnitDropDown.Value=items{1};end
        end
        function captureModel(obj)
            obj.DataModel=struct( ...
                'TargetVariable',string(obj.TargetVariableDropDown.Value), ...
                'KeyComponent',string(obj.KeyComponentField.Value), ...
                'ReferenceFeed',string(obj.ReferenceFeedField.Value), ...
                'TargetValue',obj.TargetValueField.Value, ...
                'TargetUnit',string(obj.TargetUnitDropDown.Value), ...
                'InitialValue',obj.InitialValueField.Value, ...
                'MinValue',obj.MinValueField.Value, ...
                'MaxValue',obj.MaxValueField.Value, ...
                'ParameterUnit',string(obj.ParameterUnitDropDown.Value), ...
                'Tolerance',obj.ToleranceField.Value, ...
                'Damping',obj.DampingField.Value, ...
                'Strategy',string(obj.StrategyDropDown.Value));
        end
    end
end

function value=dropRow(grid,row,label,items)
    text=uilabel(grid,'Text',label,'HorizontalAlignment','right');
    text.Layout.Row=row;text.Layout.Column=1;
    value=uidropdown(grid,'Items',items);value.Layout.Row=row;value.Layout.Column=2;
end
function value=textRow(grid,row,label)
    text=uilabel(grid,'Text',label,'HorizontalAlignment','right');
    text.Layout.Row=row;text.Layout.Column=1;
    value=uieditfield(grid,'text');value.Layout.Row=row;value.Layout.Column=2;
end
function value=numericRow(grid,row,label)
    text=uilabel(grid,'Text',label,'HorizontalAlignment','right');
    text.Layout.Row=row;text.Layout.Column=1;
    value=uieditfield(grid,'numeric');value.Layout.Row=row;value.Layout.Column=2;
end
function value=numericPair(grid,row,column,label)
    text=uilabel(grid,'Text',label,'HorizontalAlignment','right');
    text.Layout.Row=row;text.Layout.Column=column;
    value=uieditfield(grid,'numeric');value.Layout.Row=row;value.Layout.Column=column+1;
end
function units=targetUnits()
    units=[{'as entered'},UnitConverterHelper.getUnits('MolarFlow'), ...
        UnitConverterHelper.getUnits('Temperature'), ...
        UnitConverterHelper.getUnits('Concentration')];
    units=unique(units,'stable');
end
function units=parameterUnits()
    units=[UnitConverterHelper.getUnits('Volume'), ...
        UnitConverterHelper.getUnits('Temperature'), ...
        UnitConverterHelper.getUnits('VolumetricFlow'), ...
        UnitConverterHelper.getUnits('Area')];
    units=unique(units,'stable');
end
function text=numberText(value),text=num2str(value,17);end

function targets=freeParameterPorts(model)
    targets=struct('Block',{},'Port',{},'Variable',{},'Category',{},'Label',{});
    blocks=find_system(model,'LookUnderMasks','all','SearchDepth',1, ...
        'BlockType','MATLABSystem');
    for i=1:numel(blocks)
        block=blocks{i};
        try,className=string(get_param(block,'System'));catch,continue,end
        definitions=parameterDefinitions(block,className);
        ports=get_param(block,'PortHandles');
        for j=1:numel(definitions)
            port=definitions(j).Port;
            if port>numel(ports.Inport)||get_param(ports.Inport(port),'Line')~=-1,continue,end
            name=string(get_param(block,'Name'))+" / "+definitions(j).Variable;
            targets(end+1)=struct('Block',string(block),'Port',port, ... %#ok<AGROW>
                'Variable',definitions(j).Variable,'Category',definitions(j).Category, ...
                'Label',name);
        end
    end
end

function definitions=parameterDefinitions(block,className)
    definitions=struct('Port',{},'Variable',{},'Category',{});
    switch className
        case {"nirp.blocks.CSTR","nirp.blocks.PFR"}
            if strcmp(get_param(block,'VSource'),'Input port')
                definitions(1)=definition(2,"V","Volume");
            end
        case "nirp.blocks.Jacket"
            index=0;
            if strcmp(get_param(block,'ASource'),'Input port')
                index=index+1;definitions(end+1)=definition(index,"A","Area"); %#ok<AGROW>
            end
            if strcmp(get_param(block,'UtilityTinSource'),'Input port')
                index=index+1;definitions(end+1)=definition(index,"UtilityTin","Temperature"); %#ok<AGROW>
            end
        case "nirp.blocks.Stream"
            if nirp.flowsheet.streamRole(block)~="Feed",return,end
            index=0;
            if strcmp(get_param(block,'TSource'),'Input port')
                index=index+1;definitions(end+1)=definition(index,"T","Temperature"); %#ok<AGROW>
            end
            if strcmp(get_param(block,'QSource'),'Input port')
                index=index+1;definitions(end+1)=definition(index,"Q","VolumetricFlow"); %#ok<AGROW>
            end
    end
end
function value=definition(port,variable,category)
    value=struct('Port',port,'Variable',string(variable),'Category',string(category));
end
