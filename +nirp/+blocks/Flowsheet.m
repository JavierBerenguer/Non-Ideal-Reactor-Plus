classdef Flowsheet < matlab.System
    % Flowsheet reports whether every iterative block has converged.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 2, 2026
    % =========================================================================

    properties (Access = private)
        PackageName = ''
        Consecutive = 0
    end

    methods (Access = protected)
        function setupImpl(obj)
            [~,pkg] = nirp.blocks.internal.modelPackage() ;
            obj.PackageName = char(string(pkg.meta.name)) ;
            obj.Consecutive = 0 ;
        end

        function converged = stepImpl(obj)
            if nirp.flowsheet.registry('allConverged',bdroot(gcb))
                obj.Consecutive = obj.Consecutive+1 ;
            else
                obj.Consecutive = 0 ;
            end
            % One extra full iteration lets sinks publish the converged state
            % before Stop Simulation terminates the major time step.
            converged = double(obj.Consecutive >= 2) ;
        end

        function n = getNumInputsImpl(~), n = 0 ; end
        function n = getNumOutputsImpl(~), n = 1 ; end
        function type = getOutputDataTypeImpl(~), type = 'double' ; end
        function size = getOutputSizeImpl(~), size = [1 1] ; end
        function flag = isOutputFixedSizeImpl(~), flag = true ; end
        function flag = isOutputComplexImpl(~), flag = false ; end
        function name = getOutputNamesImpl(~), name = 'Converged' ; end
        function icon = getIconImpl(obj)
            if isempty(obj.PackageName), icon = 'Flowsheet' ;
            else, icon = sprintf('Flowsheet\n%s',obj.PackageName) ; end
        end
        function sts = getSampleTimeImpl(obj)
            sts = createSampleTime(obj,'Type','Discrete','SampleTime',1) ;
        end
    end

    methods (Static, Access = protected)
        function mode = getSimulateUsingImpl(), mode = 'Interpreted execution' ; end
        function flag = showSimulateUsingImpl(), flag = false ; end
    end
end
