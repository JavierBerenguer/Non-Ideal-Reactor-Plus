classdef NirpTracerReactiveTest < matlab.unittest.TestCase
    % NirpTracerReactiveTest verifies stationary reactive tracer vessels.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 25, 2026. Last update: October 25, 2026
    % =========================================================================

    methods (Test)
        function firstOrderCstrAndThreeTanksMatchAnalytical(testCase)
            grid = nirp.tracer.grid(0.01,40) ;
            tau = 2 ; k = 0.4 ; C0 = [10 0] ;
            rs = NirpTracerReactiveTest.powerLaw(1,k,0) ;
            cstr = exp(-grid.t/tau)/tau ;
            tanks = grid.t.^2.*exp(-grid.t/(tau/3))/(2*(tau/3)^3) ;

            cstrOut = nirp.tracer.reactiveVessel(grid,cstr,rs,C0,298.15,1) ;
            tanksOut = nirp.tracer.reactiveVessel(grid,tanks,rs,C0,298.15,1) ;
            expectedCstr = k*tau/(1+k*tau) ;
            expectedTanks = 1-(1+k*tau/3)^-3 ;

            % Relative tolerance 0.3% covers common-grid RTD quadrature.
            testCase.verifyEqual(cstrOut.Xseg,expectedCstr,'RelTol',3e-3) ;
            testCase.verifyEqual(cstrOut.Xmm,expectedCstr,'RelTol',3e-3) ;
            testCase.verifyEqual(tanksOut.Xseg,expectedTanks,'RelTol',3e-3) ;
            testCase.verifyEqual(tanksOut.Xmm,expectedTanks,'RelTol',3e-3) ;
        end

        function secondOrderCstrHasAnalyticalMaximumMixedness(testCase)
            grid = nirp.tracer.grid(0.01,40) ;
            tau = 2 ; k = 0.01 ; C0 = [10 0] ;
            rs = NirpTracerReactiveTest.powerLaw(2,k,0) ;
            E = exp(-grid.t/tau)/tau ;

            out = nirp.tracer.reactiveVessel(grid,E,rs,C0,298.15,1) ;
            cstrConcentration = (-1+sqrt(1+4*k*tau*C0(1)))/(2*k*tau) ;
            expected = 1-cstrConcentration/C0(1) ;

            testCase.verifyEqual(out.Xmm,expected,'RelTol',4e-3) ;
            testCase.verifyGreaterThan(out.Xseg,out.Xmm) ;
        end

        function halfOrderReversesBoundDirectionAndStaysNonnegative(testCase)
            grid = nirp.tracer.grid(0.01,40) ;
            tau = 2 ;
            rs = NirpTracerReactiveTest.powerLaw(0.5,0.2,0) ;
            E = exp(-grid.t/tau)/tau ;

            out = nirp.tracer.reactiveVessel(grid,E,rs,[10 0],298.15,1) ;
            testCase.verifyGreaterThan(out.Xmm,out.Xseg) ;
            testCase.verifyGreaterThanOrEqual(out.Cseg,zeros(1,2)) ;
            testCase.verifyGreaterThanOrEqual(out.Cmm,zeros(1,2)) ;

            pfrGrid = nirp.tracer.grid(0.01,5) ;
            pfr = nirp.tracer.rtdModel(pfrGrid,'pfr',struct('tau',4),1) ;
            depleted = nirp.tracer.reactiveVessel( ...
                pfrGrid,pfr,NirpTracerReactiveTest.powerLaw(0.5,1,0), ...
                [1 0],298.15,1) ;
            testCase.verifyGreaterThanOrEqual(depleted.Cseg,zeros(1,2)) ;
            testCase.verifyEqual(depleted.Cseg(1),0,'AbsTol',2e-6) ;
        end

        function pfrPulseMatchesPlugFlowForOrdersOneAndTwo(testCase)
            grid = nirp.tracer.grid(0.01,5) ;
            tau = 2 ; C0 = [10 0] ;
            E = nirp.tracer.rtdModel(grid,'pfr',struct('tau',tau),1) ;
            first = nirp.tracer.reactiveVessel(grid,E, ...
                NirpTracerReactiveTest.powerLaw(1,0.4,0),C0,298.15,1) ;
            second = nirp.tracer.reactiveVessel(grid,E, ...
                NirpTracerReactiveTest.powerLaw(2,0.01,0),C0,298.15,1) ;
            expectedFirst = 1-exp(-0.4*tau) ;
            expectedSecond = 1-1/(1+0.01*C0(1)*tau) ;

            testCase.verifyEqual([first.Xseg first.Xmm], ...
                expectedFirst*[1 1],'RelTol',2e-5) ;
            testCase.verifyEqual([second.Xseg second.Xmm], ...
                expectedSecond*[1 1],'RelTol',2e-5) ;
        end

        function twoCstrsInSeriesMatchTwoIdealTanks(testCase)
            grid = nirp.tracer.grid(0.01,40) ;
            tau = 1.5 ; k = 0.3 ; C0 = [10 0] ;
            rs = NirpTracerReactiveTest.powerLaw(1,k,0) ;
            E = exp(-grid.t/tau)/tau ;
            first = nirp.tracer.reactiveVessel(grid,E,rs,C0,298.15,1) ;
            secondSeg = nirp.tracer.reactiveVessel( ...
                grid,E,rs,first.Cseg,298.15,1) ;
            secondMm = nirp.tracer.reactiveVessel( ...
                grid,E,rs,first.Cmm,298.15,1) ;
            expected = 1-(1+k*tau)^-2 ;

            overallSeg = 1-secondSeg.Cseg(1)/C0(1) ;
            overallMm = 1-secondMm.Cmm(1)/C0(1) ;
            testCase.verifyEqual(overallSeg,expected,'RelTol',4e-3) ;
            testCase.verifyEqual(overallMm,expected,'RelTol',4e-3) ;
        end

        function mixerAndSplitterConserveEachReactiveChain(testCase)
            grid = nirp.tracer.grid(0.1,2) ;
            first = nirp.tracer.source(grid,1,ones(size(grid.t)),1) ;
            second = nirp.tracer.source(grid,3,2*ones(size(grid.t)),1) ;
            first.Cseg = [8 2] ; first.Cmm = [7 3] ;
            second.Cseg = [4 6] ; second.Cmm = [5 5] ;

            mixed = nirp.tracer.mixer(grid,{first,second}) ;
            [branches,fractions] = nirp.tracer.splitter(grid,mixed,[0.2 0.3]) ;
            inletSeg = first.Q*first.Cseg+second.Q*second.Cseg ;
            inletMm = first.Q*first.Cmm+second.Q*second.Cmm ;
            outletSeg = zeros(1,2) ; outletMm = zeros(1,2) ;
            for k = 1:numel(branches)
                outletSeg = outletSeg+branches{k}.Q*branches{k}.Cseg ;
                outletMm = outletMm+branches{k}.Q*branches{k}.Cmm ;
                testCase.verifyEqual(branches{k}.Cseg,mixed.Cseg) ;
                testCase.verifyEqual(branches{k}.Cmm,mixed.Cmm) ;
            end

            testCase.verifyEqual(mixed.Cseg,[5 5],'AbsTol',1e-14) ;
            testCase.verifyEqual(mixed.Cmm,[5.5 4.5],'AbsTol',1e-14) ;
            testCase.verifyEqual(fractions,[0.2 0.3 0.5],'AbsTol',1e-14) ;
            testCase.verifyEqual(outletSeg,inletSeg,'AbsTol',1e-13) ;
            testCase.verifyEqual(outletMm,inletMm,'AbsTol',1e-13) ;
        end

        function temperatureUsesArrheniusAndDefaultIsUnchanged(testCase)
            grid = nirp.tracer.grid(0.01,40) ;
            tau = 2 ; k0 = 2e5 ; Ea = 30000 ; C0 = [10 0] ;
            rs = NirpTracerReactiveTest.powerLaw(1,k0,Ea) ;
            E = exp(-grid.t/tau)/tau ;
            low = nirp.tracer.reactiveVessel(grid,E,rs,C0,290,1) ;
            high = nirp.tracer.reactiveVessel(grid,E,rs,C0,330,1) ;
            expectedLow = NirpTracerReactiveTest.cstrFirstOrder(k0,Ea,290,tau) ;
            expectedHigh = NirpTracerReactiveTest.cstrFirstOrder(k0,Ea,330,tau) ;

            testCase.verifyEqual(low.Xseg,expectedLow,'RelTol',3e-3) ;
            testCase.verifyEqual(high.Xmm,expectedHigh,'RelTol',3e-3) ;
            testCase.verifyGreaterThan(high.Xseg,low.Xseg) ;

            rtd = RTD(grid.t,E) ;
            defaultSeg = SegregationModel(rtd) ;
            defaultSeg = defaultSeg.compute_isothermal(rs,C0) ;
            explicitSeg = SegregationModel(rtd) ;
            explicitSeg = explicitSeg.compute_isothermal(rs,C0,298.15) ;
            defaultMm = MaxMixednessModel(rtd) ;
            defaultMm = defaultMm.compute_isothermal(rs,C0) ;
            explicitMm = MaxMixednessModel(rtd) ;
            explicitMm = explicitMm.compute_isothermal(rs,C0,298.15) ;
            testCase.verifyEqual(defaultSeg.C_exit,explicitSeg.C_exit,'AbsTol',0) ;
            testCase.verifyEqual(defaultMm.C_exit,explicitMm.C_exit,'AbsTol',0) ;
        end

        function edgeCasesReturnDiagnosticsWithoutIntegration(testCase)
            grid = nirp.tracer.grid(0.1,5) ;
            rs = NirpTracerReactiveTest.powerLaw(1,0.4,0) ;
            E = exp(-grid.t/2)/2 ;
            zero = nirp.tracer.reactiveVessel(grid,E,rs,[0 0],298.15,1) ;
            noKey = nirp.tracer.reactiveVessel(grid,E,rs,[0 2],298.15,1) ;
            singleRs = ReactionSys ; singleRs.stochiometricMatrix = -1 ;
            singleRs.k0 = 0.4 ;
            single = nirp.tracer.reactiveVessel(grid,E,singleRs,3,298.15,1) ;

            testCase.verifyEqual(zero.Cseg,[0 0]) ;
            testCase.verifyEqual(zero.Cmm,[0 0]) ;
            testCase.verifyTrue(isnan(zero.Xseg) && isnan(zero.Xmm)) ;
            testCase.verifyTrue(isnan(noKey.Xseg) && isnan(noKey.Xmm)) ;
            testCase.verifySize(single.Cseg,[1 1]) ;
            identifiers = string({zero.diagnostic.warnings.identifier}) ;
            testCase.verifyTrue(any(identifiers == ...
                "nirp:tracer:UndefinedKeyConversion")) ;
            testCase.verifyLessThan(zero.diagnostic.areaRetained,1) ;
            testCase.verifyTrue(any(string({zero.diagnostic.warnings.identifier}) == ...
                "nirp:tracer:TruncatedRTD")) ;
        end

        function boundValidityExplainsCriterion(testCase)
            second = ReactionSys ; second.stochiometricMatrix = [-2 1] ;
            second.k0 = 0.01 ;
            half = ReactionSys ; half.stochiometricMatrix = [-0.5 1] ;
            half.k0 = 0.01 ;
            first = ReactionSys ; first.stochiometricMatrix = [-1 1] ;
            first.k0 = 0.01 ;
            multiple = first ; multiple.stochiometricMatrix = [-1 1;-1 1] ;
            multiple.k0 = [0.01 0.02] ;
            custom = first ; custom.userDefinedKinetics = @(C,T) C(1) ;

            high = nirp.tracer.boundValidity(second,1) ;
            low = nirp.tracer.boundValidity(half,1) ;
            linear = nirp.tracer.boundValidity(first,1) ;
            many = nirp.tracer.boundValidity(multiple,1) ;
            unknown = nirp.tracer.boundValidity(custom,1) ;
            testCase.verifyTrue(high.guaranteed) ;
            testCase.verifyEqual(high.direction,'segregation-upper') ;
            testCase.verifyTrue(low.guaranteed) ;
            testCase.verifyEqual(low.direction,'maximum-mixedness-upper') ;
            testCase.verifyFalse(linear.guaranteed) ;
            testCase.verifyEqual(linear.direction,'coincident') ;
            testCase.verifyFalse(many.guaranteed) ;
            testCase.verifyFalse(unknown.guaranteed) ;
        end
    end

    methods (Static, Access = private)
        function rs = powerLaw(order,k0,Ea)
            rs = ReactionSys ;
            rs.stochiometricMatrix = [-1 1] ;
            if order == 1
                rs.k0 = k0 ;
                rs.Ea = Ea ;
            else
                rs.userDefinedKinetics = @(C,T) k0*exp(-Ea/(8.314*T))* ...
                    max(C(1),0)^order ;
            end
        end

        function value = cstrFirstOrder(k0,Ea,T,tau)
            k = k0*exp(-Ea/(8.314*T)) ;
            value = k*tau/(1+k*tau) ;
        end
    end
end
