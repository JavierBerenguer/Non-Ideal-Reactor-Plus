classdef Splitter < matlab.System
    % Splitter divides an SI stream through nirp.units.splitter.
    % Degrees of freedom: N-1 independent outlet fractions are specified;
    % the sum equation and inlet stream determine all outlets.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 3, 2026
    % =========================================================================
    properties (Nontunable)
        % Outlet fractions (2 to 20 values; at most one may be NaN).
        Fractions = [0.5 0.5]
    end
    properties (Access=private)
        RS; LastInput; LastOutputs; HasCache=false; CalculationCount=0; Model; Block; ClosedFractions
    end
    methods (Access=protected)
        function setupImpl(obj)
            n=numel(obj.Fractions); if n<2 || n>20,error('nirp:blocks:invalidPorts','Fractions must define 2 to 20 outlets.');end
            if ~isnumeric(obj.Fractions)||~isreal(obj.Fractions)||~isvector(obj.Fractions)
                error('nirp:blocks:invalidFractions','Fractions must be a real numeric vector.');
            end
            [fractions,~,message]=nirp.flowsheet.closeSum(obj.Fractions,1);
            if strlength(message)>0
                error('nirp:blocks:invalidFractions','%s',message);
            end
            obj.ClosedFractions=fractions;
            [obj.Model,~,obj.RS]=nirp.blocks.internal.modelPackage(); obj.Block=get_param(gcb,'Name');
            obj.HasCache=false; obj.CalculationCount=0;
        end
        function varargout=stepImpl(obj,in)
            nirp.stream.validate(in,obj.RS.nComponents);
            if obj.HasCache&&isequaln(in,obj.LastInput),out=obj.LastOutputs;
            else
                out=nirp.units.splitter(struct('fractions',obj.ClosedFractions),in,obj.RS);
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
        function groups=getPropertyGroupsImpl(),groups=matlab.system.display.Section('Title','Splitter','PropertyList',{'Fractions'});end
        function mode=getSimulateUsingImpl(),mode='Interpreted execution';end
        function flag=showSimulateUsingImpl(),flag=false;end
    end
end
