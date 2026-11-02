classdef NirpNonIdealReactorCoreTest < matlab.unittest.TestCase
    % NirpNonIdealReactorCoreTest verifies the non-ideal reactor unit core.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: November 3, 2026. Last update: November 3, 2026
    % =========================================================================

    methods (Test)
        function cstrMaximumMixednessMatchesIdeal(testCase)
            [in,rs] = baseCase(2) ;
            actual = solve(in,rs,modelRtd('cstr',2),'maxmixedness',false) ;
            ideal = nirp.units.cstr(struct('V',2*in.Q),in,rs) ;
            testCase.verifyEqual(actual.F,ideal.F,'RelTol',1e-4) ;
        end

        function pfrBothModelsMatchIdeal(testCase)
            [in,rs] = baseCase(2) ; rtd = modelRtd('pfr',2) ;
            segregation = solve(in,rs,rtd,'segregation',false) ;
            maximumMixedness = solve(in,rs,rtd,'maxmixedness',false) ;
            ideal = nirp.units.pfr(struct('V',2*in.Q),in,rs) ;
            % A discrete impulse has one-grid-step residence-time uncertainty.
            testCase.verifyEqual(segregation.F,ideal.F,'RelTol',1e-3) ;
            testCase.verifyEqual(maximumMixedness.F,ideal.F,'RelTol',1e-3) ;
        end

        function hundredTanksApproachPfrAndFirstOrderLimitsCoincide(testCase)
            [in,rs] = baseCase(2) ;
            tanks = modelRtd('tanks',2) ; tanks.N = 100 ;
            actual = solve(in,rs,tanks,'segregation',false) ;
            ideal = nirp.units.pfr(struct('V',2*in.Q),in,rs) ;
            testCase.verifyEqual(actual.F,ideal.F,'RelTol',2e-2) ;

            rs.k0 = 0.4 ; rs.userDefinedKinetics = [] ;
            segregation = solve(in,rs,modelRtd('cstr',2),'segregation',false) ;
            maximumMixedness = solve(in,rs,modelRtd('cstr',2),'maxmixedness',false) ;
            testCase.verifyEqual(segregation.F,maximumMixedness.F,'RelTol',1e-4) ;
        end

        function january2024SeriesMatchesReference(testCase)
            rs = examReactionSystem() ;
            in = nirp.stream.create([0.05;0;0;0;0],298.15,101325,0,5e-5) ;
            firstRtd = modelRtd('tanks',1) ; firstRtd.N = 1 ;
            secondRtd = modelRtd('tanks',2) ; secondRtd.N = 100 ;
            expectedFirst = [0.13824 0.060735 0.060735 0.31779 0.31779; ...
                0.19385 0.069644 0.069644 0.29107 0.29107] ;
            expectedSecond = [0.044859 0.038064 0.16512 0.24168 0.24168; ...
                0.045823 0.038935 0.18121 0.24376 0.24376] ;
            modes = {'segregation','maxmixedness'} ;
            for k = 1:2
                first = solve(in,rs,firstRtd,modes{k},false) ;
                second = solve(first,rs,secondRtd,modes{k},false) ;
                testCase.verifyEqual(first.F.'/in.Q/1000,expectedFirst(k,:), ...
                    'RelTol',5e-3) ;
                testCase.verifyEqual(second.F.'/in.Q/1000,expectedSecond(k,:), ...
                    'RelTol',5e-3) ;
            end
        end

        function heatMatchesIdealCstr(testCase)
            [in,rs] = baseCase(2) ;
            params = commonParams(modelRtd('cstr',2),'maxmixedness',true) ;
            [~,actualInfo] = nirp.units.nonIdealReactor(params,in,rs) ;
            [~,idealInfo] = nirp.units.cstr(struct('V',2*in.Q),in,rs) ;
            testCase.verifyEqual(actualInfo.heatDuty,idealInfo.heatDuty,'RelTol',1e-4) ;
        end

        function deficientStoichiometryMakesHeatUnavailable(testCase)
            [in,rs] = baseCase(1) ;
            rs.stochiometricMatrix = [-1 1 0;-1 1 0] ;
            rs.userDefinedKinetics = @(C,T) [0.005*C(1),0.005*C(1)] ; %#ok<INUSD>
            rs.DHref = [-10000 -10000] ; rs.componentCp = [80 80 80] ;
            in = nirp.stream.create([0.01;0;0.003],300,101325,0,0.001) ;
            [~,info] = nirp.units.nonIdealReactor( ...
                commonParams(modelRtd('cstr',1),'maxmixedness',true),in,rs) ;
            testCase.verifyTrue(isnan(info.heatDuty)) ;
            testCase.verifyTrue(any(contains(string(info.warnings),'rank deficient'))) ;
        end

        function missingThermodynamicsRaisesClearError(testCase)
            [in,rs] = baseCase(1) ; rs.componentCp = [] ; rs.DHref = [] ;
            testCase.verifyError(@() nirp.units.nonIdealReactor( ...
                commonParams(modelRtd('cstr',1),'maxmixedness',true),in,rs), ...
                'nirp:blocks:noThermodynamics') ;
        end

        function gasInertsZeroFeedAndZeroKeyAreHandled(testCase)
            [in,rs] = baseCase(1) ;
            gas = nirp.stream.create(in.F,in.T,in.P,1) ;
            params = commonParams(modelRtd('cstr',1),'segregation',false) ;
            testCase.verifyError(@() nirp.units.nonIdealReactor(params,gas,rs), ...
                'nirp:units:nonIdealGasNotSupported') ;

            in.F(3) = 0.002 ;
            out = nirp.units.nonIdealReactor(params,in,rs) ;
            testCase.verifyEqual(out.F(3),in.F(3),'AbsTol',0) ;

            zero = nirp.stream.create(zeros(3,1),in.T,in.P,0,0) ;
            zeroOut = nirp.units.nonIdealReactor(params,zero,rs) ;
            testCase.verifyEqual(zeroOut,zero) ;

            noKey = in ; noKey.F(1) = 0 ; params.keyIndex = 1 ;
            [~,info] = nirp.units.nonIdealReactor(params,noKey,rs) ;
            testCase.verifyTrue(isnan(info.conversion)) ;
            testCase.verifyTrue(any(contains(string(info.warnings),'undefined'))) ;
        end

        function dataSizeConflictIsRejected(testCase)
            [in,rs] = baseCase(1) ;
            rtd = struct('origin','data','t',0:0.1:5, ...
                'E',exp(-(0:0.1:5)),'tau',2) ;
            testCase.verifyError(@() nirp.units.nonIdealReactor( ...
                commonParams(rtd,'segregation',false),in,rs), ...
                'nirp:units:nonIdealSizeConflict') ;
        end

        function descriptorsRetainTailAndOriginalDataMean(testCase)
            cstr = nirp.tracer.rtdDescriptor(modelRtd('cstr',2),1) ;
            tanksSpec = modelRtd('tanks',2) ; tanksSpec.N = 100 ;
            tanks = nirp.tracer.rtdDescriptor(tanksSpec,1) ;
            t = 0:0.2:2 ; E = exp(-t) ;
            data = nirp.tracer.rtdDescriptor( ...
                struct('origin','data','t',t,'E',E),1) ;
            testCase.verifyLessThanOrEqual(cstr.tailFraction,1e-6) ;
            testCase.verifyLessThanOrEqual(tanks.tailFraction,1e-6) ;
            testCase.verifyEqual(cstr.tau,2,'RelTol',1e-12) ;
            testCase.verifyEqual(tanks.tau,2,'RelTol',1e-12) ;
            testCase.verifyEqual(data.tau,trapz(t,t.*E)/trapz(t,E), ...
                'RelTol',1e-12) ;
            testCase.verifyEqual(data.rawArea,trapz(t,E),'RelTol',1e-12) ;
        end

        function selectiveModeAndDefaultRegression(testCase)
            grid = nirp.tracer.grid(0.01,40) ;
            E = exp(-grid.t/2)/2 ; [~,rs] = baseCase(1) ;
            baseline = nirp.tracer.reactiveVessel( ...
                grid,E,rs,[10 0 0],298.15,1) ;
            segregation = nirp.tracer.reactiveVessel( ...
                grid,E,rs,[10 0 0],298.15,1,'Mode','segregation') ;
            maximumMixedness = nirp.tracer.reactiveVessel( ...
                grid,E,rs,[10 0 0],298.15,1,'Mode','maxmixedness') ;
            testCase.verifyEqual(segregation.Cseg,baseline.Cseg,'AbsTol',0) ;
            testCase.verifyEqual(maximumMixedness.Cmm,baseline.Cmm,'AbsTol',0) ;
            testCase.verifyEmpty(segregation.Cmm) ;
            testCase.verifyEmpty(maximumMixedness.Cseg) ;
            testCase.verifyEqual(baseline.Xseg,0.444444444444444,'RelTol',3e-3) ;
            testCase.verifyEqual(baseline.Xmm,0.444444444444444,'RelTol',3e-3) ;
        end
    end
end

function [in,rs] = baseCase(order)
rs = ReactionSys ; rs.stochiometricMatrix = [-1 1 0] ;
if order == 1, rs.k0 = 0.4 ;
else, rs.userDefinedKinetics = @(C,T) 0.01*C(1)^order ; end %#ok<INUSD>
rs.componentCp = [80 80 80] ; rs.DHref = -25000 ;
in = nirp.stream.create([0.01;0;0],300,101325,0,0.001) ;
end

function rtd = modelRtd(model,tau)
rtd = struct('origin','model','model',model,'tau',tau) ;
end

function params = commonParams(rtd,micromixing,computeHeat)
params = struct('rtd',rtd,'micromixing',micromixing, ...
    'temperatureMode','inlet','computeHeat',logical(computeHeat),'keyIndex',1) ;
end

function out = solve(in,rs,rtd,micromixing,computeHeat)
out = nirp.units.nonIdealReactor( ...
    commonParams(rtd,micromixing,computeHeat),in,rs) ;
end

function rs = examReactionSystem()
rs = ReactionSys ; rs.componentNames = {'A','B','C','D','E'} ;
rs.stochiometricMatrix = [-1 1 0 0 0;0 -1 1 0 0; ...
    -2 0 0 1 1;0 1 0 -1 -1] ;
rs.userDefinedKinetics = @(C,T) [C(1)-2*C(2),C(2), ...
    0.01*C(1)^2,0.001*C(4)*C(5)] ; %#ok<INUSD>
end
