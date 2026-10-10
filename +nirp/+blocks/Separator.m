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
    properties (Access=private)
        RS; LastInput; LastOutputs; HasCache=false; CalculationCount=0; Model; Block
    end
    methods (Access=protected)
        function setupImpl(obj)
            [obj.Model,~,obj.RS]=nirp.blocks.internal.modelPackage(); obj.Block=get_param(gcb,'Name');
            r=obj.Recovery;
            if ~isnumeric(r)||~isreal(r)||~(isscalar(r)||numel(r)==obj.RS.nComponents)||any(~isfinite(r(:)))||any(r(:)<0)||any(r(:)>1)
                error('nirp:blocks:invalidRecovery', ...
                    'Separator "%s": Recovery needs one value in [0,1] per component (%d).',obj.Block,obj.RS.nComponents);
            end
            obj.HasCache=false; obj.CalculationCount=0;
        end
        function [top,bottom]=stepImpl(obj,in)
            nirp.stream.validate(in,obj.RS.nComponents);
            if obj.HasCache&&isequaln(in,obj.LastInput),out=obj.LastOutputs;
            else
                [out,info]=nirp.units.separator(struct('recovery',obj.Recovery),in,obj.RS);
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
        function groups=getPropertyGroupsImpl(),groups=matlab.system.display.Section('Title','Separator','PropertyList',{'Recovery'});end
        function mode=getSimulateUsingImpl(),mode='Interpreted execution';end
        function flag=showSimulateUsingImpl(),flag=false;end
    end
end
