classdef MonitorDialog < handle
    % MonitorDialog configures warnings and presents reactive results.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 22, 2026. Last update: October 25, 2026
    % =========================================================================
    properties (SetAccess=private),BlockPath;Figure;WarningField;ResultsTable;ValidityLabel;StatusLabel;end
    methods
        function obj=MonitorDialog(block,varargin),p=inputParser;addParameter(p,'Visible','on');parse(p,varargin{:});obj.BlockPath=getfullname(block);obj.build(char(p.Results.Visible));obj.WarningField.Value=100*str2double(get_param(obj.BlockPath,'LostAreaWarning'));obj.refresh();end
        function delete(obj),if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure),end,end
        function value=getValues(obj),value=obj.WarningField.Value/100;end
        function refresh(obj)
            result=obj.latestResult();
            if ~isempty(result)&&isfield(result,'reaction')&&~isempty(result.reaction)
                obj.showReaction(result.reaction);return
            end
            try
                config=nirp.tracerflowsheet.reactionConfiguration(obj.BlockPath);
                if config.enabled
                    validity=nirp.tracer.boundValidity(config.RS,config.keyIndex);reaction=struct('componentNames',{config.componentNames},'mode',config.modeName,'keyIndex',config.keyIndex,'Cseg',nan(1,config.RS.nComponents),'Cmm',nan(1,config.RS.nComponents),'Xseg',NaN,'Xmm',NaN,'interval',[NaN NaN],'lowerModel','','upperModel','','validity',validity,'rtdTruncated',false,'warning','Simulate the model to populate results.');obj.showReaction(reaction);
                else
                    obj.ResultsTable.Data=cell(0,1);obj.ResultsTable.ColumnName={'Reactive results'};obj.ValidityLabel.Text='Micromixing is None; only tracer results are calculated.';
                end
            catch e,obj.ValidityLabel.Text=e.message;end
        end
        function ok=apply(obj),ok=false;try,nirp.tracerflowsheet.validateSeparation(bdroot(obj.BlockPath));value=obj.getValues();if value<0||value>=1,error('nirp:tracerflowsheet:InvalidThreshold','Lost-area threshold must be in [0, 100).'),end;set_param(obj.BlockPath,'LostAreaWarning',num2str(value,17));obj.StatusLabel.Text='Fully specified';ok=true;catch e,obj.StatusLabel.Text=e.message;end,end
        function accept(obj),if obj.apply(),delete(obj),end,end
        function cancel(obj),delete(obj),end
    end
    methods (Static)
        function dialog=open(block),if nirp.tracerflowsheet.openLibraryBlockGuide(block),dialog=[];return,end;dialog=nirp.tracerflowsheet.MonitorDialog(block);end
    end
    methods (Access=private)
        function result=latestResult(obj)
            result=[];if ~evalin('base','exist(''nirpTracerResults'',''var'')'),return,end
            values=evalin('base','nirpTracerResults');key=matlab.lang.makeValidName([bdroot(obj.BlockPath) '_' get_param(obj.BlockPath,'Name')]);if isstruct(values)&&isfield(values,key),result=values.(key);end
        end
        function showReaction(obj,reaction)
            names=reaction.componentNames(:);n=numel(names);key=reaction.keyIndex;
            segX=repmat({''},n,1);mmX=segX;if isfinite(reaction.Xseg),segX{key}=sprintf('%.6g',reaction.Xseg);end;if isfinite(reaction.Xmm),mmX{key}=sprintf('%.6g',reaction.Xmm);end
            switch lower(char(reaction.mode))
                case 'segregation'
                    obj.ResultsTable.ColumnName={'Component','Segregation C (mol/m^3)','Key conversion'};obj.ResultsTable.Data=[names num2cell(reaction.Cseg(:)) segX];
                case 'max mixedness'
                    obj.ResultsTable.ColumnName={'Component','Max mixedness C (mol/m^3)','Key conversion'};obj.ResultsTable.Data=[names num2cell(reaction.Cmm(:)) mmX];
                otherwise
                    obj.ResultsTable.ColumnName={'Component','Segregation C','Seg. key X','Max mixedness C','MM key X'};obj.ResultsTable.Data=[names num2cell(reaction.Cseg(:)) segX num2cell(reaction.Cmm(:)) mmX];
            end
            interval='';if all(isfinite(reaction.interval)),interval=sprintf(' Conversion interval: %.6g (%s) to %.6g (%s).',reaction.interval(1),reaction.lowerModel,reaction.interval(2),reaction.upperModel);end
            obj.ValidityLabel.Text=[reaction.warning interval];
        end
        function build(obj,visible)
            obj.Figure=uifigure('Name','Tracer Monitor','Tag','NirpTracerMonitorDialog','Visible',visible,'Position',[180 80 760 570]);
            g=uigridlayout(obj.Figure,[7 2],'RowHeight',{35,50,35,'1x',65,25,38},'ColumnWidth',{220,'1x'});
            t=uilabel(g,'Text','Tracer and stationary micromixing results','FontWeight','bold','FontSize',15);t.Layout.Column=[1 2];
            note=uilabel(g,'Text','The source signal and accumulated E(t) remain available in the results viewer. Reactive concentrations are evaluated once per vessel and simulation.','WordWrap','on');note.Layout.Column=[1 2];
            uilabel(g,'Text','Lost-area warning (%)');obj.WarningField=uieditfield(g,'numeric');
            obj.ResultsTable=uitable(g,'ColumnEditable',false);obj.ResultsTable.Layout.Column=[1 2];
            obj.ValidityLabel=uilabel(g,'Text','','WordWrap','on');obj.ValidityLabel.Layout.Column=[1 2];
            obj.StatusLabel=uilabel(g,'Text','Ready.');obj.StatusLabel.Layout.Column=[1 2];buttons(obj,g);
        end
    end
end
function buttons(obj,g),b=uigridlayout(g,[1 5],'ColumnWidth',{'1x',65,65,65,65});b.Layout.Column=[1 2];uilabel(b,'Text','');uibutton(b,'Text','Help','ButtonPushedFcn',@(~,~)openNirpGuide(nirp.tracerflowsheet.helpTarget('monitor')));uibutton(b,'Text','OK','ButtonPushedFcn',@(~,~)obj.accept());uibutton(b,'Text','Cancel','ButtonPushedFcn',@(~,~)obj.cancel());uibutton(b,'Text','Apply','ButtonPushedFcn',@(~,~)obj.apply());end
