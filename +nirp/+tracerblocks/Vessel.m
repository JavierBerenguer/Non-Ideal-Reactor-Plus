classdef Vessel < matlab.System
    % Vessel convolves concentration and path RTD through nirp.tracer.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 22, 2026. Last update: October 22, 2026
    % =========================================================================
    properties (Nontunable)
        Dt=0.1; TFinal=10; Origin='Model'; Model='CSTR'; ResidenceBasis='Tau'
        Tau=1; Volume=1; N=2; Pe=10; Boundary='open'
        DataTime=[0 10]; DataE=[1 0]; SessionFile=''
    end
    methods (Access=protected)
        function setupImpl(obj),nirp.tracer.grid(obj.Dt,obj.TFinal);nirp.tracerflowsheet.validateSeparation(bdroot(gcb));end
        function out=stepImpl(obj,in)
            grid=nirp.tracer.grid(obj.Dt,obj.TFinal);input=fromBus(in);
            switch lower(strtrim(obj.Origin))
                case 'model'
                    if strcmpi(obj.ResidenceBasis,'Volume'),parameters=struct('V',obj.Volume);else,parameters=struct('tau',obj.Tau);end
                    if any(strcmpi(obj.Model,{'Tanks','Tanks in series','Tanks-in-series'})),parameters.N=obj.N;end
                    if strcmpi(obj.Model,'Dispersion'),parameters.Pe=obj.Pe;parameters.boundary=obj.Boundary;end
                    E=nirp.tracer.rtdModel(grid,obj.Model,parameters,input.Q);
                case 'data',E=nirp.tracer.rtdData(grid,obj.DataTime,obj.DataE);
                case 'session',E=nirp.tracer.rtdSession(grid,obj.SessionFile);
                otherwise,error('nirp:tracerblocks:InvalidRTDOrigin','Origin must be Model, Data, or Session.');
            end
            out=nirp.tracer.vessel(grid,input,E);out=toBus(out);
        end
        function type=getOutputDataTypeImpl(~),type='NirpTracer';end
        function size=getOutputSizeImpl(~),size=[1 1];end
        function flag=isOutputFixedSizeImpl(~),flag=true;end
        function flag=isOutputComplexImpl(~),flag=false;end
        function name=getInputNamesImpl(~),name='In';end
        function name=getOutputNamesImpl(~),name='Out';end
        function icon=getIconImpl(~),icon=sprintf('Non-ideal Vessel\nC_{out}=C_{in}*E');end
    end
    methods (Static,Access=protected)
        function mode=getSimulateUsingImpl(),mode='Interpreted execution';end
        function flag=showSimulateUsingImpl(),flag=false;end
    end
end
function value=fromBus(value),value.C=reshape(value.C,1,[]);value.E=reshape(value.E,1,[]);end
function value=toBus(value),value.C=value.C(:);value.E=value.E(:);end
