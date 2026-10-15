classdef SeparatorDialog < handle
%SEPARATORDIALOG Edit and close component separator specifications.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 10, 2026. Last update: October 14, 2026
% =========================================================================
    properties (SetAccess=private)
        BlockPath;Figure;NameField;RecoveryTable;ConnectionTable;StatusLabel;DataModel
    end
    properties (Access=private)
        Origins;ComponentNames;LastResult;Updating=false
    end
    methods
        function obj=SeparatorDialog(blockPath,varargin)
            p=inputParser;addParameter(p,'Visible','on');parse(p,varargin{:});obj.BlockPath=getfullname(blockPath);
            if string(get_param(obj.BlockPath,'System'))~="nirp.blocks.Separator",error('nirp:flowsheet:invalidBlock','SeparatorDialog requires a Separator block.');end
            obj.build(char(string(p.Results.Visible)));nirp.flowsheet.internal.formatNumericControls(obj.Figure);obj.load();
        end
        function delete(obj),if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure);end,end
        function setRecovery(obj,values)
            if isscalar(values),values=repmat(values,1,numel(obj.ComponentNames));end
            if numel(values)~=numel(obj.ComponentNames),error('nirp:flowsheet:invalidRecovery','Give one recovery per component.');end
            for i=1:numel(values),obj.setCell(i,2,values(i));obj.Origins.r(i)=valueOrigin(values(i));end;obj.close();
        end
        function setSpecification(obj,name,values)
            map=struct('r',2,'f_top',3,'f_bot',4,'x_top',5,'x_bot',6);key=lower(char(string(name)));
            if ~isfield(map,key),error('nirp:flowsheet:unknownMagnitude','Unknown Separator magnitude "%s".',name);end
            if isscalar(values),values=repmat(values,1,numel(obj.ComponentNames));end
            if numel(values)~=numel(obj.ComponentNames),error('nirp:flowsheet:invalidSpecification','Give one value per component.');end
            for i=1:numel(values),obj.setCell(i,map.(key),values(i));obj.Origins.(key)(i)=valueOrigin(values(i));end;obj.close();
        end
        function values=getValues(obj),obj.captureModel();values=obj.DataModel;end
        function applied=apply(obj)
            applied=obj.close();if ~applied,obj.alertConflict();return,end
            r=zeros(1,numel(obj.ComponentNames));for i=1:numel(r),r(i)=obj.LastResult.values.(['r' num2str(i)]);end
            if any(~isfinite(r)),obj.StatusLabel.Text='Results need a run or the other components.';obj.alertConflict();applied=false;return,end
            specs=struct();names=fieldnames(obj.LastResult.origins);
            for i=1:numel(names),key=names{i};if string(obj.LastResult.origins.(key))=="specified",specs.(key)=struct('si',obj.LastResult.values.(key),'unit',unitFor(key));end,end
            try
                set_param(obj.BlockPath,'Recovery',mat2str(r,17));writeProducerSpecs(obj.BlockPath,specs);
                obj.StatusLabel.Text='Fully specified';obj.refreshConnections();nirp.flowsheet.afterApply(bdroot(obj.BlockPath),obj.StatusLabel);applied=true;
            catch exception,obj.StatusLabel.Text=exception.message;obj.alertConflict();applied=false;end
        end
        function accept(obj),if obj.apply(),delete(obj);end,end
        function cancel(obj),delete(obj);end
    end
    methods (Static),function dialog=open(blockPath),dialog=nirp.flowsheet.SeparatorDialog(blockPath);end,end
    methods (Access=private)
        function build(obj,visible)
            obj.Figure=uifigure('Name','Separator','Tag','NirpSeparatorDialog','Visible',visible,'Position',[80 80 980 560],'WindowStyle','alwaysontop');
            main=uigridlayout(obj.Figure,[4 1],'RowHeight',{38,'1x',30,38},'Padding',[12 10 12 10]);
            h=uigridlayout(main,[1 3],'ColumnWidth',{60,'1x',160});uilabel(h,'Text','Name','HorizontalAlignment','right');obj.NameField=uieditfield(h,'text','Editable','off');uibutton(h,'Text','Unit conversion helper','ButtonPushedFcn',@(~,~) UnitConverterHelper.launch());
            tabs=uitabgroup(main);sep=uitab(tabs,'Title','Component split');connections=uitab(tabs,'Title','Connections');g=uigridlayout(sep,[2 1],'RowHeight',{28,'1x'});
            uilabel(g,'Text','Specify one independent value per component; calculated cells are refreshed immediately.','FontAngle','italic');
            obj.RecoveryTable=uitable(g,'ColumnName',{'Component','Recovery','Top F (mol/s)','Bottom F (mol/s)','Top x','Bottom x'}, ...
                'ColumnEditable',[false true true true true true],'ColumnFormat',{'char','numeric','numeric','numeric','numeric','numeric'},'RowName',{},'CellEditCallback',@(~,event)obj.cellEdited(event));
            cg=uigridlayout(connections,[2 1],'RowHeight',{30,'1x'});uilabel(cg,'Text','Connected material streams (read only)','FontWeight','bold');obj.ConnectionTable=uitable(cg,'ColumnName',{'Direction','Port','Stream'},'ColumnEditable',[false false false]);
            obj.StatusLabel=uilabel(main,'Text','Ready.','FontAngle','italic');b=uigridlayout(main,[1 4],'ColumnWidth',{'1x',90,90,90});uilabel(b,'Text','');uibutton(b,'Text','OK','ButtonPushedFcn',@(~,~)obj.accept());uibutton(b,'Text','Cancel','ButtonPushedFcn',@(~,~)obj.cancel());uibutton(b,'Text','Apply','ButtonPushedFcn',@(~,~)obj.apply());
        end
        function load(obj)
            obj.NameField.Value=get_param(obj.BlockPath,'Name');pkg=nirp.pkg.readDictionary(nirp.flowsheet.modelDictionary(bdroot(obj.BlockPath)));obj.ComponentNames=string({pkg.components.name});n=numel(obj.ComponentNames);
            obj.RecoveryTable.Data=[cellstr(obj.ComponentNames(:)) repmat({[]},n,5)];empty=repmat("empty",n,1);obj.Origins=struct('r',empty,'f_top',empty,'f_bot',empty,'x_top',empty,'x_bot',empty);
            text=get_param(obj.BlockPath,'Specifications');
            if isempty(strtrim(text))
                r=str2num(get_param(obj.BlockPath,'Recovery')); %#ok<ST2NM>
                if isscalar(r),r=repmat(r,1,n);end
                if numel(r)==n,for i=1:n,if isfinite(r(i)),obj.setCell(i,2,r(i));obj.Origins.r(i)="specified";end,end,end
            else
                specs=nirp.dof.readSpecs(text);names=fieldnames(specs);for i=1:numel(names),obj.loadSpec(names{i},specs.(names{i}).si);end
            end
            obj.close();obj.refreshConnections();
        end
        function valid=close(obj)
            if obj.Updating,valid=false;return,end;obj.Updating=true;clean=onCleanup(@()obj.finishUpdate());n=numel(obj.ComponentNames);prefixes={'r','F_top','F_bot','x_top','x_bot'};originKeys={'r','f_top','f_bot','x_top','x_bot'};specs=struct();
            for column=1:5,for i=1:n,key=[prefixes{column} num2str(i)];if obj.Origins.(originKeys{column})(i)=="specified",value=obj.readCell(i,column+1);if isfinite(value),specs.(key)=struct('si',value,'unit',unitFor(key));end,end,end,end
            try,state=nirp.dof.producerState(obj.BlockPath,'InternalSpecifications',specs);result=state.Result;inlet=state.Inlet;source=state.InletSource;catch exception,result=failure(prefixes,n,exception.message);inlet=[];source="";state=struct('Output',struct('sources',struct()));end
            obj.LastResult=result;unresolved=false;
            for column=1:5,for i=1:n,key=[prefixes{column} num2str(i)];obj.setCell(i,column+1,result.values.(key));obj.Origins.(originKeys{column})(i)=string(result.origins.(key));end,end
            if strcmp(result.status,'complete'),for i=1:n,unresolved=unresolved||~isfinite(result.values.(['r' num2str(i)]));end,end
            obj.captureModel();obj.showStates(result,isempty(inlet));sources=fieldnames(state.Output.sources);if isempty(inlet),obj.RecoveryTable.Tooltip='needs a run or a defined feed';elseif isempty(sources),obj.RecoveryTable.Tooltip='';else,obj.RecoveryTable.Tooltip=char(strjoin(string(struct2cell(state.Output.sources)),'; '));end
            if strcmp(result.status,'conflict'),message="Conflict: "+strjoin(result.messages,' ');status='conflict';
            elseif strcmp(result.status,'missing'),message=result.messages(end);status='missing';
            elseif unresolved,message="Needs the other components";status='missing';
            else,message="Fully specified";status='complete';if strlength(source)>0,message=message+" - "+source;elseif isempty(inlet),message=message+" - results need a run or a defined feed";end,end
            [~,~,runLabel]=nirp.flowsheet.blockStatus(obj.BlockPath);message=message+" - "+runLabel;nirp.flowsheet.internal.paintDofStatus(obj.StatusLabel,status,message);valid=strcmp(status,'complete');
            obj.RecoveryTable.ColumnEditable=[false true true true true true];
        end
        function cellEdited(obj,event)
            if obj.Updating,return,end;row=event.Indices(1);column=event.Indices(2);keys={'','r','f_top','f_bot','x_top','x_bot'};obj.Origins.(keys{column})(row)=valueOrigin(event.NewData);obj.close();
        end
        function loadSpec(obj,key,value)
            token=regexp(key,'^(r|F_top|F_bot|x_top|x_bot)(\d+)$','tokens','once');if isempty(token),return,end;row=str2double(token{2});map=struct('r',2,'F_top',3,'F_bot',4,'x_top',5,'x_bot',6);if row<=numel(obj.ComponentNames),obj.setCell(row,map.(token{1}),value);obj.Origins.(lower(token{1}))(row)="specified";end
        end
        function value=readCell(obj,row,column),value=obj.RecoveryTable.Data{row,column};if ischar(value)||isstring(value),value=str2double(value);end;if isempty(value)||~isnumeric(value)||~isscalar(value),value=NaN;end,end
        function setCell(obj,row,column,value),d=obj.RecoveryTable.Data;if isnumeric(value)&&isscalar(value)&&isfinite(value),d{row,column}=nirp.flowsheet.internal.formatTableNumber(value);else,d{row,column}=[];end;obj.RecoveryTable.Data=d;end
        function captureModel(obj)
            n=numel(obj.ComponentNames);names={'Recovery','TopFlow','BottomFlow','TopFraction','BottomFraction'};keys={'r','f_top','f_bot','x_top','x_bot'};units={'1','mol/s','mol/s','1','1'};data=struct();for c=1:5,v=nan(1,n);for i=1:n,v(i)=obj.readCell(i,c+1);end;data.(names{c})=struct('value',v,'unit',units{c},'origin',obj.Origins.(keys{c}));end;data.Result=obj.LastResult;obj.DataModel=data;
        end
        function showStates(obj,result,waiting),removeStyle(obj.RecoveryTable);n=numel(obj.ComponentNames);prefixes={'r','F_top','F_bot','x_top','x_bot'};for c=1:5,s=strings(n,1);for i=1:n,s(i)=string(result.states.([prefixes{c} num2str(i)]));end;if waiting&&c>1,s(s=="empty")="external";end;addStates(obj.RecoveryTable,c+1,s);end,end
        function refreshConnections(obj)
            graph=nirp.flowsheet.topology(bdroot(obj.BlockPath));key=matlab.lang.makeValidName(get_param(obj.BlockPath,'Name'));data=cell(0,3);outputs={'Top','Bottom'};
            if isfield(graph.Units,key),x=graph.Units.(key);for i=1:numel(x.Inputs),data(end+1,:)={'Input',i,label(x.Inputs{i})};end;for i=1:numel(x.Outputs),data(end+1,:)={['Output (' outputs{min(i,2)} ')'],i,label(x.Outputs{i})};end,end;obj.ConnectionTable.Data=data;
        end
        function finishUpdate(obj),obj.Updating=false;end
        function alertConflict(obj),if isvalid(obj.Figure)&&strcmp(obj.Figure.Visible,'on'),uialert(obj.Figure,obj.StatusLabel.Text,'Separator','Icon','error');end,end
    end
end
function origin=valueOrigin(value),if isempty(value)||(isnumeric(value)&&isscalar(value)&&isnan(value)),origin="empty";else,origin="specified";end,end
function value=unitFor(key),if startsWith(key,'F_'),value='mol/s';else,value='1';end,end
function addStates(tableHandle,column,states),defs={"specified",[0.15 0.25 0.55],'normal';"calculated",[0.92 0.92 0.92],'italic';"empty",[1 0.90 0.90],'normal';"external",[0.88 0.88 0.88],'normal';"conflict",[1 0.72 0.72],'normal'};for i=1:size(defs,1),rows=find(states==defs{i,1});if isempty(rows),continue,end;s=uistyle('FontAngle',defs{i,3});if defs{i,1}=="specified",s.FontColor=defs{i,2};else,s.BackgroundColor=defs{i,2};end;addStyle(tableHandle,s,'cell',[rows repmat(column,numel(rows),1)]);end,end
function s=label(v),if isempty(v),s='<missing>';else,s=char(strjoin(string(v),', '));end,end
function result=failure(prefixes,n,message),values=struct();origins=struct();states=struct();names=strings(0,1);for p=1:numel(prefixes),for i=1:n,name=[prefixes{p} num2str(i)];values.(name)=NaN;origins.(name)='empty';states.(name)='conflict';names(end+1)=string(name);end,end;result=struct('values',values,'origins',origins,'states',states,'messages',string(message),'status','conflict','missingCount',0,'missing',strings(0,1),'conflicts',names);end
function writeProducerSpecs(block,specs),if isempty(fieldnames(specs)),set_param(block,'Specifications','{}');else,nirp.dof.writeSpecs(block,specs);end,end
