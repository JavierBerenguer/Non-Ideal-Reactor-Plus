classdef Monitor < matlab.System
    % Monitor publishes the latest tracer result for the headless/UI viewer.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 22, 2026. Last update: October 22, 2026
    % =========================================================================
    properties (Nontunable),Dt=0.1;TFinal=10;LostAreaWarning=0.01;end
    methods (Access=protected)
        function setupImpl(obj),nirp.tracer.grid(obj.Dt,obj.TFinal);nirp.tracerflowsheet.validateSeparation(bdroot(gcb));end
        function stepImpl(obj,in)
            grid=nirp.tracer.grid(obj.Dt,obj.TFinal);value=in;value.C=reshape(value.C,1,[]);value.E=reshape(value.E,1,[]);
            result=struct('grid',grid,'stream',value,'concentrationMoments',nirp.tracer.moments(grid,value.C), ...
                'rtdMoments',[],'warning','');
            if value.status==1,result.rtdMoments=nirp.tracer.moments(grid,value.E);if result.rtdMoments.area<1-obj.LostAreaWarning,result.warning='More than the configured RTD area is truncated; increase t_final.';end
            else,result.warning='Global RTD is undefined because the network contains multiple sources.';end
            allResults=struct();if evalin('base','exist(''nirpTracerResults'',''var'')'),allResults=evalin('base','nirpTracerResults');end
            key=matlab.lang.makeValidName([bdroot(gcb) '_' get_param(gcb,'Name')]);allResults.(key)=result;assignin('base','nirpTracerResults',allResults);
        end
        function n=getNumOutputsImpl(~),n=0;end
        function name=getInputNamesImpl(~),name='Tracer';end
        function icon=getIconImpl(~),icon=sprintf('Tracer Monitor\nC(t), E(t)');end
    end
    methods (Static,Access=protected)
        function mode=getSimulateUsingImpl(),mode='Interpreted execution';end
        function flag=showSimulateUsingImpl(),flag=false;end
    end
end
