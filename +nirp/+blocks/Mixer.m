classdef Mixer < matlab.System
    % Mixer combines two to six SI streams through nirp.units.mixer.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 2, 2026
    % =========================================================================
    properties (Nontunable)
        % Number of inlet streams (2 to 6).
        NumInputs = 2
    end
    properties (Access=private)
        RS; LastInputs; LastOutput; HasCache=false; CalculationCount=0; Model; Block
    end
    methods (Access=protected)
        function setupImpl(obj)
            if obj.NumInputs<2 || obj.NumInputs>6 || obj.NumInputs~=fix(obj.NumInputs)
                error('nirp:blocks:invalidPorts','NumInputs must be an integer from 2 to 6.');
            end
            [obj.Model,~,obj.RS]=nirp.blocks.internal.modelPackage(); obj.Block=get_param(gcb,'Name');
            obj.HasCache=false; obj.CalculationCount=0;
        end
        function out=stepImpl(obj,varargin)
            for i=1:numel(varargin), nirp.stream.validate(varargin{i},obj.RS.nComponents); end
            if obj.HasCache && isequaln(varargin,obj.LastInputs), out=obj.LastOutput;
            else
                out=nirp.units.mixer([],varargin,obj.RS); obj.LastInputs=varargin; obj.LastOutput=out;
                obj.HasCache=true; obj.CalculationCount=obj.CalculationCount+1;
                nirp.blocks.internal.diagnostic(obj.Model,obj.Block,obj.CalculationCount,out);
            end
        end
        function n=getNumInputsImpl(obj),n=obj.NumInputs;end
        function type=getOutputDataTypeImpl(~),type='NirpStream';end
        function size=getOutputSizeImpl(~),size=[1 1];end
        function flag=isOutputFixedSizeImpl(~),flag=true;end
        function flag=isOutputComplexImpl(~),flag=false;end
        function varargout=getInputNamesImpl(obj),for i=1:obj.NumInputs,varargout{i}=sprintf('Feed %d',i);end,end
        function name=getOutputNamesImpl(~),name='Product';end
        function icon=getIconImpl(~),icon='Mixer';end
    end
    methods (Static,Access=protected)
        function groups=getPropertyGroupsImpl(),groups=matlab.system.display.Section('Title','Mixer','PropertyList',{'NumInputs'});end
        function mode=getSimulateUsingImpl(),mode='Interpreted execution';end
        function flag=showSimulateUsingImpl(),flag=false;end
    end
end
