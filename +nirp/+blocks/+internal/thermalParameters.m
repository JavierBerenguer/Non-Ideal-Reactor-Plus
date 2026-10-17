function params = thermalParameters(obj)
%THERMALPARAMETERS Convert reactor block thermal properties to SI.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 7, 2026
% =========================================================================

    params.heatMode = char(obj.HeatMode) ;
    % Flowsheet reactors have no internal bypass (T-131, D-057): a bypass
    % is drawn as a Splitter and a Mixer.
    params.bypassRatio = 0 ;
    params.catalystDensity = obj.CatalystDensity ;
    params.catalystPorosity = obj.CatalystPorosity ;
    params.specifiedT = convertTemperature(obj.SpecifiedT,obj.SpecifiedTUnit) ;
    params.specifiedQ = UnitConverterHelper.convertToSI( ...
        'Power',obj.SpecifiedQ,char(obj.SpecifiedQUnit)) ;
    params.U = UnitConverterHelper.convertToSI( ...
        'HeatTransferCoefficient',obj.U,char(obj.UUnit)) ;
    params.A = UnitConverterHelper.convertToSI('Area',obj.A,char(obj.AUnit)) ;
    params.utilityTin = convertTemperature(obj.UtilityTin,obj.UtilityTinUnit) ;
    if isempty(obj.UtilityTout) || any(isnan(obj.UtilityTout))
        params.utilityTout = [] ;
    else
        params.utilityTout = convertTemperature(obj.UtilityTout,obj.UtilityToutUnit) ;
    end
    if isempty(obj.InitialTGuess) || any(isnan(obj.InitialTGuess))
        params.initialTemperatureGuess = [] ;
    else
        params.initialTemperatureGuess = convertTemperature( ...
            obj.InitialTGuess,obj.InitialTGuessUnit) ;
    end
end

function value = convertTemperature(value,unit)
    value = UnitConverterHelper.convertToSI('Temperature',value,char(unit)) ;
end
