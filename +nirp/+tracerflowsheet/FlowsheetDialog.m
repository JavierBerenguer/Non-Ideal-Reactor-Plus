classdef FlowsheetDialog < handle
    % FlowsheetDialog edits the common grid and reaction configuration.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 22, 2026. Last update: October 25, 2026
    % =========================================================================
    properties (SetAccess=private)
        BlockPath;Figure;DtField;TFinalField;UnitDropDown;StatusLabel;
        OriginDropDown;ReferenceField;BrowseButton;NewButton;
        MicromixingDropDown;KeyDropDown;TemperatureField;
        TemperatureUnitDropDown;ValidityLabel;
    end
    methods
        function obj=FlowsheetDialog(block,varargin)
            p=inputParser;addParameter(p,'Visible','on');parse(p,varargin{:});
            obj.BlockPath=getfullname(block);assertSystem(obj.BlockPath,'nirp.tracerblocks.Flowsheet');
            obj.build(char(p.Results.Visible));obj.load();
        end
        function delete(obj),if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure),end,end
        function setValues(obj,dt,tFinal,unit),obj.DtField.Value=dt;obj.TFinalField.Value=tFinal;obj.UnitDropDown.Value=char(unit);end
        function setReaction(obj,origin,reference,mode,keyIndex,temperature,unit)
            obj.OriginDropDown.Value=char(origin);obj.ReferenceField.Value=char(reference);
            obj.MicromixingDropDown.Value=char(mode);obj.TemperatureField.Value=temperature;
            obj.TemperatureUnitDropDown.Value=char(unit);obj.refreshReaction();
            if isnumeric(keyIndex),obj.KeyDropDown.Value=keyIndex;end
        end
        function value=getValues(obj)
            value=struct('dt',obj.DtField.Value,'tFinal',obj.TFinalField.Value, ...
                'unit',string(obj.UnitDropDown.Value),'origin',string(obj.OriginDropDown.Value), ...
                'reference',string(obj.ReferenceField.Value),'micromixing',string(obj.MicromixingDropDown.Value), ...
                'keyIndex',obj.KeyDropDown.Value,'temperature',obj.TemperatureField.Value, ...
                'temperatureUnit',string(obj.TemperatureUnitDropDown.Value));
        end
        function ok=apply(obj)
            ok=false;
            try
                nirp.tracerflowsheet.validateSeparation(bdroot(obj.BlockPath));
                factor=nirp.tracerflowsheet.timeFactor(obj.UnitDropDown.Value);
                dt=obj.DtField.Value*factor;final=obj.TFinalField.Value*factor;
                mode=obj.MicromixingDropDown.Value;nComp=1;key=1;temperature=298.15;
                if ~strcmp(mode,'None')
                    RS=nirp.tracerflowsheet.loadReactionSystem(obj.OriginDropDown.Value,obj.ReferenceField.Value,obj.BlockPath);
                    nComp=RS.nComponents;key=obj.KeyDropDown.Value;
                    temperature=UnitConverterHelper.convertToSI('Temperature',obj.TemperatureField.Value,obj.TemperatureUnitDropDown.Value);
                    validity=nirp.tracer.boundValidity(RS,key);obj.showValidity(validity);
                end
                set_param(obj.BlockPath,'ReactionOrigin',obj.OriginDropDown.Value, ...
                    'ReactionReference',obj.ReferenceField.Value,'Micromixing',mode, ...
                    'KeyComponent',num2str(key),'Temperature',num2str(temperature,17), ...
                    'TemperatureUnit',obj.TemperatureUnitDropDown.Value,'TimeUnit',obj.UnitDropDown.Value);
                nirp.tracerflowsheet.applyGrid(obj.BlockPath,dt,final,nComp);
                obj.StatusLabel.Text='Fully specified';obj.StatusLabel.BackgroundColor=[.82 .94 .82];ok=true;
            catch e
                obj.StatusLabel.Text=e.message;obj.StatusLabel.BackgroundColor=[1 .75 .75];
            end
        end
        function accept(obj),if obj.apply(),delete(obj),end,end
        function cancel(obj),delete(obj),end
        function browseSession(obj)
            [file,folder]=uigetfile({'*.mat','MATLAB data (*.mat)'},'Select reaction system');
            if isequal(file,0),return,end
            obj.ReferenceField.Value=fullfile(folder,file);obj.OriginDropDown.Value='Session';obj.refreshReaction();
        end
        function newReactionSystem(obj)
            root=bdroot(obj.BlockPath);modelFile=get_param(root,'FileName');
            if isempty(modelFile),error('nirp:tracerflowsheet:UnsavedModel','Save the model before creating a reaction system.'),end
            target=fullfile(fileparts(modelFile),[root '_reaction.mat']);
            editor=defineReactionSysApp();editor.CreatedFcn=@created;
            function created(RS,~)
                reactionSystem=RS;save(target,'reactionSystem','-mat'); %#ok<NASGU>
                if isvalid(obj),obj.OriginDropDown.Value='File';obj.ReferenceField.Value=target;obj.refreshReaction();end
            end
        end
    end
    methods (Static)
        function dialog=open(block)
            if nirp.tracerflowsheet.openLibraryBlockGuide(block),dialog=[];return,end
            dialog=nirp.tracerflowsheet.FlowsheetDialog(block);
        end
    end
    methods (Access=private)
        function load(obj)
            unit=get_param(obj.BlockPath,'TimeUnit');factor=nirp.tracerflowsheet.timeFactor(unit);
            obj.UnitDropDown.Value=unit;obj.DtField.Value=str2double(get_param(obj.BlockPath,'Dt'))/factor;
            obj.TFinalField.Value=str2double(get_param(obj.BlockPath,'TFinal'))/factor;
            obj.OriginDropDown.Value=get_param(obj.BlockPath,'ReactionOrigin');
            obj.ReferenceField.Value=get_param(obj.BlockPath,'ReactionReference');
            obj.MicromixingDropDown.Value=get_param(obj.BlockPath,'Micromixing');
            obj.TemperatureUnitDropDown.Value=get_param(obj.BlockPath,'TemperatureUnit');
            obj.TemperatureField.Value=UnitConverterHelper.convertFromSI('Temperature',str2double(get_param(obj.BlockPath,'Temperature')),obj.TemperatureUnitDropDown.Value);
            obj.refreshReaction();key=str2double(get_param(obj.BlockPath,'KeyComponent'));
            if any(obj.KeyDropDown.ItemsData==key),obj.KeyDropDown.Value=key;end
        end
        function refreshReaction(obj)
            enabled=~strcmp(obj.MicromixingDropDown.Value,'None');state=onoff(enabled);
            obj.OriginDropDown.Enable=state;obj.ReferenceField.Enable=state;obj.BrowseButton.Enable=state;obj.NewButton.Enable=state;
            obj.KeyDropDown.Enable=state;obj.TemperatureField.Enable=state;obj.TemperatureUnitDropDown.Enable=state;
            if ~enabled,obj.KeyDropDown.Items={'Component 1'};obj.KeyDropDown.ItemsData=1;obj.ValidityLabel.Text='Inert tracer mode: reaction calculations are disabled.';return,end
            try
                RS=nirp.tracerflowsheet.loadReactionSystem(obj.OriginDropDown.Value,obj.ReferenceField.Value,obj.BlockPath);
                names=cellstr(string(RS.componentNames));if numel(names)~=RS.nComponents||any(strlength(string(names))==0),names=arrayfun(@(k)sprintf('Component %d',k),1:RS.nComponents,'UniformOutput',false);end
                previous=obj.KeyDropDown.Value;obj.KeyDropDown.Items=names;obj.KeyDropDown.ItemsData=1:RS.nComponents;
                if isnumeric(previous)&&ismember(previous,1:RS.nComponents),obj.KeyDropDown.Value=previous;else,obj.KeyDropDown.Value=1;end
                obj.showValidity(nirp.tracer.boundValidity(RS,obj.KeyDropDown.Value));
            catch e
                obj.KeyDropDown.Items={'Unavailable'};obj.KeyDropDown.ItemsData=1;obj.ValidityLabel.Text=e.message;
            end
        end
        function showValidity(obj,value)
            if value.guaranteed,prefix='Guaranteed bounds';else,prefix='Bounds not guaranteed';end
            obj.ValidityLabel.Text=sprintf('%s: %s',prefix,value.reason);
        end
        function build(obj,visible)
            obj.Figure=uifigure('Name','Tracer Flowsheet','Tag','NirpTracerFlowsheetDialog','Visible',visible,'Position',[160 70 700 650]);
            g=uigridlayout(obj.Figure,[12 4],'RowHeight',{35,32,32,18,32,32,32,32,32,55,25,38},'ColumnWidth',{175,'1x',100,95});
            title=uilabel(g,'Text','Common grid and stationary reaction system','FontWeight','bold','FontSize',15);title.Layout.Column=[1 4];
            uilabel(g,'Text','Time step, Δt');obj.DtField=uieditfield(g,'numeric');obj.UnitDropDown=uidropdown(g,'Items',{'s','min','h'});uilabel(g,'Text','');
            uilabel(g,'Text','Final time, t_final');obj.TFinalField=uieditfield(g,'numeric');uilabel(g,'Text','');uilabel(g,'Text','');
            separator=uilabel(g,'Text','Reaction and micromixing','FontWeight','bold');separator.Layout.Column=[1 4];
            uilabel(g,'Text','Micromixing');obj.MicromixingDropDown=uidropdown(g,'Items',{'None','Segregation','Max mixedness','Both'},'ValueChangedFcn',@(~,~)obj.refreshReaction());obj.MicromixingDropDown.Layout.Column=[2 4];
            uilabel(g,'Text','Reaction-system origin');obj.OriginDropDown=uidropdown(g,'Items',{'Session','Workspace','File'},'ValueChangedFcn',@(~,~)obj.refreshReaction());obj.OriginDropDown.Layout.Column=[2 4];
            uilabel(g,'Text','Reference');obj.ReferenceField=uieditfield(g,'text','ValueChangedFcn',@(~,~)obj.refreshReaction());obj.BrowseButton=uibutton(g,'Text','Browse...','ButtonPushedFcn',@(~,~)obj.browseSession());obj.NewButton=uibutton(g,'Text','New...','ButtonPushedFcn',@(~,~)obj.newReactionSystem());
            uilabel(g,'Text','Key component');obj.KeyDropDown=uidropdown(g,'Items',{'Component 1'},'ItemsData',1,'ValueChangedFcn',@(~,~)obj.refreshReaction());obj.KeyDropDown.Layout.Column=[2 4];
            uilabel(g,'Text','Operating temperature');obj.TemperatureField=uieditfield(g,'numeric');obj.TemperatureUnitDropDown=uidropdown(g,'Items',UnitConverterHelper.getUnits('Temperature'));uilabel(g,'Text','');
            obj.ValidityLabel=uilabel(g,'Text','','WordWrap','on');obj.ValidityLabel.Layout.Row=10;obj.ValidityLabel.Layout.Column=[1 4];
            obj.StatusLabel=uilabel(g,'Text','Ready.','WordWrap','on');obj.StatusLabel.Layout.Row=11;obj.StatusLabel.Layout.Column=[1 4];buttons(obj,g);
        end
    end
end
function value=onoff(condition),if condition,value='on';else,value='off';end,end
function assertSystem(block,expected),if string(get_param(block,'System'))~=expected,error('nirp:tracerflowsheet:InvalidBlock','Dialog received the wrong block type.'),end,end
function buttons(obj,g),b=uigridlayout(g,[1 5],'ColumnWidth',{'1x',65,65,65,65});b.Layout.Row=12;b.Layout.Column=[1 4];uilabel(b,'Text','');uibutton(b,'Text','Help','ButtonPushedFcn',@(~,~)openNirpGuide(nirp.tracerflowsheet.helpTarget('flowsheet')));uibutton(b,'Text','OK','ButtonPushedFcn',@(~,~)obj.accept());uibutton(b,'Text','Cancel','ButtonPushedFcn',@(~,~)obj.cancel());uibutton(b,'Text','Apply','ButtonPushedFcn',@(~,~)obj.apply());end
