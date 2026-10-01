classdef IdealReactorModesTest < matlab.unittest.TestCase
    % IdealReactorModesTest verifies specified thermal reactor modes.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 1, 2026. Last update: October 1, 2026 (T-102)
    % =========================================================================

    methods (Test)
        function cstrSpecifiedTemperature(testCase)
            [feed,rs] = IdealReactorModesTest.baseCase() ;
            reactor = IdealReactorModesTest.cstr('Specified T') ;
            reactor.specifiedT = 350 ; % K

            [product,reactor] = reactor.compute_output(feed,rs) ;

            testCase.verifyEqual(product.T,350,'AbsTol',1e-10) ;
            testCase.verifyEqual(1-product.molarFlow(1),0.5,'AbsTol',1e-10) ;
            testCase.verifyEqual(reactor.heatDuty,-20000,'RelTol',1e-10) ;
            testCase.verifyEqual(reactor.heatFlux,reactor.heatDuty,'AbsTol',1e-12) ;
        end

        function cstrSpecifiedFeedTemperatureMatchesIsothermal(testCase)
            [feed,rs] = IdealReactorModesTest.baseCase() ;
            isothermal = IdealReactorModesTest.cstr('Isothermal') ;
            [isothermalProduct,isothermal] = isothermal.compute_output(feed,rs) ;
            specified = IdealReactorModesTest.cstr('Specified T') ;
            specified.specifiedT = feed.T ;

            [specifiedProduct,specified] = specified.compute_output(feed,rs) ;

            testCase.verifyEqual(specifiedProduct.molarFlow, ...
                isothermalProduct.molarFlow,'AbsTol',1e-10) ;
            testCase.verifyEqual(specifiedProduct.T,isothermalProduct.T, ...
                'AbsTol',1e-10) ;
            testCase.verifyEqual(specified.heatDuty,isothermal.heatDuty, ...
                'AbsTol',1e-10) ;
        end

        function cstrSpecifiedHeat(testCase)
            [feed,rs] = IdealReactorModesTest.baseCase() ;
            adiabatic = IdealReactorModesTest.cstr('Adiabatic') ;
            adiabaticProduct = adiabatic.compute_output(feed,rs) ;
            reactor = IdealReactorModesTest.cstr('Specified Q') ;
            reactor.specifiedQ = 0 ; % W

            [zeroProduct,reactor] = reactor.compute_output(feed,rs) ;

            testCase.verifyEqual(zeroProduct.molarFlow,adiabaticProduct.molarFlow, ...
                'RelTol',1e-10) ;
            testCase.verifyEqual(zeroProduct.T,adiabaticProduct.T,'RelTol',1e-10) ;
            testCase.verifyEqual(zeroProduct.T,550,'RelTol',1e-8) ;
            testCase.verifyEqual(reactor.heatDuty,0,'AbsTol',1e-12) ;

            reactor.specifiedQ = -25000 ; % W
            [cooledProduct,reactor] = reactor.compute_output(feed,rs) ;
            testCase.verifyEqual(cooledProduct.T,300,'RelTol',1e-8) ;
            testCase.verifyEqual(reactor.heatDuty,-25000,'AbsTol',1e-12) ;
        end

        function cstrTemperatureGuessSelectsMultiplicity(testCase)
            [feed,rs] = IdealReactorModesTest.multiplicityCase() ;
            guesses = [300 345 450] ; % K
            expectedConversion = [0.0198400356 0.2999323545 0.9851403691] ;
            expectedTemperature = [300.97600534 342.98985317 445.77105537] ; % K

            for i = 1:numel(guesses)
                reactor = IdealReactorModesTest.cstr('Adiabatic') ;
                reactor.V = 18e-3 ; % m^3
                reactor.initialTemperatureGuess = guesses(i) ;
                product = reactor.compute_output(feed,rs) ;
                conversion = 1-product.molarFlow(1)/feed.molarFlow(1) ;
                testCase.verifyEqual(conversion,expectedConversion(i), ...
                    'RelTol',1e-6) ;
                testCase.verifyEqual(product.T,expectedTemperature(i), ...
                    'RelTol',1e-6) ;
            end

            % With an empty estimate, the historical feed-state estimate
            % converges to the low-temperature steady state.
            reactor = IdealReactorModesTest.cstr('Adiabatic') ;
            reactor.V = 18e-3 ; % m^3
            product = reactor.compute_output(feed,rs) ;
            defaultConversion = 1-product.molarFlow(1)/feed.molarFlow(1) ;
            testCase.verifyEqual(defaultConversion,expectedConversion(1),'RelTol',1e-6) ;
        end

        function pfrSpecifiedTemperature(testCase)
            [feed,rs] = IdealReactorModesTest.baseCase() ;
            reactor = IdealReactorModesTest.pfr('Specified T') ;
            reactor.specifiedT = 350 ; % K

            [product,reactor] = reactor.compute_output(feed,rs) ;
            conversion = 1-product.molarFlow(1) ;
            expectedConversion = 1-exp(-1) ;
            expectedDuty = 5000-50000*expectedConversion ; % W

            testCase.verifyEqual(product.T,350,'AbsTol',1e-9) ;
            testCase.verifyEqual(conversion,expectedConversion,'RelTol',1e-7) ;
            testCase.verifyEqual(reactor.heatDuty,expectedDuty,'RelTol',1e-6) ;
        end

        function pfrSpecifiedTemperatureGas(testCase)
            feed = Stream ;
            feed.phase = 'G' ;
            feed.molarFlow = [20e3*(0.1/60) 0 20e3*(0.1/60)/9] ; % mol/s
            feed.volumetricFlow = 0.1/60 ; % m^3/s
            feed.concentration = [] ;
            feed.T = 298.15 ; % K
            feed.P = 5.50849e7 ; % Pa
            rs = ReactionSys ;
            rs.stochiometricMatrix = [-2 1 0] ;
            rs.userDefinedKinetics = @(C,T) ...
                exp(14-7000/T)*1e-3/60*C(1)^2 ;
            rs.componentCp = [1 1 1] ; % J/(mol*K)
            rs.DHref = 0 ; % J/mol
            reactor = IdealReactorModesTest.pfr('Specified T') ;
            reactor.V = 1 ; % m^3
            reactor.diameterTubes = 0.1 ; % m
            reactor.specifiedT = 387 ; % K

            product = reactor.compute_output(feed,rs) ;
            conversion = (feed.molarFlow(1)-product.molarFlow(1)) / ...
                feed.molarFlow(1) ;

            testCase.verifyEqual(conversion,0.898224,'RelTol',1e-5) ;
            testCase.verifyEqual(product.T,387,'AbsTol',1e-9) ;
        end

        function pfrSpecifiedHeat(testCase)
            [feed,rs] = IdealReactorModesTest.baseCase() ;
            adiabatic = IdealReactorModesTest.pfr('Adiabatic') ;
            adiabaticProduct = adiabatic.compute_output(feed,rs) ;
            reactor = IdealReactorModesTest.pfr('Specified Q') ;
            reactor.specifiedQ = 0 ; % W

            [zeroProduct,reactor] = reactor.compute_output(feed,rs) ;
            testCase.verifyEqual(zeroProduct.molarFlow,adiabaticProduct.molarFlow, ...
                'RelTol',1e-8) ;
            testCase.verifyEqual(zeroProduct.T,adiabaticProduct.T,'RelTol',1e-8) ;
            testCase.verifyEqual(zeroProduct.T,616.0602794,'RelTol',1e-6) ;

            reactor.specifiedQ = 10000 ; % W
            [heatedProduct,reactor] = reactor.compute_output(feed,rs) ;
            extent = feed.molarFlow(1)-heatedProduct.molarFlow(1) ; % mol/s
            globalBalance = feed.molarFlow*rs.componentCp.UserValues' * ...
                (heatedProduct.T-feed.T) + rs.DHref*extent ;
            testCase.verifyEqual(globalBalance,reactor.specifiedQ,'RelTol',1e-6) ;
            testCase.verifyEqual(reactor.heatDuty,reactor.specifiedQ,'AbsTol',1e-12) ;
        end

        function pfrHeatProfileCoversAllTubes(testCase)
            [feed,rs] = IdealReactorModesTest.baseCase() ;
            oneTube = IdealReactorModesTest.pfr('Isothermal') ;
            [~,oneTube] = oneTube.compute_output(feed,rs) ;
            fourTubes = IdealReactorModesTest.pfr('Isothermal') ;
            fourTubes.nTubes = 4 ;

            [~,fourTubes] = fourTubes.compute_output(feed,rs) ;
            profileIntegral = trapz(linspace(0,fourTubes.L, ...
                numel(fourTubes.heatArray)),fourTubes.heatArray) ;

            testCase.verifyEqual(fourTubes.heatDuty,oneTube.heatDuty,'RelTol',1e-8) ;
            % heatArray is a 201-point sampled profile: its trapezoidal integral
            % matches the ODE-integrated duty within quadrature error (Claude, T-102 review).
            testCase.verifyEqual(profileIntegral,fourTubes.heatDuty,'RelTol',1e-4) ;
        end

        function missingSpecificationsRaiseErrors(testCase)
            [feed,rs] = IdealReactorModesTest.baseCase() ;
            reactors = {IdealReactorModesTest.cstr('Specified T'), ...
                IdealReactorModesTest.cstr('Specified Q'), ...
                IdealReactorModesTest.pfr('Specified T'), ...
                IdealReactorModesTest.pfr('Specified Q')} ;
            for i = 1:numel(reactors)
                testCase.verifyError(@() reactors{i}.compute_output(feed,rs), ...
                    'Reactor:missingSpecification') ;
            end
        end

        function computeCostUsesTotalHeatDuty(testCase)
            [feed,rs] = IdealReactorModesTest.baseCase() ;
            isothermal = IdealReactorModesTest.pfr('Isothermal') ;
            [isothermalProduct,isothermal] = isothermal.compute_output(feed,rs) ;
            specified = IdealReactorModesTest.pfr('Specified T') ;
            specified.specifiedT = 350 ; % K
            [specifiedProduct,specified] = specified.compute_output(feed,rs) ;

            isothermalCost = computeCost(isothermal,feed,isothermalProduct) ;
            specifiedCost = computeCost(specified,feed,specifiedProduct) ;

            % Both duties are cooling loads. The 5 kW inlet heating step
            % reduces the specified-temperature cooling OPEX by $50/year.
            testCase.verifyEqual(specifiedCost-isothermalCost,-50,'RelTol',1e-6) ;
        end
    end

    methods (Static, Access = private)
        function [feed,rs] = baseCase()
            feed = Stream ;
            feed.phase = 'L' ;
            feed.molarFlow = [1 0] ; % mol/s
            feed.molarFlow_Units = 'mol/s' ;
            feed.volumetricFlow = 1e-3 ; % m^3/s
            feed.volumetricFlow_Units = 'm^3/s' ;
            feed.concentration = [] ;
            feed.concentration_Units = 'mol/m^3' ;
            feed.T = 300 ; % K
            feed.P = 101325 ; % Pa
            feed.density = 1000 ; % kg/m^3
            feed.viscosity = 1e-3 ; % Pa*s

            rs = ReactionSys ;
            rs.stochiometricMatrix = [-1 1] ;
            rs.k0 = 0.01 ; % 1/s
            rs.Ea = 0 ; % J/mol
            rs.componentCp = [100 100] ; % J/(mol*K)
            rs.DHref = -50000 ; % J/mol
            rs.componentMw = [18 18] ; % g/mol
        end

        function [feed,rs] = multiplicityCase()
            feed = Stream ;
            feed.phase = 'L' ;
            feed.molarFlow = [0.18 0] ; % mol/s
            feed.volumetricFlow = 6e-5 ; % m^3/s
            feed.concentration = [] ;
            feed.T = 298 ; % K
            feed.P = 101325 ; % Pa
            rs = ReactionSys ;
            rs.stochiometricMatrix = [-1 1] ;
            rs.k0 = 4.48e6 ; % 1/s
            rs.Ea = 7500*8.314 ; % J/mol
            rs.componentCp = [1393.333333 1393.333333] ; % J/(mol*K)
            rs.DHref = -209000 ; % J/mol
        end

        function reactor = cstr(heatMode)
            reactor = CSTR ;
            reactor.V = 0.1 ; % m^3
            reactor.heatMode = heatMode ;
        end

        function reactor = pfr(heatMode)
            reactor = PFR ;
            reactor.V = 0.1 ; % m^3
            reactor.L = [] ;
            reactor.diameterTubes = 0.1 ; % m
            reactor.nTubes = 1 ;
            reactor.heatMode = heatMode ;
        end
    end
end
