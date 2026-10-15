classdef Splitter < matlab.System
    % Splitter divides an SI stream through nirp.units.splitter.
    % Degrees of freedom: N-1 independent outlet fractions are specified;
    % the sum equation and inlet stream determine all outlets.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 14, 2026
    % =========================================================================
    properties (Nontunable)
        % Last closed outlet fractions (two empty entries for a new block).
        Fractions = [0.5 0.5]
    end
    properties (Nontunable)
        % JSON containing only user specifications; empty means legacy.
        Specifications = ''
    end
    properties (Access=private)
        RS; LastInput; LastOutputs; HasCache=false; CalculationCount=0; Model; Block; ClosedFractions; Specs; OutputSpecs; HasRecycle=false
    end
    methods (Access=protected)
        function setupImpl(obj)
            n=numel(obj.Fractions); if n<2 || n>20,error('nirp:blocks:invalidPorts','Fractions must define 2 to 20 outlets.');end
            if ~isnumeric(obj.Fractions)||~isreal(obj.Fractions)||~isvector(obj.Fractions)
                error('nirp:blocks:invalidFractions','Fractions must be a real numeric vector.');
            end
            obj.Block=get_param(gcb,'Name');obj.OutputSpecs=nirp.dof.connectedSpecifications(gcb);obj.HasRecycle=hasRecycle(bdroot(gcb));
            if isempty(strtrim(obj.Specifications))&&isempty(fieldnames(obj.OutputSpecs.values))
                [fractions,~,message]=nirp.flowsheet.closeSum(obj.Fractions,1);
                if strlength(message)>0
                    error('nirp:blocks:invalidFractions','Splitter "%s": %s',get_param(gcb,'Name'),message);
                end
                if any(~isfinite(fractions))
                    missing=sum(~isfinite(fractions));if missing==0,missing=1;end
                    error('nirp:blocks:missingSpecifications', ...
                        'Splitter "%s": %d specification%s missing: fractions.', ...
                        get_param(gcb,'Name'),missing,plural(missing));
                end
                obj.ClosedFractions=fractions;obj.Specs=struct();
            else
                obj.Specs=nirp.dof.readSpecs(obj.Specifications);
                if isempty(fieldnames(obj.Specs))&&isempty(strtrim(obj.Specifications)),obj.Specs=legacySpecs(obj.Fractions);end
                result=solveSpecifications(numel(obj.Fractions),obj.Specs,obj.OutputSpecs,NaN,obj.Block);
                if ~strcmp(result.status,'complete'),throwResult(get_param(gcb,'Name'),result);end
                obj.ClosedFractions=legacyFractions(obj.Fractions);candidate=fractionVector(result,numel(obj.Fractions));if all(isfinite(candidate)),obj.ClosedFractions=candidate;end
            end
            if any(~isfinite(obj.ClosedFractions))
                % Start-up estimate when no split was ever closed (e.g. only an outlet flow is
                % specified and the inlet was unknown): equal split; the specification applies once
                % the loop converges (Claude, T-155 review).
                obj.ClosedFractions=repmat(1/numel(obj.Fractions),1,numel(obj.Fractions));
            end
            [obj.Model,~,obj.RS]=nirp.blocks.internal.modelPackage();
            obj.HasCache=false; obj.CalculationCount=0;
        end
        function varargout=stepImpl(obj,in)
            nirp.stream.validate(in,obj.RS.nComponents);
            if obj.HasCache&&isequaln(in,obj.LastInput),out=obj.LastOutputs;
            else
                fractions=obj.ClosedFractions;
                if ~isempty(fieldnames(obj.Specs))||~isempty(fieldnames(obj.OutputSpecs.values))
                    if ~(obj.HasRecycle&&~nirp.flowsheet.registry('allConverged',obj.Model))
                        result=solveSpecifications(numel(obj.Fractions),obj.Specs,obj.OutputSpecs,sum(in.F),obj.Block);
                        if ~strcmp(result.status,'complete'),throwResult(obj.Block,result);end
                        fractions=fractionVector(result,numel(obj.Fractions));obj.ClosedFractions=fractions;
                    end
                end
                evaluated=[obj.Model '/' obj.Block];
                if obj.HasRecycle
                    out=nirp.blocks.internal.evaluate(evaluated,{in},'ReactionSystem',obj.RS, ...
                        'PreparedParameters',struct('fractions',fractions));
                else
                    out=nirp.blocks.internal.evaluate(evaluated,{in},'ReactionSystem',obj.RS);
                end
                obj.LastInput=in;obj.LastOutputs=out;obj.HasCache=true;obj.CalculationCount=obj.CalculationCount+1;
                nirp.blocks.internal.diagnostic(obj.Model,obj.Block,obj.CalculationCount,out);
            end
            varargout=out;
        end
        function n=getNumOutputsImpl(obj),n=numel(obj.Fractions);end
        function varargout=getOutputDataTypeImpl(obj),varargout=repmat({'NirpStream'},1,numel(obj.Fractions));end
        function varargout=getOutputSizeImpl(obj),varargout=repmat({[1 1]},1,numel(obj.Fractions));end
        function varargout=isOutputFixedSizeImpl(obj),varargout=repmat({true},1,numel(obj.Fractions));end
        function varargout=isOutputComplexImpl(obj),varargout=repmat({false},1,numel(obj.Fractions));end
        function name=getInputNamesImpl(~),name='Feed';end
        function varargout=getOutputNamesImpl(obj),for i=1:numel(obj.Fractions),varargout{i}=sprintf('Product %d',i);end,end
        function icon=getIconImpl(~),icon='Splitter';end
    end
    methods (Static,Access=protected)
        function groups=getPropertyGroupsImpl(),groups=matlab.system.display.Section('Title','Splitter','PropertyList',{'Fractions','Specifications'});end
        function mode=getSimulateUsingImpl(),mode='Interpreted execution';end
        function flag=showSimulateUsingImpl(),flag=false;end
    end
end

function result=solveSpecifications(n,specs,output,inletFlow,block)
    model=nirp.dof.catalog.splitter(n);values=struct('F_in',inletFlow);origins=struct('F_in','external');
    result=nirp.dof.resolveProducer(model,'Splitter',block,specs,output,values,origins);
end
function values=fractionVector(result,n)
    values=zeros(1,n);for i=1:n,values(i)=result.values.(sprintf('f%d',i));end
end
function throwResult(block,result)
    if strcmp(result.status,'missing')
        vars=strjoin(result.missing,', ');if strlength(vars)==0,vars="fractions";end
        error('nirp:blocks:missingSpecifications','Splitter "%s": %d specification%s missing: %s.', ...
            block,result.missingCount,plural(result.missingCount),vars);
    end
    error('nirp:blocks:conflictingSpecifications','Splitter "%s": conflict in %s: %s', ...
        block,strjoin(result.conflicts,', '),strjoin(result.messages,' '));
end
function text=plural(n),if n==1,text='';else,text='s';end,end
function specs=legacySpecs(values),specs=struct();for i=1:max(0,numel(values)-1),if isfinite(values(i)),specs.(['f' num2str(i)])=struct('si',values(i),'unit','1');end,end,end
function values=legacyFractions(input),[values,~,message]=nirp.flowsheet.closeSum(input,1);if strlength(message)>0||any(~isfinite(values)),values=input;end,end
function flag=hasRecycle(model),flag=~isempty(find_system(model,'LookUnderMasks','all','SearchDepth',1,'BlockType','MATLABSystem','System','nirp.blocks.Recycle'));end
