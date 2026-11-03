classdef Vessel < matlab.System
    % Vessel convolves tracer data and preserves compatibility bus fields.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 22, 2026. Last update: November 3, 2026
    % =========================================================================
    properties (Nontunable)
        Dt=0.1; TFinal=10; Origin='Model'; Model='CSTR'; ResidenceBasis='Tau'
        Tau=1; Volume=1; N=2; Pe=10; Boundary='open'
        DataTime=[0 10]; DataE=[1 0]; SessionFile=''
    end
    properties (Access=private),Output;end
    methods (Access=protected)
        function setupImpl(obj)
            nirp.tracer.grid(obj.Dt,obj.TFinal);nirp.tracerflowsheet.validateSeparation(bdroot(gcb));
            obj.Output=[];
        end
        function out=stepImpl(obj,in)
            if ~isempty(obj.Output),out=obj.Output;return,end
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
            out=nirp.tracer.vessel(grid,input,E);
            obj.Output=toBus(out);out=obj.Output;
        end
        function type=getOutputDataTypeImpl(~),type='NirpTracer';end
        function size=getOutputSizeImpl(~),size=[1 1];end
        function flag=isOutputFixedSizeImpl(~),flag=true;end
        function flag=isOutputComplexImpl(~),flag=false;end
        function name=getInputNamesImpl(~),name='In';end
        function name=getOutputNamesImpl(~),name='Out';end
        function icon=getIconImpl(~),icon=sprintf('Non-ideal Vessel\nCout = Cin ∗ E');end
    end
    methods (Static,Access=protected)
        function mode=getSimulateUsingImpl(),mode='Interpreted execution';end
        function flag=showSimulateUsingImpl(),flag=false;end
    end
end
function value=fromBus(value),value.C=reshape(value.C,1,[]);value.E=reshape(value.E,1,[]);value.C0=reshape(value.C0,1,[]);value.Cseg=reshape(value.Cseg,1,[]);value.Cmm=reshape(value.Cmm,1,[]);end
function value=toBus(value),value.C=value.C(:);value.E=value.E(:);value.C0=value.C0(:);value.Cseg=value.Cseg(:);value.Cmm=value.Cmm(:);end
