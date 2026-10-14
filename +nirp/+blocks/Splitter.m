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
        RS; LastInput; LastOutputs; HasCache=false; CalculationCount=0; Model; Block; ClosedFractions; Specs
    end
    methods (Access=protected)
        function setupImpl(obj)
            n=numel(obj.Fractions); if n<2 || n>20,error('nirp:blocks:invalidPorts','Fractions must define 2 to 20 outlets.');end
            if ~isnumeric(obj.Fractions)||~isreal(obj.Fractions)||~isvector(obj.Fractions)
                error('nirp:blocks:invalidFractions','Fractions must be a real numeric vector.');
            end
            if isempty(strtrim(obj.Specifications))
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
                result=solveSpecifications(numel(obj.Fractions),obj.Specs,NaN);
                if ~strcmp(result.status,'complete'),throwResult(get_param(gcb,'Name'),result);end
                obj.ClosedFractions=fractionVector(result,numel(obj.Fractions));
            end
            [obj.Model,~,obj.RS]=nirp.blocks.internal.modelPackage(); obj.Block=get_param(gcb,'Name');
            obj.HasCache=false; obj.CalculationCount=0;
        end
        function varargout=stepImpl(obj,in)
            nirp.stream.validate(in,obj.RS.nComponents);
            if obj.HasCache&&isequaln(in,obj.LastInput),out=obj.LastOutputs;
            else
                fractions=obj.ClosedFractions;
                if ~isempty(fieldnames(obj.Specs))
                    result=solveSpecifications(numel(obj.Fractions),obj.Specs,sum(in.F));
                    if ~strcmp(result.status,'complete'),throwResult(obj.Block,result);end
                    fractions=fractionVector(result,numel(obj.Fractions));
                end
                out=nirp.units.splitter(struct('fractions',fractions),in,obj.RS);
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

function result=solveSpecifications(n,specs,inletFlow)
    model=nirp.dof.catalog.splitter(n);values=struct('F_in',inletFlow);origins=struct('F_in','external');
    names=fieldnames(specs);
    for i=1:numel(names)
        if isempty(regexp(names{i},'^f\d+$','once'))||str2double(extractAfter(names{i},1))>n
            error('nirp:blocks:invalidSpecifications','Unknown Splitter specification "%s".',names{i});
        end
        values.(names{i})=specs.(names{i}).si;origins.(names{i})='specified';
    end
    result=nirp.dof.solve(model,values,origins);
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
