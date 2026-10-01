classdef Product < matlab.System
    % Product exports a stream and its presentation values to nirpResults.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 2, 2026
    % =========================================================================
    properties (Nontunable)
        % Result field name; empty uses the Simulink block name.
        ResultName = ''
        % Optional package feed used as the conversion reference.
        ReferenceFeed = ''
        % Optional key component used to calculate conversion.
        KeyComponent = ''
        % Display unit for component molar flow.
        FlowUnit = 'mol/s'
        % Display unit for temperature.
        TemperatureUnit = 'K'
        % Display unit for pressure.
        PressureUnit = 'Pa'
        % Display unit for concentration.
        ConcentrationUnit = 'mol/m^3'
    end
    properties (Constant,Hidden)
        FlowUnitSet=matlab.system.StringSet(UnitConverterHelper.getUnits('MolarFlow'))
        TemperatureUnitSet=matlab.system.StringSet({'K',[char(176) 'C']})
        PressureUnitSet=matlab.system.StringSet(UnitConverterHelper.getUnits('Pressure'))
        ConcentrationUnitSet=matlab.system.StringSet(UnitConverterHelper.getUnits('Concentration'))
    end
    properties (Access=private)
        Pkg; RS; Name; Reference; KeyIndex=[]
    end
    methods (Access=protected)
        function setupImpl(obj)
            [~,obj.Pkg,obj.RS]=nirp.blocks.internal.modelPackage();
            obj.Name=char(string(obj.ResultName)); if isempty(strtrim(obj.Name)),obj.Name=get_param(gcb,'Name');end
            obj.Name=matlab.lang.makeValidName(obj.Name);
            if ~isempty(strtrim(char(string(obj.ReferenceFeed))))
                obj.Reference=nirp.pkg.feedStream(obj.Pkg,obj.ReferenceFeed);
                if isempty(strtrim(char(string(obj.KeyComponent))))
                    error('nirp:blocks:missingKeyComponent','KeyComponent is required when ReferenceFeed is set.');
                end
                names=nirp.pkg.componentNames(obj.Pkg); obj.KeyIndex=find(names==string(obj.KeyComponent),1);
                if isempty(obj.KeyIndex)
                    error('nirp:blocks:unknownComponent','Unknown key component "%s". Valid names: %s.',char(string(obj.KeyComponent)),strjoin(cellstr(names),', '));
                end
            end
        end
        function stepImpl(obj,in)
            nirp.stream.validate(in,obj.RS.nComponents);
            names=nirp.pkg.componentNames(obj.Pkg)';
            flow=UnitConverterHelper.convertFromSI('MolarFlow',in.F,char(obj.FlowUnit));
            if in.Q>0, concentration=nirp.stream.concentration(in); else, concentration=nan(size(in.F)); end
            concentration=UnitConverterHelper.convertFromSI('Concentration',concentration,char(obj.ConcentrationUnit));
            streamTable=table(names,flow,concentration,'VariableNames',{'Component','F','C'});
            item=struct(); item.streamSI=in; item.streamTable=streamTable;
            item.units=struct('F',char(obj.FlowUnit),'C',char(obj.ConcentrationUnit), ...
                'T',char(obj.TemperatureUnit),'P',char(obj.PressureUnit));
            item.T=UnitConverterHelper.convertFromSI('Temperature',in.T,char(obj.TemperatureUnit));
            item.P=UnitConverterHelper.convertFromSI('Pressure',in.P,char(obj.PressureUnit));
            phases={'Liquid','Gas'}; item.phase=phases{in.phase+1}; item.status=in.status; item.conversion=[];
            if ~isempty(obj.KeyIndex)
                initial=obj.Reference.F(obj.KeyIndex);
                if initial<=0,error('nirp:blocks:invalidReference','The reference feed key-component flow must be positive.');end
                item.conversion=(initial-in.F(obj.KeyIndex))/initial;
            end
            if evalin('base','exist(''nirpResults'',''var'')'),results=evalin('base','nirpResults');else,results=struct();end
            if ~isstruct(results),results=struct();end
            results.(obj.Name)=item; assignin('base','nirpResults',results);
        end
        function n=getNumOutputsImpl(~),n=0;end
        function name=getInputNamesImpl(~),name='Product';end
        function icon=getIconImpl(~),icon='Product';end
    end
    methods (Static,Access=protected)
        function groups=getPropertyGroupsImpl()
            groups=matlab.system.display.Section('Title','Product','PropertyList',{'ResultName','ReferenceFeed','KeyComponent','FlowUnit','TemperatureUnit','PressureUnit','ConcentrationUnit'});
        end
        function mode=getSimulateUsingImpl(),mode='Interpreted execution';end
        function flag=showSimulateUsingImpl(),flag=false;end
    end
end
