classdef Vessel < matlab.System
    % Vessel convolves tracer data and caches stationary reactive limits.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 22, 2026. Last update: October 25, 2026
    % =========================================================================
    properties (Nontunable)
        Dt=0.1; TFinal=10; Origin='Model'; Model='CSTR'; ResidenceBasis='Tau'
        Tau=1; Volume=1; N=2; Pe=10; Boundary='open'
        DataTime=[0 10]; DataE=[1 0]; SessionFile=''
    end
    properties (Access=private),Output;EvaluationCount=uint32(0);end
    methods (Access=protected)
        function setupImpl(obj)
            nirp.tracer.grid(obj.Dt,obj.TFinal);nirp.tracerflowsheet.validateSeparation(bdroot(gcb));
            obj.Output=[];obj.EvaluationCount=uint32(0);publishCount(gcb,obj.EvaluationCount);
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
            if input.reactiveMode>0
                config=nirp.tracerflowsheet.reactionConfiguration(gcb);
                [out,obj.EvaluationCount]=evaluateReactive(out,input,E,grid,config,obj.EvaluationCount);
                out.rtdTruncated=input.rtdTruncated||grid.dt*sum(E)<1-1e-6;
            end
            publishCount(gcb,obj.EvaluationCount);obj.Output=toBus(out);out=obj.Output;
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
function [out,count]=evaluateReactive(out,input,E,grid,config,count)
mode=double(input.reactiveMode);
if mode~=double(config.mode),error('nirp:tracerblocks:ReactiveModeMismatch','Stream and flowsheet micromixing modes do not match.'),end
if mode==1
    result=nirp.tracer.reactiveVessel(grid,E,config.RS,input.Cseg,config.temperature,config.keyIndex);count=count+1;out.Cseg=result.Cseg;
elseif mode==2
    result=nirp.tracer.reactiveVessel(grid,E,config.RS,input.Cmm,config.temperature,config.keyIndex);count=count+1;out.Cmm=result.Cmm;
elseif mode==3
    if isequal(input.Cseg,input.Cmm)
        result=nirp.tracer.reactiveVessel(grid,E,config.RS,input.Cseg,config.temperature,config.keyIndex);count=count+1;out.Cseg=result.Cseg;out.Cmm=result.Cmm;
    else
        seg=nirp.tracer.reactiveVessel(grid,E,config.RS,input.Cseg,config.temperature,config.keyIndex);count=count+1;
        mm=nirp.tracer.reactiveVessel(grid,E,config.RS,input.Cmm,config.temperature,config.keyIndex);count=count+1;
        out.Cseg=seg.Cseg;out.Cmm=mm.Cmm;
    end
end
end
function publishCount(block,count)
counts=struct();if evalin('base','exist(''nirpTracerReactiveCalls'',''var'')'),counts=evalin('base','nirpTracerReactiveCalls');end
key=matlab.lang.makeValidName([bdroot(block) '_' get_param(block,'Name')]);counts.(key)=double(count);assignin('base','nirpTracerReactiveCalls',counts);
end
function value=fromBus(value),value.C=reshape(value.C,1,[]);value.E=reshape(value.E,1,[]);value.C0=reshape(value.C0,1,[]);value.Cseg=reshape(value.Cseg,1,[]);value.Cmm=reshape(value.Cmm,1,[]);end
function value=toBus(value),value.C=value.C(:);value.E=value.E(:);value.C0=value.C0(:);value.Cseg=value.Cseg(:);value.Cmm=value.Cmm(:);end
