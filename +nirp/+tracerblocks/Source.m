classdef Source < matlab.System
    % Source creates a NirpTracer stream through the tracer core.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 22, 2026. Last update: October 25, 2026
    % =========================================================================
    properties (Nontunable)
        Dt=0.1; TFinal=10; Q=1; QUnit='m^3/s'; SourceId=uint32(1)
        SignalMode='Data'; DataTime=[0 10]; DataConcentration=[1 1]
        FunctionEdges=[0 10]; FunctionExpressions={'1'}
        FeedConcentrations=0; ConcentrationUnit='mol/m^3'
    end
    properties (Access=private),Output;end
    methods (Access=protected)
        function setupImpl(obj)
            nirp.tracerflowsheet.validateSeparation(bdroot(gcb));grid=nirp.tracer.grid(obj.Dt,obj.TFinal);
            switch lower(strtrim(obj.SignalMode))
                case 'data',obj.Output=nirp.tracer.sourceData(grid,obj.Q,obj.DataTime,obj.DataConcentration,obj.SourceId);
                case 'function'
                    expressions=cellstr(string(obj.FunctionExpressions));functions=cell(size(expressions));
                    for k=1:numel(expressions),functions{k}=str2func(['@(t)' expressions{k}]);end
                    obj.Output=nirp.tracer.sourceFunction(grid,obj.Q,obj.FunctionEdges,functions,obj.SourceId);
                otherwise,error('nirp:tracerblocks:InvalidSignalMode','SignalMode must be Data or Function.');
            end
            config=nirp.tracerflowsheet.reactionConfiguration(gcb);
            if config.enabled
                concentrations=reshape(double(obj.FeedConcentrations),1,[]);
                if numel(concentrations)~=config.RS.nComponents||any(~isfinite(concentrations))||any(concentrations<0)
                    error('nirp:tracerblocks:InvalidFeedComposition','FeedConcentrations must contain one nonnegative finite value per component.');
                end
                obj.Output.C0=concentrations;obj.Output.Cseg=concentrations;obj.Output.Cmm=concentrations;
                obj.Output.reactiveMode=config.mode;obj.Output.rtdTruncated=false;
            end
            obj.Output=toBus(obj.Output);
        end
        function out=stepImpl(obj),out=obj.Output;end
        function n=getNumInputsImpl(~),n=0;end
        function type=getOutputDataTypeImpl(~),type='NirpTracer';end
        function size=getOutputSizeImpl(~),size=[1 1];end
        function flag=isOutputFixedSizeImpl(~),flag=true;end
        function flag=isOutputComplexImpl(~),flag=false;end
        function name=getOutputNamesImpl(~),name='Tracer';end
        function icon=getIconImpl(~),icon=sprintf('Tracer Source\nCin(t)');end
        function sts=getSampleTimeImpl(obj),sts=createSampleTime(obj,'Type','Discrete','SampleTime',obj.Dt);end
    end
    methods (Static,Access=protected)
        function mode=getSimulateUsingImpl(),mode='Interpreted execution';end
        function flag=showSimulateUsingImpl(),flag=false;end
    end
end
function value=toBus(value),value.C=value.C(:);value.E=value.E(:);value.C0=value.C0(:);value.Cseg=value.Cseg(:);value.Cmm=value.Cmm(:);end
