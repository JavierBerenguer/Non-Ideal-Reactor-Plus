classdef EnthalpyModelTest < matlab.unittest.TestCase
    % EnthalpyModelTest verifies the common temperature-dependent enthalpy model.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 1, 2026. Last update: October 1, 2026 (T-103)
    % =========================================================================

    methods (Test)
        function sensibleEnthalpy(testCase)
            rs = EnthalpyModelTest.singleComponentSystem() ;

            forward = rs.compute_SensibleEnthalpy(300,400,101325) ;
            reverse = rs.compute_SensibleEnthalpy(400,300,101325) ;
            zero = rs.compute_SensibleEnthalpy(350,350,101325) ;

            testCase.verifyEqual(forward,5500,'RelTol',1e-12) ;
            testCase.verifyEqual(reverse,-5500,'RelTol',1e-12) ;
            testCase.verifyEqual(zero,0,'AbsTol',0) ;

            rs.componentCp = 100 ; % J/(mol*K)
            testCase.verifyEqual(rs.compute_SensibleEnthalpy(300,400,101325), ...
                10000,'AbsTol',0) ;
        end

        function reactionEnthalpy(testCase)
            rs = ReactionSys ;
            rs.stochiometricMatrix = [-1 1] ;
            rs.componentCp = struct('option','Cp = f(T)', ...
                'Function',{{@(T) 20+0.1*T,@(T) 30+0.1*T}}) ;
            rs.DHref = -50000 ; % J/mol
            rs.Tref = 298.15 ; % K

            value = rs.compute_ReactionEnthalpy(400,101325) ;

            testCase.verifyEqual(value,-48981.5,'RelTol',1e-12) ;
        end

        function adiabaticMixing(testCase)
            rs = EnthalpyModelTest.singleComponentSystem() ;
            flows = [1 ; 1] ; % mol/s
            temperatures = [300 ; 400] ; % K

            [temperature,ok] = Reactor.mixTemperature( ...
                rs,flows,temperatures,101325) ;
            expected = (-40+sqrt(12200))/0.2 ;

            testCase.verifyTrue(ok) ;
            testCase.verifyEqual(temperature,expected,'RelTol',1e-9) ;

            rs.componentCp = 100 ; % J/(mol*K)
            [constantTemperature,ok] = Reactor.mixTemperature( ...
                rs,[1 ; 3],temperatures,101325) ;
            testCase.verifyTrue(ok) ;
            testCase.verifyEqual(constantTemperature,375,'AbsTol',0) ;

            [emptyTemperature,ok] = Reactor.mixTemperature( ...
                rs,[0 ; 0],temperatures,101325) ;
            testCase.verifyFalse(ok) ;
            testCase.verifyEqual(emptyTemperature,temperatures(1),'AbsTol',0) ;
        end

        function cstrAdiabaticEnthalpyConservation(testCase)
            [feed,rs] = EnthalpyModelTest.reactorCase() ;
            reactor = EnthalpyModelTest.cstr('Adiabatic') ;

            product = reactor.compute_output(feed,rs) ;
            [residual,scale] = EnthalpyModelTest.enthalpyResidual( ...
                feed,product,rs) ;

            testCase.verifyLessThanOrEqual(abs(residual),1e-8*scale) ;
        end

        function pfrAdiabaticEnthalpyConservation(testCase)
            [feed,rs] = EnthalpyModelTest.reactorCase() ;
            reactor = EnthalpyModelTest.pfr('Adiabatic') ;

            product = reactor.compute_output(feed,rs) ;
            [residual,scale] = EnthalpyModelTest.enthalpyResidual( ...
                feed,product,rs) ;

            testCase.verifyLessThanOrEqual(abs(residual),1e-7*scale) ;
        end

        function cstrBypassUsesEnthalpyMixing(testCase)
            [feed,rs] = EnthalpyModelTest.reactorCase() ;
            reactor = EnthalpyModelTest.cstr('Adiabatic') ;
            reactor.bypassRatio = 0.4 ;

            product = reactor.compute_output(feed,rs) ;
            reactorFeed = feed ;
            reactorFeed.molarFlow = feed.molarFlow/(1+reactor.bypassRatio) ;
            noBypass = reactor ;
            noBypass.bypassRatio = 0 ;
            reactorProduct = noBypass.compute_output(reactorFeed,rs) ;
            bypassFlow = feed.molarFlow*reactor.bypassRatio / ...
                (1+reactor.bypassRatio) ;
            expectedTemperature = Reactor.mixTemperature(rs, ...
                [reactorProduct.molarFlow ; bypassFlow], ...
                [reactorProduct.T ; feed.T],feed.P) ;
            [residual,scale] = EnthalpyModelTest.enthalpyResidual( ...
                feed,product,rs) ;

            testCase.verifyEqual(product.T,expectedTemperature,'RelTol',1e-9) ;
            testCase.verifyLessThanOrEqual(abs(residual),1e-8*scale) ;
        end

        function parallelReactorsUseEnthalpyMixing(testCase)
            [feed,rs] = EnthalpyModelTest.reactorCase() ;
            lowTemperature = EnthalpyModelTest.cstr('Specified T') ;
            lowTemperature.specifiedT = 320 ; % K
            highTemperature = EnthalpyModelTest.cstr('Specified T') ;
            highTemperature.specifiedT = 380 ; % K
            association = Reactor ;

            [product,sequence] = association.compute_parallel( ...
                feed,rs,{lowTemperature highTemperature}) ;
            splitFeed = EnthalpyModelTest.splitFeed(feed,0.5) ;
            lowProduct = sequence{1}.compute_output(splitFeed,rs) ;
            highProduct = sequence{2}.compute_output(splitFeed,rs) ;
            outletFlows = [lowProduct.molarFlow ; highProduct.molarFlow] ;
            expectedTemperature = Reactor.mixTemperature(rs,outletFlows, ...
                [320 ; 380],product.P) ;
            outletFlow = sum(outletFlows,1) ;
            inletEnthalpy = 0 ;
            outletTemperatures = [320 380] ;
            for i = 1:2
                inletEnthalpy = inletEnthalpy+outletFlows(i,:) * ...
                    EnthalpyModelTest.independentSensibleEnthalpy( ...
                    rs,rs.Tref,outletTemperatures(i),product.P)' ;
            end
            enthalpyEquation = @(T) outletFlow * ...
                EnthalpyModelTest.independentSensibleEnthalpy( ...
                rs,rs.Tref,T,product.P)' - inletEnthalpy ;
            independentTemperature = fzero(enthalpyEquation,[320 380]) ;

            testCase.verifyEqual(product.T,expectedTemperature,'RelTol',1e-9) ;
            testCase.verifyEqual(product.T,independentTemperature,'RelTol',1e-9) ;
        end
    end

    methods (Static, Access = private)
        function rs = singleComponentSystem()
            rs = ReactionSys ;
            rs.stochiometricMatrix = -1 ;
            rs.componentCp = struct('option','Cp = f(T)', ...
                'Function',{{@(T) 20+0.1*T}}) ;
        end

        function [feed,rs] = reactorCase()
            feed = Stream ;
            feed.phase = 'L' ;
            feed.molarFlow = [1 0] ; % mol/s
            feed.volumetricFlow = 1e-3 ; % m^3/s
            feed.concentration = [] ;
            feed.T = 300 ; % K
            feed.P = 101325 ; % Pa
            feed.density = 1000 ; % kg/m^3
            feed.viscosity = 1e-3 ; % Pa*s

            rs = ReactionSys ;
            rs.stochiometricMatrix = [-1 1] ;
            rs.k0 = 0.01 ; % 1/s
            rs.Ea = 5000 ; % J/mol
            rs.componentCp = struct('option','Cp = f(T)', ...
                'Function',{{@(T) 20+0.1*T,@(T) 20+0.1*T}}) ;
            rs.DHref = -50000 ; % J/mol
            rs.Tref = 298.15 ; % K
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

        function feed = splitFeed(feed,fraction)
            feed.molarFlow = feed.molarFlow*fraction ;
            feed.volumetricFlow = feed.volumetricFlow*fraction ;
        end

        function [residual,scale] = enthalpyResidual(feed,product,rs)
            inletEnthalpy = feed.molarFlow * ...
                EnthalpyModelTest.componentEnthalpy(rs,feed.T,feed.P)' ;
            outletEnthalpy = product.molarFlow * ...
                EnthalpyModelTest.componentEnthalpy(rs,product.T,product.P)' ;
            residual = outletEnthalpy-inletEnthalpy ;
            extent = product.molarFlow(2)-feed.molarFlow(2) ;
            scale = abs(rs.DHref*extent) ;
        end

        function H = componentEnthalpy(rs,T,P)
            H = EnthalpyModelTest.independentSensibleEnthalpy( ...
                rs,rs.Tref,T,P) ;
            H(2) = H(2)+rs.DHref ;
        end

        function S = independentSensibleEnthalpy(rs,T1,T2,P)
            S = zeros(1,rs.nComponents) ;
            for i = 1:rs.nComponents
                if strcmp(rs.componentCp.option,'Cp = f(T)')
                    cp = rs.componentCp.Function{i} ;
                    S(i) = integral(cp,T1,T2,'RelTol',1e-13,'AbsTol',1e-13) ;
                elseif strcmp(rs.componentCp.option,'Cp = f(T,P)')
                    cp = rs.componentCp.FunctionWithP{i} ;
                    S(i) = integral(@(T) cp(T,P),T1,T2, ...
                        'RelTol',1e-13,'AbsTol',1e-13) ;
                else
                    values = rs.compute_HeatCapacity(T1,P) ;
                    S(i) = values(i)*(T2-T1) ;
                end
            end
        end
    end
end
