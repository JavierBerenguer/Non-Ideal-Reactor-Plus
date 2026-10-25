classdef NirpConvolutionTest < matlab.unittest.TestCase
    % NirpConvolutionTest verifies tracer convolution and deconvolution.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 9, 2026. Last update: October 25, 2026
    % =========================================================================

    methods (Test)
        function reproducesTopicExampleOne(testCase)
            Cin = nirp.conv.signal(0:4,[0 8 4 6 0]) ;
            E = nirp.conv.signal(2:6,[0 .05 .5 .35 0]) ;

            [out,info] = nirp.conv.convolve(E,Cin) ;

            testCase.verifyEqual(out.t,2:10,'AbsTol',1e-12) ;
            testCase.verifyEqual(out.C,[0 0 .4 4.2 5.1 4.4 2.1 0 0], ...
                'AbsTol',1e-12) ;
            testCase.verifyEqual(info.dt,1,'AbsTol',1e-12) ;
        end

        function reproducesTopicExampleThree(testCase)
            Cin = nirp.conv.signal(0:11,[0 0 8 6 4 5 6 3 1 0 0 0]) ;
            E = nirp.conv.signal(0:5,[0 .05 .5 .35 .1 0]) ;
            expected = [0 0 0 .4 4.3 6 5.15 4.8 5.3 4.15 2.15 .65 .1 0 0 0] ;

            [out,info] = nirp.conv.convolve(E,Cin) ;

            testCase.verifyEqual(out.t,0:16,'AbsTol',1e-12) ;
            testCase.verifyEqual(out.C(1:16),expected,'AbsTol',1e-12) ;
            testCase.verifyEqual(out.C(17),0,'AbsTol',1e-12) ;
            testCase.verifyEqual(sum(out.C),sum(Cin.C),'AbsTol',1e-12) ;
            testCase.verifyEqual(info.massBalance,1,'AbsTol',1e-12) ;
        end

        function piecewiseTrapzoidAndCstrAddMoments(testCase)
            dt = 1e-3 ; % s
            t = 0:dt:40 ; % s
            pulse = nirp.conv.piecewise([2 5 8 11], ...
                {@(x) x-2,@(x) 3+0*x,@(x) 11-x},t) ;
            pulseMoments = nirp.conv.moments(pulse) ;
            E1 = nirp.conv.signal(pulse.t,pulse.C/pulseMoments.area) ;
            cstr = nirp.conv.fromRTD(RTD.ideal_cstr(2),dt) ;

            out = nirp.conv.convolve(E1,cstr) ;
            outMoments = nirp.conv.moments(out) ;

            testCase.verifyEqual(pulseMoments.area,18,'AbsTol',1e-9) ;
            testCase.verifyEqual(pulseMoments.mean,6.5,'AbsTol',1e-9) ;
            testCase.verifyEqual(pulseMoments.variance,3.75,'AbsTol',1e-6) ;
            testCase.verifyEqual(outMoments.area,1,'AbsTol',1e-3) ;
            testCase.verifyEqual(outMoments.mean,8.5,'RelTol',1e-3) ;
            testCase.verifyEqual(outMoments.variance,7.75,'RelTol',1e-3) ;
        end

        function pfrIsExactFiveSecondShift(testCase)
            Cin = nirp.conv.signal(0:11,[0 0 8 6 4 5 6 3 1 0 0 0]) ;
            E = nirp.conv.fromRTD(RTD.ideal_pfr(5),1) ;

            out = nirp.conv.convolve(E,Cin) ;

            expected = [zeros(1,5) Cin.C zeros(1,numel(E.C)-6)] ;
            testCase.verifyEqual(out.C,expected,'AbsTol',1e-9) ;
            testCase.verifyEqual(out.t,0:numel(out.C)-1,'AbsTol',1e-12) ;
        end

        function cstrPreservesMassAndAddsMean(testCase)
            dt = 1e-3 ; % s
            coarse = nirp.conv.signal(0:11,[0 0 8 6 4 5 6 3 1 0 0 0]) ;
            Cin = nirp.conv.resample(coarse,dt) ;
            E = nirp.conv.fromRTD(RTD.ideal_cstr(5),dt) ;

            out = nirp.conv.convolve(E,Cin) ;
            inMoments = nirp.conv.moments(Cin) ;
            outMoments = nirp.conv.moments(out) ;

            testCase.verifyEqual(outMoments.area,inMoments.area,'RelTol',1e-3) ;
            testCase.verifyEqual(outMoments.mean,inMoments.mean+5,'AbsTol',1e-2) ;
        end

        function reproducesTopicExampleTwoDeconvolution(testCase)
            t = 0:4 ; % min, used consistently as the time unit in course data
            Cin = nirp.conv.fromFunction(@(x) x.*exp(-x/2),t) ;
            Cout = nirp.conv.signal(4:13,[.9 1.8 2.1 5.2 3.6 4.5 1.7 .8 .7 .5]) ;

            [E,info] = nirp.conv.deconvolve(Cin,Cout,[4 9]) ;

            testCase.verifyEqual(E.t,4:9,'AbsTol',1e-12) ;
            testCase.verifyEqual(E.C,[1.79 2.33 2.58 0 1.24 0], ...
                'AbsTol',2e-2) ;
            testCase.verifyGreaterThan(abs(info.areaE-1),1) ;
            testCase.verifySize(info.reconvolved.C,[1 10]) ;
            testCase.verifyFalse(info.underdetermined) ;
            testCase.verifyEqual(info.support,[4 9],'AbsTol',1e-12) ;
        end

        function zeroRegularizationExactlyPreservesLegacyResult(testCase)
            t = 0:4 ; % min, used consistently as the time unit in course data
            Cin = nirp.conv.fromFunction(@(x) x.*exp(-x/2),t) ;
            Cout = nirp.conv.signal(4:13,[.9 1.8 2.1 5.2 3.6 4.5 1.7 .8 .7 .5]) ;

            legacy = nirp.conv.deconvolve(Cin,Cout,[4 9]) ;
            [regularized,info] = nirp.conv.deconvolve(Cin,Cout,[4 9], ...
                struct('lambda',0,'smoothing','identity')) ;

            testCase.verifyEqual(regularized.C,legacy.C,'AbsTol',0) ;
            testCase.verifyEqual(regularized.C,[1.79 2.33 2.58 0 1.24 0], ...
                'AbsTol',2e-2) ;
            testCase.verifyEqual(info.lambda,0,'AbsTol',0) ;
            testCase.verifyFalse(info.lambdaSelectedAutomatically) ;
            testCase.verifyEqual(info.smoothing,'identity') ;
        end

        function automaticTikhonovReducesFixedSeedNoiseError(testCase)
            rng(187,'twister') ;
            dt = 0.2 ; % s
            t = 0:dt:20 ; % s
            Cin = nirp.conv.fromFunction(@(x) exp(-((x-2)/0.7).^2),t) ;
            trueE = nirp.conv.fromRTD(RTD.tanks_in_series(3,5,t),dt) ;
            clean = nirp.conv.convolve(trueE,Cin) ;
            noise = 0.05*max(clean.C)*randn(size(clean.C)) ;
            measured = nirp.conv.signal(clean.t,max(0,clean.C+noise)) ;

            unregularized = nirp.conv.deconvolve(Cin,measured,numel(trueE.C)) ;
            [regularized,info] = nirp.conv.deconvolve(Cin,measured, ...
                numel(trueE.C),struct('lambda','auto')) ;
            rawError = norm(unregularized.C-trueE.C)/norm(trueE.C) ;
            regularizedError = norm(regularized.C-trueE.C)/norm(trueE.C) ;
            regularizedArea = trapz(regularized.t,regularized.C) ;
            oracleLambda = testCase.minimumErrorLambda( ...
                Cin,measured,trueE,trueE.t) ;

            testCase.verifyGreaterThan(rawError,1) ;
            testCase.verifyLessThan(regularizedError,0.1) ;
            testCase.verifyLessThan(regularizedError,0.2*rawError) ;
            testCase.verifyEqual(regularizedArea,1,'AbsTol',0.02) ;
            testCase.verifyGreaterThan(info.lCurve.selectedIndex,1) ;
            testCase.verifyLessThan(info.lCurve.selectedIndex, ...
                numel(info.lCurve.lambda)) ;
            testCase.verifyEqual(info.lambda, ...
                info.lCurve.lambda(info.lCurve.selectedIndex),'RelTol',1e-12) ;
            % A factor of two accommodates the 40-point production sweep
            % while still requiring the same logarithmic L-curve corner.
            testCase.verifyGreaterThanOrEqual(info.lambda/oracleLambda,0.5) ;
            testCase.verifyLessThanOrEqual(info.lambda/oracleLambda,2) ;
        end

        function automaticLambdaTracksNoisyPublishedBenchmark(testCase)
            dt = 0.5 ; % s
            t = 0:dt:7 ; % s
            Cin = nirp.conv.signal(t, ...
                [0 1 .8 .4 .1 0 0 0 0 0 0 0 0 0 0]) ;
            measured = nirp.conv.signal(t, ...
                [.0099 0 .088 .2905 .4853 .5478 .4766 .2853 .1181 ...
                 .0554 .0017 0 .0048 0 0]) ;
            trueE = nirp.conv.signal(0:dt:4, ...
                [0 .15 .4 .6 .45 .25 .1 .03 0]) ;

            [estimated,info] = nirp.conv.deconvolve( ...
                Cin,measured,[0 4],struct('lambda','auto')) ;
            oracleLambda = testCase.minimumErrorLambda( ...
                Cin,measured,trueE,trueE.t) ;

            testCase.verifyGreaterThanOrEqual(info.lambda/oracleLambda,0.5) ;
            testCase.verifyLessThanOrEqual(info.lambda/oracleLambda,2) ;
            testCase.verifyLessThan( ...
                norm(estimated.C-trueE.C)/norm(trueE.C),0.11) ;
            testCase.verifyEqual(trapz(estimated.t,estimated.C),1, ...
                'AbsTol',0.03) ;
        end

        function signedCurvatureRecoversExactPublishedBenchmarks(testCase)
            definitions = { ...
                {1,0:8,[0 2 2 1 0 0 0 0 0], ...
                    [0 0 .4 1 1.2 .8 .3 .05 0],0:4,[0 .2 .3 .2 .05]}, ...
                {.5,0:.5:5,[1 .5 .25 .1 .05 0 0 0 0 0 0], ...
                    [0 .25 .325 .2875 .1875 .08875 .035 .01125 .0025 0 0], ...
                    0:.5:2.5,[0 .5 .4 .25 .1 0]}, ...
                {.2,0:.2:3,[0 .5 1 .8 .3 0 0 0 0 0 0 0 0 0 0 0], ...
                    [0 0 .01 .055 .156 .292 .388 .386 .304 .2 .113 ...
                     .052 .017 .003 0 0],0:.2:2, ...
                    [0 .1 .35 .7 .9 .75 .5 .3 .15 .05 0]}, ...
                {1,0:6,[.8 .2 0 0 0 0 0],[.16 .28 .26 .17 .03 0 0], ...
                    0:4,[.2 .3 .25 .15 0]}} ;

            for k = 1:numel(definitions)
                values = definitions{k} ;
                Cin = nirp.conv.signal(values{2},values{3}) ;
                Cout = nirp.conv.signal(values{2},values{4}) ;
                reference = values{6} ;
                [estimated,info] = nirp.conv.deconvolve( ...
                    Cin,Cout,values{5}([1 end]),struct('lambda','auto')) ;

                testCase.verifyLessThan(norm(estimated.C-reference),1e-8) ;
                testCase.verifyGreaterThan(info.lCurve.curvature( ...
                    info.lCurve.selectedIndex),0) ;
            end
        end

        function sect02UnregularizedResultIsUnchanged(testCase)
            % SECT02 is stored in minutes and mol/L; reproduce it in SI.
            inletMinutes = 0:4 ;
            Cin = nirp.conv.signal(inletMinutes*60, ...
                inletMinutes.*exp(-inletMinutes/2)*1000) ;
            Cout = nirp.conv.signal((4:13)*60, ...
                [.9 1.8 2.1 5.2 3.6 4.5 1.7 .8 .7 .5]*1000) ;

            baseline = nirp.conv.deconvolve(Cin,Cout,[4 9]*60) ;
            [explicit,zeroInfo] = nirp.conv.deconvolve(Cin,Cout,[4 9]*60, ...
                struct('lambda',0)) ;
            [~,autoInfo] = nirp.conv.deconvolve(Cin,Cout,[4 9]*60, ...
                struct('lambda','auto')) ;

            testCase.verifyEqual(explicit.C,baseline.C,'AbsTol',0) ;
            testCase.verifyEqual(zeroInfo.lambda,0,'AbsTol',0) ;
            testCase.verifyEqual(autoInfo.lCurve.selectedIndex,24) ;
            testCase.verifyGreaterThan(autoInfo.lCurve.curvature(24),0) ;
            testCase.verifyLessThan(autoInfo.lCurve.curvature(31),0) ;
            testCase.verifyGreaterThan(autoInfo.lambda,5e3) ;
            testCase.verifyLessThan(autoInfo.lambda,1e4) ;
        end

        function manualIdentityTikhonovUsesAugmentedNnls(testCase)
            Cin = nirp.conv.signal(0:2,[1 2 1]) ;
            Cout = nirp.conv.signal(0:4,[0.2 1.2 2.6 2.1 0.7]) ;
            lambda = 0.3 ;

            [estimated,info] = nirp.conv.deconvolve(Cin,Cout,3, ...
                struct('lambda',lambda,'smoothing','identity')) ;
            A = interp1(Cin.t,Cin.C,Cout.t(:)-(0:2),'linear',0) ;
            expected = lsqnonneg([A; lambda*eye(3)], ...
                [Cout.C.'; zeros(3,1)]) ;

            testCase.verifyEqual(estimated.C,expected.','AbsTol',1e-12) ;
            testCase.verifyEqual(info.regularizationMatrix,eye(3),'AbsTol',0) ;
        end

        function explicitSupportUsesAllMeasuredSamples(testCase)
            Cin = nirp.conv.fromFunction(@(t) t.*exp(-t/2),0:13) ;
            Cout = nirp.conv.signal(4:13, ...
                [.9 1.8 2.1 5.2 3.6 4.5 1.7 .8 .7 .5]) ;

            [E,info] = nirp.conv.deconvolve(Cin,Cout,[0 13]) ;

            testCase.verifyEqual(E.t,0:13,'AbsTol',1e-12) ;
            testCase.verifyEqual(info.reconvolved.t,Cout.t,'AbsTol',1e-12) ;
            testCase.verifySize(info.residual,size(Cout.C)) ;
            testCase.verifyTrue(info.underdetermined) ;
            testCase.verifyEqual(info.numberOfUnknowns,14) ;
            testCase.verifyEqual(info.numberOfEquations,10) ;
        end

        function recoversNoisyProblemSixDistribution(testCase)
            Cin = nirp.conv.signal(0:11,[0 0 8 6 4 5 6 3 1 0 0 0]) ;
            Cout = nirp.conv.signal(0:15, ...
                [0 0 0 .4 4.3 6 5.1 4.8 5.63 4.1 2.1 .6 .1 0 0 0]) ;

            [E,info] = nirp.conv.deconvolve(Cin,Cout,6) ;

            testCase.verifyEqual(E.C,[0 .05 .5 .35 .1 0],'AbsTol',.1) ;
            testCase.verifyLessThan(info.residualNorm,1) ;
        end

        function exactlyRecoversSyntheticDistribution(testCase)
            Cin = nirp.conv.signal(0:.25:1,[1 2 3 2 1]) ;
            expected = nirp.conv.signal(2:.25:2.75,[.2 .8 .6 .1]) ;
            Cout = nirp.conv.convolve(expected,Cin) ;

            E = nirp.conv.deconvolve(Cin,Cout) ;

            testCase.verifyEqual(E.t,expected.t,'AbsTol',1e-12) ;
            testCase.verifyEqual(E.C,expected.C,'AbsTol',1e-8) ;
        end

        function composesSeriesAndParallelDistributions(testCase)
            E1 = nirp.conv.signal(0:2,[0 .5 .5]) ;
            E2 = nirp.conv.signal(0:2,[0 .25 .75]) ;

            serial = nirp.conv.series(E1,E2) ;
            mixed = nirp.conv.parallel({E1,E2},[.4 .6]) ;

            testCase.verifyEqual(serial.C,conv(E1.C,E2.C),'AbsTol',1e-12) ;
            testCase.verifyEqual(mixed.C,.4*E1.C+.6*E2.C,'AbsTol',1e-12) ;
        end

        function rejectsInvalidSignalsAndGrids(testCase)
            testCase.verifyError(@() nirp.conv.signal(0:2,[1 -1 2]), ...
                'nirp:conv:NegativeConcentration') ;
            testCase.verifyError(@() nirp.conv.convolve( ...
                nirp.conv.signal(0:2,[0 1 0]), ...
                nirp.conv.signal(0:.5:2,[0 1 2 1 0])), ...
                'nirp:conv:StepMismatch') ;
            testCase.verifyError(@() nirp.conv.convolve( ...
                nirp.conv.signal([0 1 3],[0 1 0]), ...
                nirp.conv.signal(0:2,[0 1 0])), ...
                'nirp:conv:NonuniformGrid') ;
            testCase.verifyError(@() nirp.conv.deconvolve( ...
                nirp.conv.signal(0:2,[1 2 1]), ...
                nirp.conv.signal(0:4,[1 2 3 2 1]),6), ...
                'nirp:conv:InvalidLength') ;
        end
    end

    methods (Static, Access = private)
        function lambda = minimumErrorLambda(Cin,Cout,reference,tau)
            dt = Cin.t(2)-Cin.t(1) ;
            matrix = interp1(Cin.t,Cin.C,Cout.t(:)-tau,'linear',0)*dt ;
            L = diff(eye(numel(tau)),2,1) ;
            scale = norm(matrix,2) ;
            lambdas = logspace(log10(1e-6*scale), ...
                log10(1e2*scale),400) ;
            errors = zeros(size(lambdas)) ;
            for k = 1:numel(lambdas)
                estimate = lsqnonneg([matrix;lambdas(k)*L], ...
                    [Cout.C.';zeros(size(L,1),1)]) ;
                errors(k) = norm(estimate-reference.C.') ;
            end
            [~,index] = min(errors) ;
            lambda = lambdas(index) ;
        end
    end
end
