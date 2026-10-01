classdef Flowsheet < matlab.System
    % Flowsheet validates the common package for a Simulink flowsheet.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 2, 2026
    % =========================================================================

    properties (Access = private)
        PackageName = ''
    end

    methods (Access = protected)
        function setupImpl(obj)
            [~,pkg] = nirp.blocks.internal.modelPackage() ;
            obj.PackageName = char(string(pkg.meta.name)) ;
        end

        function stepImpl(~)
        end

        function n = getNumInputsImpl(~), n = 0 ; end
        function n = getNumOutputsImpl(~), n = 0 ; end
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
