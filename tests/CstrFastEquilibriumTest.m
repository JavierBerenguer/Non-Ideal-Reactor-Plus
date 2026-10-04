classdef CstrFastEquilibriumTest < matlab.unittest.TestCase
    % CstrFastEquilibriumTest verifies the T-121 extent fallback.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 3, 2026. Last update: October 3, 2026
    % =========================================================================

    methods (Test)
        function problem33PackageIsIndependentOfTemperatureGuess(testCase)
            pkg = nirp.pkg.examples.problem33Gas() ;
            rs = nirp.pkg.toReactionSys(pkg) ;
            feed = nirp.pkg.feedStream(pkg,"F1") ;
            guesses = [NaN 600 700 770 800] ;
            for guess = guesses
                params = CstrFastEquilibriumTest.problem33Parameters(guess) ;
                [product,info] = nirp.units.cstr(params,feed,rs) ;
                testCase.verifyEqual(info.status,1,sprintf( ...
                    'Problem 33b failed from T0 = %g K.',guess)) ;
                testCase.verifyEqual(product.T,772.6110,'AbsTol',0.01) ;
                testCase.verifyEqual(CstrFastEquilibriumTest.conversion( ...
                    feed,product),0.869045,'AbsTol',1e-5) ;
            end
        end

        function problem33ClippedKineticsReachesSameState(testCase)
            pkg = nirp.pkg.examples.problem33Gas() ;
            rs = nirp.pkg.toReactionSys(pkg) ;
            gasConstant = 8.314 ;
            rs.userDefinedKinetics = @(C,T) ...
                1.45e7*exp(-70000/(gasConstant*T))*max(C(1),0)*max(C(2),0)- ...
                1.85e6*exp(-90000/(gasConstant*T))*max(C(3),0)^2 ;
            feed = nirp.pkg.feedStream(pkg,"F1") ;
            guesses = [NaN 600 700 770 800] ;
            for guess = guesses
                [product,info] = nirp.units.cstr( ...
                    CstrFastEquilibriumTest.problem33Parameters(guess),feed,rs) ;
                testCase.verifyEqual(info.status,1) ;
                testCase.verifyEqual(product.T,772.6110,'AbsTol',0.01) ;
                testCase.verifyEqual(CstrFastEquilibriumTest.conversion( ...
                    feed,product),0.869045,'AbsTol',1e-5) ;
            end
        end

        function liquidAnalyticalLimits(testCase)
            cases = [1e6 1e4; 1 0.5] ;
            for i = 1:size(cases,1)
                forward = cases(i,1) ; reverse = cases(i,2) ;
                [feed,rs] = CstrFastEquilibriumTest.liquidSystem( ...
                    forward,reverse,0) ;
                [product,info] = nirp.units.cstr(struct('V',1, ...
                    'heatMode','Isothermal'),feed,rs) ;
                expected = forward/(1+forward+reverse) ;
                testCase.verifyEqual(info.status,1) ;
                testCase.verifyEqual(CstrFastEquilibriumTest.conversion( ...
                    feed,product),expected,'RelTol',1e-9) ;
            end
        end

        function twoFastReactionsSatisfyBothExtentBalances(testCase)
            forward1 = 1e5 ; reverse1 = 1e3 ;
            forward2 = 5e5 ; reverse2 = 2e4 ;
            feed = nirp.stream.create([1;0;0],300,101325,0,1) ;
            rs = ReactionSys ;
            rs.stochiometricMatrix = [-1 1 0; 0 -1 1] ;
            rs.userDefinedKinetics = @(C,T) [ ...
                forward1*C(1)-reverse1*C(2), ...
                forward2*C(2)-reverse2*C(3)] ;
            rs.componentCp = [100 100 100] ;
            rs.DHref = [0 0] ; rs.Tref = 300 ;
            [product,info] = nirp.units.cstr(struct('V',1, ...
                'heatMode','Isothermal'),feed,rs) ;

            rateMatrix = [forward1 -reverse1 0; 0 forward2 -reverse2] ;
            expected = (eye(3)-rs.stochiometricMatrix'*rateMatrix)\feed.F ;
            extent = rs.stochiometricMatrix'\(product.F-feed.F) ;
            outletRs = rs.computeRate(nirp.stream.concentration(product),product.T) ;
            scaledResidual = norm(extent-outletRs.r_i(:),inf)/max(feed.F) ;
            testCase.verifyEqual(info.status,1) ;
            testCase.verifyEqual(product.F,expected,'RelTol',1e-9, ...
                'AbsTol',1e-12) ;
            testCase.verifyLessThanOrEqual(scaledResidual,1e-9) ;
        end

        function bypassPreservesStoichiometryAndNonnegativeFlow(testCase)
            [feed,rs] = CstrFastEquilibriumTest.liquidSystem(1e6,1e4,0) ;
            reactor = CSTR ; reactor.V = 1 ; reactor.heatMode = 'Isothermal' ;
            reactor.bypassRatio = 0.5 ;
            product = reactor.compute_output(nirp.stream.toStream(feed),rs) ;
            reactedOutlet = product.molarFlow- ...
                feed.F'*reactor.bypassRatio/(1+reactor.bypassRatio) ;
            extent = rs.stochiometricMatrix'\(reactedOutlet'- ...
                feed.F/(1+reactor.bypassRatio)) ;
            testCase.verifyGreaterThanOrEqual(min(product.molarFlow),0) ;
            testCase.verifyEqual(reactedOutlet',feed.F/(1+reactor.bypassRatio)+ ...
                rs.stochiometricMatrix'*extent,'AbsTol',1e-12) ;
        end

        function fastAdiabaticLiquidClosesEnergyBalance(testCase)
            [feed,rs] = CstrFastEquilibriumTest.liquidSystem(1e6,1e4,-5000) ;
            [product,info] = nirp.units.cstr(struct('V',1, ...
                'heatMode','Adiabatic','initialTemperatureGuess',340),feed,rs) ;
            extent = rs.stochiometricMatrix'\(product.F-feed.F) ;
            expectedTemperature = feed.T-extent*rs.DHref/100 ;
            testCase.verifyEqual(info.status,1) ;
            testCase.verifyEqual(product.T,expectedTemperature,'RelTol',1e-9) ;
            testCase.verifyGreaterThanOrEqual(min(product.F),0) ;
        end

        function fastLiquidSupportsEveryThermalMode(testCase)
            [feed,rs] = CstrFastEquilibriumTest.liquidSystem(1e6,1e4,0) ;
            cases = { ...
                struct('V',1,'heatMode','Isothermal'), ...
                struct('V',1,'heatMode','Specified T','specifiedT',320), ...
                struct('V',1,'heatMode','Adiabatic','initialTemperatureGuess',340), ...
                struct('V',1,'heatMode','Other','U',10,'A',2, ...
                    'utilityTin',300,'initialTemperatureGuess',340), ...
                struct('V',1,'heatMode','Specified Q','specifiedQ',0, ...
                    'initialTemperatureGuess',340)} ;
            expectedTemperatures = [300 320 300 300 300] ;
            for i = 1:numel(cases)
                [product,info] = nirp.units.cstr(cases{i},feed,rs) ;
                testCase.verifyEqual(info.status,1,cases{i}.heatMode) ;
                testCase.verifyEqual(product.T,expectedTemperatures(i), ...
                    'AbsTol',1e-8) ;
                testCase.verifyGreaterThanOrEqual(min(product.F),0) ;
            end
        end
    end

    methods (Static, Access = private)
        function params = problem33Parameters(guess)
            params = struct('V',1.6,'heatMode','Other','U',10,'A',2, ...
                'utilityTin',290.15) ;
            if ~isnan(guess), params.initialTemperatureGuess = guess ; end
        end

        function [feed,rs] = liquidSystem(forward,reverse,reactionHeat)
            feed = nirp.stream.create([1;0],300,101325,0,1) ;
            rs = ReactionSys ; rs.stochiometricMatrix = [-1 1] ;
            rs.userDefinedKinetics = @(C,T) forward*C(1)-reverse*C(2) ;
            rs.componentCp = [100 100] ; rs.DHref = reactionHeat ;
            rs.Tref = 300 ;
        end

        function value = conversion(feed,product)
            value = (feed.F(1)-product.F(1))/feed.F(1) ;
        end
    end
end
