classdef NirpConvolutionTest < matlab.unittest.TestCase
    % NirpConvolutionTest verifies tracer convolution and deconvolution.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 9, 2026. Last update: October 21, 2026
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

            testCase.verifyGreaterThan(rawError,1) ;
            testCase.verifyLessThan(regularizedError,0.1) ;
            testCase.verifyLessThan(regularizedError,0.2*rawError) ;
            testCase.verifyEqual(regularizedArea,1,'AbsTol',0.02) ;
            testCase.verifyGreaterThan(info.lCurve.selectedIndex,1) ;
            testCase.verifyLessThan(info.lCurve.selectedIndex, ...
                numel(info.lCurve.lambda)) ;
            testCase.verifyEqual(info.lambda, ...
                info.lCurve.lambda(info.lCurve.selectedIndex),'RelTol',1e-12) ;
        end

        function sect02LcurveRejectsSmallLambdaPlateau(testCase)
            % SECT02 is stored in minutes and mol/L; reproduce it in SI.
            inletMinutes = 0:4 ;
            Cin = nirp.conv.signal(inletMinutes*60, ...
                inletMinutes.*exp(-inletMinutes/2)*1000) ;
            Cout = nirp.conv.signal((4:13)*60, ...
                [.9 1.8 2.1 5.2 3.6 4.5 1.7 .8 .7 .5]*1000) ;

            [~,info] = nirp.conv.deconvolve(Cin,Cout,[4 9]*60, ...
                struct('lambda','auto')) ;

            testCase.verifyEqual(info.lCurve.selectedIndex,31) ;
            testCase.verifyGreaterThan(info.lambda,1e5) ;
            testCase.verifyLessThan(info.lambda,3e5) ;
            testCase.verifyGreaterThan(info.lCurve.residualNorm(31),2300) ;
            testCase.verifyLessThan(info.lCurve.residualNorm(31),2450) ;
            testCase.verifyGreaterThan(info.lCurve.selectedIndex, ...
                numel(info.lCurve.lambda)/2) ;
            testCase.verifyLessThan(info.lCurve.selectedIndex, ...
                numel(info.lCurve.lambda)) ;
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
end
