classdef SeparatorDialog < handle
%SEPARATORDIALOG Edit the component recoveries of a Separator block (T-141).
% =========================================================================
% Javier Berenguer Sabater
% Created: October 10, 2026. Last update: October 10, 2026
% =========================================================================
    properties (SetAccess=private)
        BlockPath;Figure;NameField;RecoveryTable;ConnectionTable;StatusLabel;DataModel
    end
    methods
        function obj=SeparatorDialog(blockPath,varargin)
            p=inputParser;addParameter(p,'Visible','on');parse(p,varargin{:});obj.BlockPath=getfullname(blockPath);
            if string(get_param(obj.BlockPath,'System'))~="nirp.blocks.Separator",error('nirp:flowsheet:invalidBlock','SeparatorDialog requires a Separator block.');end
            obj.build(char(string(p.Results.Visible)));obj.load();
            [~,~,label]=nirp.flowsheet.blockStatus(obj.BlockPath);obj.StatusLabel.Text=char(label);
        end
        function delete(obj),if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure);end,end
        function setRecovery(obj,values)
            d=obj.RecoveryTable.Data;if isscalar(values),values=repmat(values,1,size(d,1));end
            if numel(values)~=size(d,1),error('nirp:flowsheet:invalidRecovery','Give one recovery per component.');end
            for i=1:size(d,1),d{i,2}=values(i);end;obj.RecoveryTable.Data=d;obj.captureModel();
        end
        function values=getValues(obj),obj.captureModel();values=obj.DataModel;end
        function applied=apply(obj)
            applied=false;obj.captureModel();r=obj.DataModel.Recovery.value;
            if any(~isfinite(r))||any(r<0)||any(r>1),obj.StatusLabel.Text='Each recovery must be between 0 and 1.';return,end
            try,set_param(obj.BlockPath,'Recovery',mat2str(r,17));obj.StatusLabel.Text='Applied.';obj.refreshConnections();applied=true;
            catch exception,obj.StatusLabel.Text=exception.message;end
        end
        function accept(obj),if obj.apply(),block=obj.BlockPath;delete(obj);nirp.flowsheet.autoRun(block);end,end
        function cancel(obj),delete(obj);end
    end
    methods (Static),function dialog=open(blockPath),dialog=nirp.flowsheet.SeparatorDialog(blockPath);end,end
    methods (Access=private)
        function build(obj,visible)
            obj.Figure=uifigure('Name','Separator','Tag','NirpSeparatorDialog','Visible',visible,'Position',[130 90 620 480],'WindowStyle','alwaysontop');
            main=uigridlayout(obj.Figure,[4 1],'RowHeight',{38,'1x',25,38},'Padding',[12 10 12 10]);
            h=uigridlayout(main,[1 3],'ColumnWidth',{60,'1x',160});uilabel(h,'Text','Name','HorizontalAlignment','right');obj.NameField=uieditfield(h,'text','Editable','off');
            uibutton(h,'Text','Unit conversion helper','ButtonPushedFcn',@(~,~) UnitConverterHelper.launch());
            tabs=uitabgroup(main);sep=uitab(tabs,'Title','Recoveries');connections=uitab(tabs,'Title','Connections');
            g=uigridlayout(sep,[2 1],'RowHeight',{24,'1x'});
            uilabel(g,'Text','Fraction of each component sent to Top (output 1); the rest goes to Bottom (output 2).','FontAngle','italic');
            obj.RecoveryTable=uitable(g,'ColumnName',{'Component','Recovery to Top'},'ColumnEditable',[false true],'ColumnFormat',{'char','numeric'},'RowName',{});
            cg=uigridlayout(connections,[2 1],'RowHeight',{30,'1x'});uilabel(cg,'Text','Connected material streams (read only)','FontWeight','bold');
            obj.ConnectionTable=uitable(cg,'ColumnName',{'Direction','Port','Stream'});
            obj.StatusLabel=uilabel(main,'Text','Ready.','FontAngle','italic');
            b=uigridlayout(main,[1 4],'ColumnWidth',{'1x',90,90,90});uilabel(b,'Text','');
            uibutton(b,'Text','OK','ButtonPushedFcn',@(~,~) obj.accept());uibutton(b,'Text','Cancel','ButtonPushedFcn',@(~,~) obj.cancel());uibutton(b,'Text','Apply','ButtonPushedFcn',@(~,~) obj.apply());
        end
        function load(obj)
            obj.NameField.Value=get_param(obj.BlockPath,'Name');
            pkg=nirp.pkg.readDictionary(nirp.flowsheet.modelDictionary(bdroot(obj.BlockPath)));names=cellstr(string({pkg.components.name}));
            r=str2num(get_param(obj.BlockPath,'Recovery')); %#ok<ST2NM>
            if isscalar(r),r=repmat(r,1,numel(names));end;if numel(r)~=numel(names),r=NaN(1,numel(names));end
            obj.RecoveryTable.Data=[names(:) num2cell(r(:))];obj.captureModel();obj.refreshConnections();
        end
        function captureModel(obj)
            d=obj.RecoveryTable.Data;r=NaN(1,size(d,1));for i=1:size(d,1),v=d{i,2};if isnumeric(v)&&isscalar(v),r(i)=v;end,end
            obj.DataModel=struct('Recovery',struct('value',r,'unit',"1",'origin',"specified"));
        end
        function refreshConnections(obj)
            graph=nirp.flowsheet.topology(bdroot(obj.BlockPath));key=matlab.lang.makeValidName(get_param(obj.BlockPath,'Name'));data=cell(0,3);
            outputs={'Top','Bottom'};
            if isfield(graph.Units,key)
                x=graph.Units.(key);
                for i=1:numel(x.Inputs),data(end+1,:)={'Input',i,label(x.Inputs{i})};end %#ok<AGROW>
                for i=1:numel(x.Outputs),data(end+1,:)={['Output (' outputs{min(i,2)} ')'],i,label(x.Outputs{i})};end %#ok<AGROW>
            end
            obj.ConnectionTable.Data=data;
        end
    end
end
function s=label(v),if isempty(v),s='<missing>';else,s=char(strjoin(string(v),', '));end,end
