classdef Separator < matlab.System
    % Separator splits an SI stream component by component through
    % nirp.units.separator: Recovery(i) of component i goes to Top and the
    % rest to Bottom (T-141). A scalar Recovery applies to every component.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 10, 2026. Last update: October 10, 2026
    % =========================================================================
    properties (Nontunable)
        % Fraction of each component sent to Top (one value per component).
        Recovery = 0.5
    end
    properties (Nontunable)
        % JSON containing only user specifications; empty means legacy.
        Specifications = ''
    end
    properties (Access=private)
        RS; LastInput; LastOutputs; HasCache=false; CalculationCount=0; Model; Block; Specs; DofModel
    end
    methods (Access=protected)
        function setupImpl(obj)
            [obj.Model,~,obj.RS]=nirp.blocks.internal.modelPackage(); obj.Block=get_param(gcb,'Name');
            obj.Specs=nirp.dof.readSpecs(obj.Specifications);obj.DofModel=nirp.dof.catalog.separator(obj.RS.nComponents);
            if isempty(fieldnames(obj.Specs))
                r=obj.Recovery;
                if any(isnan(r(:))),nirp.blocks.internal.requireSpecifications('Separator',obj.Block,'Recovery');end
                if ~isnumeric(r)||~isreal(r)||~(isscalar(r)||numel(r)==obj.RS.nComponents)||any(~isfinite(r(:)))||any(r(:)<0)||any(r(:)>1)
                    error('nirp:blocks:invalidRecovery', ...
                        'Separator "%s": Recovery needs one value in [0,1] per component (%d).',obj.Block,obj.RS.nComponents);
                end
            else
                result=solveSpecifications(obj.DofModel,obj.Specs,nan(obj.RS.nComponents,1));
                if ~strcmp(result.status,'complete'),throwResult(obj.Block,result);end
            end
            obj.HasCache=false; obj.CalculationCount=0;
        end
        function [top,bottom]=stepImpl(obj,in)
            nirp.stream.validate(in,obj.RS.nComponents);
            if obj.HasCache&&isequaln(in,obj.LastInput),out=obj.LastOutputs;
            else
                recovery=obj.Recovery;
                if ~isempty(fieldnames(obj.Specs))
                    result=solveSpecifications(obj.DofModel,obj.Specs,in.F);
                    if ~strcmp(result.status,'complete'),throwResult(obj.Block,result);end
                    recovery=zeros(1,obj.RS.nComponents);for i=1:numel(recovery),recovery(i)=result.values.(['r' num2str(i)]);end
                end
                [out,info]=nirp.units.separator(struct('recovery',recovery),in,obj.RS);
                obj.LastInput=in;obj.LastOutputs=out;obj.HasCache=true;obj.CalculationCount=obj.CalculationCount+1;
                nirp.blocks.internal.diagnostic(obj.Model,obj.Block,obj.CalculationCount,out,info);
            end
            top=out{1};bottom=out{2};
        end
        function n=getNumOutputsImpl(~),n=2;end
        function [a,b]=getOutputDataTypeImpl(~),a='NirpStream';b='NirpStream';end
        function [a,b]=getOutputSizeImpl(~),a=[1 1];b=[1 1];end
        function [a,b]=isOutputFixedSizeImpl(~),a=true;b=true;end
        function [a,b]=isOutputComplexImpl(~),a=false;b=false;end
        function name=getInputNamesImpl(~),name='Feed';end
        function [a,b]=getOutputNamesImpl(~),a='Top';b='Bottom';end
        function icon=getIconImpl(~),icon='Separator';end
    end
    methods (Static,Access=protected)
        function groups=getPropertyGroupsImpl(),groups=matlab.system.display.Section('Title','Separator','PropertyList',{'Recovery','Specifications'});end
        function mode=getSimulateUsingImpl(),mode='Interpreted execution';end
        function flag=showSimulateUsingImpl(),flag=false;end
    end
end

function result=solveSpecifications(model,specs,inlet)
    values=struct();origins=struct();allowed={model.variables.name};names=fieldnames(specs);
    for i=1:numel(names)
        if ~ismember(names{i},allowed)||startsWith(names{i},'F_in')
            error('nirp:blocks:invalidSpecifications','Unknown or non-specifiable Separator specification "%s".',names{i});
        end
        values.(names{i})=specs.(names{i}).si;origins.(names{i})='specified';
    end
    for i=1:numel(inlet),key=['F_in' num2str(i)];values.(key)=inlet(i);origins.(key)='external';end
    result=nirp.dof.solve(model,values,origins);
end
function throwResult(block,result)
    if strcmp(result.status,'missing')
        error('nirp:blocks:missingSpecifications','Separator "%s": %d specifications missing: %s.',block,result.missingCount,strjoin(result.missing,', '));
    end
    error('nirp:blocks:conflictingSpecifications','Separator "%s": conflict in %s: %s',block,strjoin(result.conflicts,', '),strjoin(result.messages,' '));
end
