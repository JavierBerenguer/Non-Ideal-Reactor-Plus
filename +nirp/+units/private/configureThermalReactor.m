function reactor = configureThermalReactor(reactor,params)
%CONFIGURETHERMALREACTOR Apply common SI reactor parameters and defaults.
%   Defaults are Isothermal, bypassRatio 0, catalystDensity 1 kg/m^3,
%   catalystPorosity 0, U 0 W/(m^2*K), A 1 m^2, and no utility outlet.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 1, 2026
% =========================================================================

    heatMode = parameter(params,'heatMode','Isothermal',false) ;
    if ~(ischar(heatMode) || (isstring(heatMode) && isscalar(heatMode)))
        error('nirp:units:invalidParameter','heatMode must be text.') ;
    end
    reactor.heatMode = char(heatMode) ;
    reactor.bypassRatio = parameter(params,'bypassRatio',0,false) ;
    reactor.densityCatalyst = parameter(params,'catalystDensity',1,false) ;
    reactor.porosityCatalyst = parameter(params,'catalystPorosity',0,false) ;
    reactor.U = parameter(params,'U',0,false) ;
    reactor.heatTransferArea = parameter(params,'A',1,false) ;
    reactor.inletUtilityTemperature = parameter(params,'utilityTin',1,false) ;
    reactor.outletUtilityTemperature = parameter(params,'utilityTout',[],false) ;
    reactor.initialTemperatureGuess = parameter( ...
        params,'initialTemperatureGuess',[],false) ;
    if strcmp(reactor.heatMode,'Specified T')
        reactor.specifiedT = parameter(params,'specifiedT',[],true) ;
    elseif strcmp(reactor.heatMode,'Specified Q')
        reactor.specifiedQ = parameter(params,'specifiedQ',[],true) ;
    elseif strcmp(reactor.heatMode,'Other')
        reactor.U = parameter(params,'U',[],true) ;
        reactor.inletUtilityTemperature = parameter( ...
            params,'utilityTin',[],true) ;
        if isa(reactor,'CSTR')
            reactor.heatTransferArea = parameter(params,'A',[],true) ;
        end
    end

    scalarNames = {'bypassRatio','densityCatalyst','porosityCatalyst','U', ...
        'heatTransferArea','inletUtilityTemperature'} ;
    for i = 1:numel(scalarNames)
        value = reactor.(scalarNames{i}) ;
        if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ...
                ~isfinite(value)
            error('nirp:units:invalidParameter', ...
                '%s must be a finite real scalar.',scalarNames{i}) ;
        end
    end
    if reactor.bypassRatio < 0 || reactor.densityCatalyst <= 0 || ...
            reactor.porosityCatalyst < 0 || reactor.porosityCatalyst >= 1 || ...
            reactor.U < 0 || reactor.heatTransferArea <= 0 || ...
            reactor.inletUtilityTemperature <= 0
        error('nirp:units:invalidParameter', ...
            'Catalyst and bypass parameters are outside their valid ranges.') ;
    end
    optionalScalars = {'outletUtilityTemperature','initialTemperatureGuess'} ;
    for i = 1:numel(optionalScalars)
        value = reactor.(optionalScalars{i}) ;
        if ~isempty(value) && (~isnumeric(value) || ~isreal(value) || ...
                ~isscalar(value) || ~isfinite(value))
            error('nirp:units:invalidParameter', ...
                '%s must be empty or a finite real scalar.',optionalScalars{i}) ;
        end
    end
    if ~isempty(reactor.outletUtilityTemperature) && ...
            reactor.outletUtilityTemperature <= 0
        error('nirp:units:invalidParameter', ...
            'utilityTout must be positive in K.') ;
    end
    if strcmp(reactor.heatMode,'Specified T') && ...
            (~isnumeric(reactor.specifiedT) || ~isreal(reactor.specifiedT) || ...
            ~isscalar(reactor.specifiedT) || ~isfinite(reactor.specifiedT) || ...
            reactor.specifiedT <= 0)
        error('nirp:units:invalidParameter', ...
            'specifiedT must be a finite positive scalar in K.') ;
    elseif strcmp(reactor.heatMode,'Specified Q') && ...
            (~isnumeric(reactor.specifiedQ) || ~isreal(reactor.specifiedQ) || ...
            ~isscalar(reactor.specifiedQ) || ~isfinite(reactor.specifiedQ))
        error('nirp:units:invalidParameter', ...
            'specifiedQ must be a finite real scalar in W.') ;
    end
end
