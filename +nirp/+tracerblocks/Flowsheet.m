classdef Flowsheet < matlab.System
    % Flowsheet owns the fixed time grid for a tracer-only diagram.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 22, 2026. Last update: October 24, 2026
    % =========================================================================
    properties (Nontunable)
        Dt = 0.1
        TFinal = 10
        TimeUnit = 's'
    end
    methods (Access=protected)
        function setupImpl(obj)
            nirp.tracer.grid(obj.Dt,obj.TFinal) ;
            nirp.tracerflowsheet.validateSeparation(bdroot(gcb)) ;
        end
        function stepImpl(~)
        end
        function n=getNumInputsImpl(~),n=0;end
        function n=getNumOutputsImpl(~),n=0;end
        function icon=getIconImpl(~),icon=sprintf('Tracer Flowsheet\ncommon time grid');end
        function sts=getSampleTimeImpl(obj),sts=createSampleTime(obj,'Type','Discrete','SampleTime',obj.Dt);end
    end
    methods (Static,Access=protected)
        function mode=getSimulateUsingImpl(),mode='Interpreted execution';end
        function flag=showSimulateUsingImpl(),flag=false;end
    end
end
