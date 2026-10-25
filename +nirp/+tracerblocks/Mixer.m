classdef Mixer < matlab.System
    % Mixer flow-weights NirpTracer inputs through nirp.tracer.mixer.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 22, 2026. Last update: October 25, 2026
    % =========================================================================
    properties (Nontunable),Dt=0.1;TFinal=10;NumInputs=2;end
    methods (Access=protected)
        function setupImpl(obj),if obj.NumInputs<2||obj.NumInputs~=fix(obj.NumInputs),error('nirp:tracerblocks:InvalidPorts','Mixer requires at least two inputs.');end;nirp.tracerflowsheet.validateSeparation(bdroot(gcb));end
        function out=stepImpl(obj,varargin)
            inputs=cell(size(varargin));for k=1:numel(varargin),inputs{k}=fromBus(varargin{k});end
            out=nirp.tracer.mixer(nirp.tracer.grid(obj.Dt,obj.TFinal),inputs);out=toBus(out);
        end
        function n=getNumInputsImpl(obj),n=obj.NumInputs;end
        function type=getOutputDataTypeImpl(~),type='NirpTracer';end
        function size=getOutputSizeImpl(~),size=[1 1];end
        function flag=isOutputFixedSizeImpl(~),flag=true;end
        function flag=isOutputComplexImpl(~),flag=false;end
        function varargout=getInputNamesImpl(obj),for k=1:obj.NumInputs,varargout{k}=sprintf('In %d',k);end,end
        function name=getOutputNamesImpl(~),name='Out';end
        function icon=getIconImpl(~),icon=sprintf('Tracer Mixer\nflow weighted');end
    end
    methods (Static,Access=protected)
        function mode=getSimulateUsingImpl(),mode='Interpreted execution';end
        function flag=showSimulateUsingImpl(),flag=false;end
    end
end
function value=fromBus(value),value.C=reshape(value.C,1,[]);value.E=reshape(value.E,1,[]);value.C0=reshape(value.C0,1,[]);value.Cseg=reshape(value.Cseg,1,[]);value.Cmm=reshape(value.Cmm,1,[]);end
function value=toBus(value),value.C=value.C(:);value.E=value.E(:);value.C0=value.C0(:);value.Cseg=value.Cseg(:);value.Cmm=value.Cmm(:);end
