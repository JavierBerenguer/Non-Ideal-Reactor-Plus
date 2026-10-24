classdef Splitter < matlab.System
    % Splitter calls nirp.tracer.splitter; the final fraction is calculated.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 22, 2026. Last update: October 24, 2026
    % =========================================================================
    properties (Nontunable),Dt=0.1;TFinal=10;Fractions=0.5;end
    methods (Access=protected)
        function setupImpl(obj),nirp.tracer.grid(obj.Dt,obj.TFinal);nirp.tracerflowsheet.validateSeparation(bdroot(gcb));end
        function varargout=stepImpl(obj,in)
            [values,~]=nirp.tracer.splitter(nirp.tracer.grid(obj.Dt,obj.TFinal),fromBus(in),obj.Fractions);
            for k=1:numel(values),varargout{k}=toBus(values{k});end
        end
        function n=getNumOutputsImpl(obj),n=numel(obj.Fractions)+1;end
        function varargout=getOutputDataTypeImpl(obj),varargout=repmat({'NirpTracer'},1,numel(obj.Fractions)+1);end
        function varargout=getOutputSizeImpl(obj),varargout=repmat({[1 1]},1,numel(obj.Fractions)+1);end
        function varargout=isOutputFixedSizeImpl(obj),varargout=repmat({true},1,numel(obj.Fractions)+1);end
        function varargout=isOutputComplexImpl(obj),varargout=repmat({false},1,numel(obj.Fractions)+1);end
        function name=getInputNamesImpl(~),name='In';end
        function varargout=getOutputNamesImpl(obj),for k=1:numel(obj.Fractions)+1,varargout{k}=sprintf('Out %d',k);end,end
        function icon=getIconImpl(~),icon=sprintf('Tracer Splitter\nQi = fi·Q');end
    end
    methods (Static,Access=protected)
        function mode=getSimulateUsingImpl(),mode='Interpreted execution';end
        function flag=showSimulateUsingImpl(),flag=false;end
    end
end
function value=fromBus(value),value.C=reshape(value.C,1,[]);value.E=reshape(value.E,1,[]);end
function value=toBus(value),value.C=value.C(:);value.E=value.E(:);end
