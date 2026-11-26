classdef Splitter < matlab.System
    % Splitter divides an SI stream through nirp.units.splitter.
    % Degrees of freedom: N-1 independent outlet fractions are specified;
    % the sum equation and inlet stream determine all outlets.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: November 4, 2026
    % =========================================================================
    properties (Nontunable)
        % Last closed outlet fractions (two empty entries for a new block).
        Fractions = [0.5 0.5]
        % Source of the first-outlet fraction.
        FractionSource = 'Dialog'
    end
    properties (Constant,Hidden)
        FractionSourceSet = matlab.system.StringSet({'Dialog','Input port'})
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
            if strcmp(obj.FractionSource,'Input port')
                [fractions,~,message]=nirp.flowsheet.closeSum(obj.Fractions,1);
                if strlength(message)>0,error('nirp:blocks:invalidFractions','Splitter "%s": %s',obj.Block,message);end
                if any(~isfinite(fractions)),fractions=repmat(1/n,1,n);end
                obj.ClosedFractions=fractions;obj.Specs=nirp.dof.readSpecs(obj.Specifications);
            elseif isempty(strtrim(obj.Specifications))&&isempty(fieldnames(obj.OutputSpecs.values))
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
        function varargout=stepImpl(obj,in,varargin)
            nirp.stream.validate(in,obj.RS.nComponents);
            cacheInput={in,varargin{:}};
            if obj.HasCache&&isequaln(cacheInput,obj.LastInput),out=obj.LastOutputs;
            else
                fractions=obj.ClosedFractions;
                externalFraction=NaN;
                if strcmp(obj.FractionSource,'Input port')
                    if isempty(varargin),error('nirp:flowsheet:waitingFor','Splitter is waiting for its Fraction 1 signal input.');end
                    externalFraction=validateExternalFraction(varargin{1});
                    fractions=scaleFirstFraction(obj.ClosedFractions,externalFraction);
                end
                if ~isempty(fieldnames(obj.Specs))||~isempty(fieldnames(obj.OutputSpecs.values))||strcmp(obj.FractionSource,'Input port')
                    if ~(obj.HasRecycle&&~nirp.flowsheet.registry('allConverged',obj.Model))
                        result=solveSpecifications(numel(obj.Fractions),obj.Specs,obj.OutputSpecs,sum(in.F),obj.Block,externalFraction,obj.ClosedFractions);
                        if ~strcmp(result.status,'complete'),throwResult(obj.Block,result);end
                        fractions=fractionVector(result,numel(obj.Fractions));obj.ClosedFractions=fractions;
                    end
                end
                evaluated=[obj.Model '/' obj.Block];
                if obj.HasRecycle
                    out=nirp.blocks.internal.evaluate(evaluated,{in},'ReactionSystem',obj.RS, ...
                        'PreparedParameters',struct('fractions',fractions));
                else
                    out=nirp.blocks.internal.evaluate(evaluated,{in},'Signals',varargin,'ReactionSystem',obj.RS);
                end
                obj.LastInput=cacheInput;obj.LastOutputs=out;obj.HasCache=true;obj.CalculationCount=obj.CalculationCount+1;
                nirp.blocks.internal.diagnostic(obj.Model,obj.Block,obj.CalculationCount,out);
            end
            varargout=out;
        end
        function n=getNumOutputsImpl(obj),n=numel(obj.Fractions);end
        function varargout=getOutputDataTypeImpl(obj),varargout=repmat({'NirpStream'},1,numel(obj.Fractions));end
        function varargout=getOutputSizeImpl(obj),varargout=repmat({[1 1]},1,numel(obj.Fractions));end
        function varargout=isOutputFixedSizeImpl(obj),varargout=repmat({true},1,numel(obj.Fractions));end
        function varargout=isOutputComplexImpl(obj),varargout=repmat({false},1,numel(obj.Fractions));end
        function n=getNumInputsImpl(obj),n=1+strcmp(obj.FractionSource,'Input port');end
        function varargout=getInputNamesImpl(obj),varargout{1}='Feed';if strcmp(obj.FractionSource,'Input port'),varargout{2}='Fraction 1 (-)';end,end
        function varargout=getOutputNamesImpl(obj),for i=1:numel(obj.Fractions),varargout{i}=sprintf('Product %d',i);end,end
        function icon=getIconImpl(~),icon='Splitter';end
    end
    methods (Static,Access=protected)
        function groups=getPropertyGroupsImpl(),groups=matlab.system.display.Section('Title','Splitter','PropertyList',{'FractionSource','Fractions','Specifications'});end
        function mode=getSimulateUsingImpl(),mode='Interpreted execution';end
        function flag=showSimulateUsingImpl(),flag=false;end
    end
end

function result=solveSpecifications(n,specs,output,inletFlow,block,externalFraction,baseline)
    if nargin<6,externalFraction=NaN;end
    model=nirp.dof.catalog.splitter(n);values=struct('F_in',inletFlow);origins=struct('F_in','external');
    if isfinite(externalFraction)
        fractions=scaleFirstFraction(baseline,externalFraction);values.f1=externalFraction;origins.f1='external';
        for i=2:n-1,name=sprintf('f%d',i);values.(name)=fractions(i);origins.(name)='specified';end
        result=nirp.dof.solve(model,values,origins);result=checkOutputSpecifications(result,output,block);
    else
        result=nirp.dof.resolveProducer(model,'Splitter',block,specs,output,values,origins);
    end
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
function value=validateExternalFraction(value)
    if ~isnumeric(value)||~isreal(value)||~isscalar(value)||~isfinite(value)||value<0||value>1
        error('nirp:blocks:invalidSplitterFraction','Splitter Fraction 1 input must be in [0, 1].');
    end
    value=double(value);
end
function fractions=scaleFirstFraction(baseline,first)
    baseline=reshape(double(baseline),1,[]);remaining=baseline(2:end);total=sum(remaining);
    if any(~isfinite(remaining))||any(remaining<0)||~isfinite(total)||total<=0
        remaining=ones(size(remaining));total=numel(remaining);
    end
    fractions=[first (1-first)*remaining/total];
end
function result=checkOutputSpecifications(result,output,block)
    names=fieldnames(output.values);conflicts=strings(0,1);
    for i=1:numel(names)
        name=names{i};if ~isfield(result.values,name),continue,end
        expected=result.values.(name);specified=output.values.(name);
        if ~(isfinite(expected)&&isfinite(specified))||abs(expected-specified)>1e-9*max([abs(expected) abs(specified) 1])
            conflicts(end+1)=string(name); %#ok<AGROW>
            result.states.(name)='conflict';
            result.messages(end+1)=sprintf('Splitter "%s" conflicts with Stream "%s".',block,output.streams.(name)); %#ok<AGROW>
        end
    end
    if ~isempty(conflicts),result.status='conflict';result.conflicts=unique([result.conflicts conflicts],'stable');result.messages=unique(result.messages,'stable');end
    result.external=output;
end
