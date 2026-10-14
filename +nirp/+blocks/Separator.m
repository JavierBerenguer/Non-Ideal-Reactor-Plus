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
        RS; LastInput; LastOutputs; HasCache=false; CalculationCount=0; Model; Block; Specs; DofModel; OutputSpecs; ClosedRecovery; HasRecycle=false
    end
    methods (Access=protected)
        function setupImpl(obj)
            [obj.Model,~,obj.RS]=nirp.blocks.internal.modelPackage(); obj.Block=get_param(gcb,'Name');
            obj.Specs=nirp.dof.readSpecs(obj.Specifications);obj.DofModel=nirp.dof.catalog.separator(obj.RS.nComponents);obj.OutputSpecs=nirp.dof.connectedSpecifications(gcb);obj.ClosedRecovery=expandedRecovery(obj.Recovery,obj.RS.nComponents);if any(~isfinite(obj.ClosedRecovery)),obj.ClosedRecovery=0.5*ones(size(obj.ClosedRecovery));end
            % Start-up estimate when no recovery was ever closed (Claude, T-155 review).
            obj.HasRecycle=hasRecycle(bdroot(gcb));
            if isempty(strtrim(obj.Specifications))&&isempty(fieldnames(obj.Specs))&&isempty(fieldnames(obj.OutputSpecs.values))
                r=obj.Recovery;
                if any(isnan(r(:))),nirp.blocks.internal.requireSpecifications('Separator',obj.Block,'Recovery');end
                if ~isnumeric(r)||~isreal(r)||~(isscalar(r)||numel(r)==obj.RS.nComponents)||any(~isfinite(r(:)))||any(r(:)<0)||any(r(:)>1)
                    error('nirp:blocks:invalidRecovery', ...
                        'Separator "%s": Recovery needs one value in [0,1] per component (%d).',obj.Block,obj.RS.nComponents);
                end
            else
                if isempty(fieldnames(obj.Specs))&&isempty(strtrim(obj.Specifications)),obj.Specs=legacySpecs(obj.Recovery,obj.RS.nComponents);end
                result=solveSpecifications(obj.DofModel,obj.Specs,obj.OutputSpecs,nan(obj.RS.nComponents,1),obj.Block);
                if ~strcmp(result.status,'complete'),throwResult(obj.Block,result);end
            end
            obj.HasCache=false; obj.CalculationCount=0;
        end
        function [top,bottom]=stepImpl(obj,in)
            nirp.stream.validate(in,obj.RS.nComponents);
            if obj.HasCache&&isequaln(in,obj.LastInput),out=obj.LastOutputs;
            else
                recovery=obj.Recovery;
                if ~isempty(fieldnames(obj.Specs))||~isempty(fieldnames(obj.OutputSpecs.values))
                    recovery=obj.ClosedRecovery;
                    if ~(obj.HasRecycle&&~nirp.flowsheet.registry('allConverged',obj.Model))
                        result=solveSpecifications(obj.DofModel,obj.Specs,obj.OutputSpecs,in.F,obj.Block);
                        if ~strcmp(result.status,'complete'),throwResult(obj.Block,result);end
                        recovery=zeros(1,obj.RS.nComponents);for i=1:numel(recovery),recovery(i)=result.values.(['r' num2str(i)]);end;obj.ClosedRecovery=recovery;
                    end
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

function result=solveSpecifications(model,specs,output,inlet,block)
    values=struct();origins=struct();
    for i=1:numel(inlet),key=['F_in' num2str(i)];values.(key)=inlet(i);origins.(key)='external';end
    result=nirp.dof.resolveProducer(model,'Separator',block,specs,output,values,origins);
end
function specs=legacySpecs(values,n),specs=struct();if isscalar(values),values=repmat(values,1,n);end;for i=1:min(n,numel(values)),if isfinite(values(i)),specs.(['r' num2str(i)])=struct('si',values(i),'unit','1');end,end,end
function values=expandedRecovery(input,n),if isscalar(input),values=repmat(input,1,n);else,values=reshape(input,1,[]);end;if numel(values)~=n,values=nan(1,n);end,end
function flag=hasRecycle(model),flag=~isempty(find_system(model,'LookUnderMasks','all','SearchDepth',1,'BlockType','MATLABSystem','System','nirp.blocks.Recycle'));end
function throwResult(block,result)
    if strcmp(result.status,'missing')
        error('nirp:blocks:missingSpecifications','Separator "%s": %d specifications missing: %s.',block,result.missingCount,strjoin(result.missing,', '));
    end
    error('nirp:blocks:conflictingSpecifications','Separator "%s": conflict in %s: %s',block,strjoin(result.conflicts,', '),strjoin(result.messages,' '));
end
