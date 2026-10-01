classdef IdealReactorCoreTest < matlab.unittest.TestCase
    % IdealReactorCoreTest verifies corrected ideal-reactor balances.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 1, 2026. Last update: October 1, 2026
    % =========================================================================

    methods (Test)
        function cstrAdiabaticExothermicAndEndothermic(testCase)
            [feed,rs] = IdealReactorCoreTest.baseCase() ;
            reactor = IdealReactorCoreTest.cstr('Adiabatic') ;

            [product,solvedReactor] = reactor.compute_output(feed,rs) ;
            testCase.verifyEqual(product.molarFlow(1),0.5,'RelTol',1e-6) ;
            testCase.verifyEqual(product.T,550,'RelTol',1e-6) ;
            testCase.verifyEqual(solvedReactor.heatFlux,0,'AbsTol',1e-12) ;

            rs.DHref = 50000 ; % J/mol
            product = reactor.compute_output(feed,rs) ;
            testCase.verifyEqual(product.molarFlow(1),0.5,'RelTol',1e-6) ;
            testCase.verifyEqual(product.T,50,'RelTol',1e-6) ;
        end

        function cstrVariableTemperatureKineticsClosesBalances(testCase)
            [feed,rs] = IdealReactorCoreTest.baseCase() ;
            rs.k0 = 1e3 ; % 1/s
            rs.Ea = 40000 ; % J/mol
            reactor = IdealReactorCoreTest.cstr('Adiabatic') ;

            product = reactor.compute_output(feed,rs) ;
            rsAtOutlet = rs.computeRate(product.concentration,product.T) ;
            rate = rsAtOutlet.r_i ; % mol/(m^3*s)
            massResidual = feed.molarFlow-product.molarFlow + ...
                rate*rs.stochiometricMatrix*reactor.V ;
            energyResidual = feed.molarFlow*rs.componentCp.UserValues' * ...
                (product.T-feed.T) + reactor.V*rate*rs.DHref' ;

            testCase.verifyLessThanOrEqual(norm(massResidual,inf),1e-8) ;
            energyScale = max([abs(feed.molarFlow*rs.componentCp.UserValues' * ...
                (product.T-feed.T)),abs(reactor.V*rate*rs.DHref'),1]) ;
            testCase.verifyLessThanOrEqual(abs(energyResidual)/energyScale,1e-8) ;
        end

        function cstrIsothermalHeatAndLiquidRegression(testCase)
            [feed,rs] = IdealReactorCoreTest.baseCase() ;
            reactor = IdealReactorCoreTest.cstr('Isothermal') ;

            [product,reactor] = reactor.compute_output(feed,rs) ;

            testCase.verifyEqual(product.molarFlow(1),0.5,'AbsTol',1e-10) ;
            testCase.verifyEqual(reactor.heatFlux,-25000,'RelTol',1e-10) ;
        end

        function cstrOtherUsesConstantUtilityTemperature(testCase)
            [feed,rs] = IdealReactorCoreTest.baseCase() ;
            reactor = IdealReactorCoreTest.cstr('Other') ;
            reactor.U = 1000 ; % W/(m^2*K)
            reactor.heatTransferArea = 1 ; % m^2
            reactor.inletUtilityTemperature = 290 ; % K
            reactor.outletUtilityTemperature = [] ;

            [product,reactor] = reactor.compute_output(feed,rs) ;
            [massResidual,energyResidual] = ...
                IdealReactorCoreTest.cstrResiduals(product,feed,rs,reactor) ;
            expectedQ = 1000*(290-product.T) ; % W

            testCase.verifyLessThanOrEqual(norm(massResidual,inf),1e-8) ;
            testCase.verifyLessThanOrEqual(abs(energyResidual-expectedQ),1e-6) ;
            testCase.verifyEqual(reactor.heatFlux,expectedQ,'RelTol',1e-10) ;
        end

        function cstrOtherUsesLogMeanTemperatureDifference(testCase)
            [feed,rs] = IdealReactorCoreTest.baseCase() ;
            reactor = IdealReactorCoreTest.cstr('Other') ;
            reactor.U = 1000 ; % W/(m^2*K)
            reactor.heatTransferArea = 1 ; % m^2
            reactor.inletUtilityTemperature = 290 ; % K
            reactor.outletUtilityTemperature = 280 ; % K

            [product,reactor] = reactor.compute_output(feed,rs) ;
            deltaTIn = reactor.inletUtilityTemperature-product.T ;
            deltaTOut = reactor.outletUtilityTemperature-product.T ;
            logMean = (deltaTIn-deltaTOut)/log(deltaTIn/deltaTOut) ;
            expectedQ = reactor.U*reactor.heatTransferArea*logMean ;
            [~,energyResidual] = ...
                IdealReactorCoreTest.cstrResiduals(product,feed,rs,reactor) ;

            testCase.verifyEqual(reactor.heatFlux,expectedQ,'RelTol',1e-10) ;
            testCase.verifyLessThanOrEqual(abs(energyResidual-expectedQ),1e-6) ;

            reactor.outletUtilityTemperature = ...
                reactor.inletUtilityTemperature ;
            [equalDifferenceProduct,reactor] = reactor.compute_output(feed,rs) ;
            arithmeticMeanQ = reactor.U*reactor.heatTransferArea * ...
                (reactor.inletUtilityTemperature-equalDifferenceProduct.T) ;
            testCase.verifyEqual(reactor.heatFlux,arithmeticMeanQ,'RelTol',1e-10) ;
        end

        function cstrBypassUsesReactorInletFlow(testCase)
            [feed,rs] = IdealReactorCoreTest.baseCase() ;
            reactor = IdealReactorCoreTest.cstr('Adiabatic') ;
            reactor.bypassRatio = 1 ;

            product = reactor.compute_output(feed,rs) ;

            testCase.verifyEqual(product.molarFlow,[0.75 0.25],'AbsTol',1e-9) ;
            testCase.verifyEqual(product.T,425,'RelTol',1e-8) ;
        end

        function cstrSupportsTwoReactions(testCase)
            [feed,~] = IdealReactorCoreTest.baseCase() ;
            feed.molarFlow = [1 0 0] ; % mol/s
            rs = ReactionSys ;
            rs.stochiometricMatrix = [-1 1 0; -1 0 1] ;
            rs.userDefinedKinetics = @(C,T) [0.004*C(1),0.006*C(1)] ;
            rs.componentCp = [100 100 100] ; % J/(mol*K)
            rs.DHref = [-50000 -50000] ; % J/mol
            reactor = IdealReactorCoreTest.cstr('Isothermal') ;

            product = reactor.compute_output(feed,rs) ;

            testCase.verifyEqual(product.molarFlow,[0.5 0.2 0.3], ...
                'AbsTol',1e-9) ;
        end

        function pfrAdiabaticAndIsothermalAnalyticalResults(testCase)
            [feed,rs] = IdealReactorCoreTest.baseCase() ;
            reactor = IdealReactorCoreTest.pfr('Adiabatic') ;

            product = reactor.compute_output(feed,rs) ;
            conversion = 1-exp(-1) ;
            testCase.verifyEqual(1-product.molarFlow(1),conversion,'RelTol',1e-6) ;
            testCase.verifyEqual(product.T,300+500*conversion,'RelTol',1e-6) ;

            reactor = IdealReactorCoreTest.pfr('Isothermal') ;
            [product,reactor] = reactor.compute_output(feed,rs) ;
            testCase.verifyEqual(product.molarFlow(1),exp(-1),'RelTol',1e-7) ;
            testCase.verifySize(reactor.heatArray,[201 1]) ;
            expectedHeat = rs.DHref*(1-exp(-1)) ; % W
            heat = trapz(linspace(0,reactor.L,numel(reactor.heatArray)), ...
                reactor.heatArray) ;
            testCase.verifyEqual(heat,expectedHeat,'RelTol',2e-5) ;
        end

        function pfrVolumeOnlyMatchesEquivalentLength(testCase)
            [feed,rs] = IdealReactorCoreTest.baseCase() ;
            volumeOnly = IdealReactorCoreTest.pfr('Isothermal') ;
            equivalentLength = volumeOnly.V / ...
                (volumeOnly.nTubes*pi*(volumeOnly.diameterTubes/2)^2) ;
            specifiedLength = volumeOnly ;
            specifiedLength.L = equivalentLength ;

            [volumeProduct,volumeOnly] = volumeOnly.compute_output(feed,rs) ;
            lengthProduct = specifiedLength.compute_output(feed,rs) ;

            testCase.verifyEqual(volumeOnly.L,equivalentLength,'RelTol',1e-12) ;
            testCase.verifyEqual(volumeProduct.molarFlow,lengthProduct.molarFlow, ...
                'RelTol',1e-10) ;
            testCase.verifyEqual(volumeProduct.T,lengthProduct.T,'RelTol',1e-10) ;
        end

        function gasProductsDeriveNumericFlowAndConcentration(testCase)
            [~,rs] = IdealReactorCoreTest.baseCase() ;
            feed = Stream ;
            feed.phase = 'G' ;
            feed.molarFlow = [1 0] ; % mol/s
            feed.molarFlow_Units = 'mol/s' ;
            feed.volumetricFlow = [] ;
            feed.volumetricFlow_Units = 'm^3/s' ;
            feed.concentration = [] ;
            feed.T = 500 ; % K
            feed.P = 2e5 ; % Pa

            cstr = IdealReactorCoreTest.cstr('Isothermal') ;
            cstrProduct = cstr.compute_output(feed,rs) ;
            expectedCstrA = 1/(1+0.001/(8.314*feed.T/feed.P)) ;
            testCase.verifyEqual(cstrProduct.molarFlow(1),expectedCstrA, ...
                'RelTol',1e-8) ;
            IdealReactorCoreTest.verifyGasDerivedProperties(testCase,cstrProduct) ;

            pfr = IdealReactorCoreTest.pfr('Isothermal') ;
            pfrProduct = pfr.compute_output(feed,rs) ;
            IdealReactorCoreTest.verifyGasDerivedProperties(testCase,pfrProduct) ;
        end

        function heatCapacityFunctionOfTemperatureAndPressure(testCase)
            rs = ReactionSys ;
            rs.stochiometricMatrix = [-1 1] ;
            cp.option = 'Cp = f(T,P)' ;
            cp.FunctionWithP = {@(T,P) T+P/1e5,@(T,P) 2*T+P/2e5} ;
            rs.componentCp = cp ;

            values = rs.compute_HeatCapacity(300,2e5) ;

            testCase.verifyEqual(values,[302 601],'AbsTol',1e-12) ;
        end

        function pfrLiquidPressureDropExecutes(testCase)
            [feed,rs] = IdealReactorCoreTest.baseCase() ;
            feed.density = 1000 ; % kg/m^3
            feed.viscosity = 1e-3 ; % Pa*s
            rs.componentMw = [18 18] ; % g/mol
            reactor = IdealReactorCoreTest.pfr('Isothermal') ;
            reactor.pressureMode = 'Non constant' ;
            reactor.pressureDropEqn = 'Pipe' ;

            product = reactor.compute_output(feed,rs) ;

            testCase.verifyLessThan(product.P,feed.P) ;
        end

        function secondOrderCstrRegression(testCase)
            [feed,rs] = IdealReactorCoreTest.baseCase() ;
            rs.stochiometricMatrix = [-2 1] ;
            rs.k0 = 5e-3 ;
            rs.Ea = 20000 ; % J/mol
            reactor = IdealReactorCoreTest.cstr('Isothermal') ;
            reactor.V = 0.2 ; % m^3
            feed.T = 350 ; % K

            product = reactor.compute_output(feed,rs) ;

            testCase.verifyEqual(product.molarFlow(1),0.494233531520652, ...
                'RelTol',1e-8) ;
            testCase.verifyEqual(product.molarFlow(2),0.252883234239674, ...
                'RelTol',1e-8) ;
        end

        function parallelGasCstrRegression(testCase)
            feed = Stream ;
            feed.phase = 'G' ;
            feed.volumetricFlow = 1e-3 ; % m^3/s
            feed.P = 10*101325 ; % Pa
            feed.T = 500.15 ; % K
            feed.molarFlow = feed.P*feed.volumetricFlow/(8.314*feed.T) * ...
                [0.41 0.41 0 0.18] ; % mol/s
            nA0 = feed.molarFlow(1) ;
            q0 = feed.volumetricFlow ;
            rs = ReactionSys ;
            rs.stochiometricMatrix = [-1 -1 1 0] ;
            rs.userDefinedKinetics = @(C,T) ...
                IdealReactorCoreTest.example40Rate(C,nA0,q0,feed.P,feed.T) ;
            reactor = IdealReactorCoreTest.cstr('Isothermal') ;
            reactor.V = 0.4 ; % m^3
            sequence = {reactor,reactor} ;

            association = Reactor ;
            product = association.compute_parallel(feed,rs,sequence) ;
            conversion = (feed.molarFlow(1)-product.molarFlow(1)) / ...
                feed.molarFlow(1) ;

            % Reference from the independent design equation
            % 0.4*(-rA(X)) = (FA0/2)*X solved with fzero (R = 8.314). The
            % pre-T-101 value 0.578647079017323 was biased by Rg = 8.31 in
            % CSTR.m (Claude, T-101 review).
            testCase.verifyEqual(conversion,0.578473757692,'RelTol',1e-8) ;
        end

        function computeCostRemainsFiniteForOtherMode(testCase)
            [feed,rs] = IdealReactorCoreTest.baseCase() ;
            cstr = IdealReactorCoreTest.cstr('Other') ;
            cstr.U = 1000 ;
            cstr.heatTransferArea = 1 ;
            cstr.inletUtilityTemperature = 290 ;
            [cstrProduct,cstr] = cstr.compute_output(feed,rs) ;
            cstrCost = computeCost(cstr,feed,cstrProduct) ;

            pfr = IdealReactorCoreTest.pfr('Other') ;
            pfr.U = 100 ;
            pfr.inletUtilityTemperature = 350 ;
            pfr.outletUtilityTemperature = 340 ;
            [pfrProduct,pfr] = pfr.compute_output(feed,rs) ;
            pfrCost = computeCost(pfr,feed,pfrProduct) ;

            testCase.verifyTrue(isfinite(cstrCost)) ;
            testCase.verifyTrue(isfinite(pfrCost)) ;
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

        function [massResidual,energyLeftHandSide] = ...
                cstrResiduals(product,feed,rs,reactor)
            rsAtOutlet = rs.computeRate(product.concentration,product.T) ;
            rate = rsAtOutlet.r_i ;
            massResidual = feed.molarFlow-product.molarFlow + ...
                rate*rs.stochiometricMatrix*reactor.V ;
            energyLeftHandSide = feed.molarFlow*rs.componentCp.UserValues' * ...
                (product.T-feed.T) + reactor.V*rate*rs.DHref' ;
        end

        function verifyGasDerivedProperties(testCase,product)
            expectedFlow = sum(product.molarFlow)*8.314*product.T/product.P ;
            testCase.verifyClass(product.volumetricFlow,'double') ;
            testCase.verifyClass(product.concentration,'double') ;
            testCase.verifyEqual(product.volumetricFlow,expectedFlow,'RelTol',1e-12) ;
            testCase.verifyEqual(product.concentration, ...
                product.molarFlow/expectedFlow,'RelTol',1e-12) ;
        end

        function rate = example40Rate(concentration,nA0,q0,pressure,temperature)
            cA = concentration(1) ;
            conversion = (cA*q0-nA0)*pressure / ...
                (nA0*(cA*8.314*temperature-pressure)) ;
            rate = (0.0167-0.023*(conversion-0.1) + ...
                0.0234*(conversion-0.1)*(conversion-0.7))*1000/60 ;
        end
    end
end
