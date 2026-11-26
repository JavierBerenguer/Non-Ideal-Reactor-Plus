classdef Flowsheet < matlab.System
    % Flowsheet owns the fixed grid for a tracer-only network.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 22, 2026. Last update: November 3, 2026
    % =========================================================================
    properties (Nontunable)
        Dt = 0.1
        TFinal = 10
        TimeUnit = 's'
    end
    % Obsolete reactive settings (T-217): kept as block parameters so models
    % saved with them still load; tracer blocks no longer use them.
    properties (Nontunable)
        ReactionOrigin = 'Session'
        ReactionReference = ''
        KeyComponent = 1
        Temperature = 298.15
        TemperatureUnit = 'K'
        Micromixing = 'None'
    end
    methods (Access=protected)
        function setupImpl(obj)
            nirp.tracer.grid(obj.Dt,obj.TFinal) ;
            nirp.tracerflowsheet.validateSeparation(bdroot(gcb)) ;
            if ~strcmpi(obj.Micromixing,'None')
                warning('nirp:tracerblocks:ReactiveCalculationsMoved', ...
                    ['Reactive calculations moved to the Non-ideal Reactor block of the flowsheet library; ' ...
                    'this tracer flowsheet now computes tracer signals and RTDs only.']) ;
            end
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
