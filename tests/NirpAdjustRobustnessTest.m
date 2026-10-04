classdef NirpAdjustRobustnessTest < matlab.unittest.TestCase
    % NirpAdjustRobustnessTest verifies safeguarded Adjust iteration.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 4, 2026. Last update: October 4, 2026
    % =========================================================================

    methods (Test)
        function pureRuleConvergesForRepresentativeFunctions(testCase)
            plateau = @(x) tanh(50*(x-0.3))-0.9*tanh(50*0.4) ;
            cases = {plateau,0.1,0,1; @(x) 1000*(x-0.73),0.2,0,1; ...
                @(x) x-0.42,0.1,0,1; @(x) exp(x)-2,0,0,2} ;
            expected = [0.3+atanh(0.9*tanh(20))/50,0.73,0.42,log(2)] ;
            for i = 1:size(cases,1)
                [actual,iterations] = NirpAdjustRobustnessTest.solve( ...
                    cases{i,1},cases{i,2},cases{i,3},cases{i,4},1e-12,60) ;
                testCase.verifyEqual(actual,expected(i),'AbsTol',1e-9) ;
                testCase.verifyLessThanOrEqual(iterations,60) ;
            end
        end

        function unsafeguardedSecantStallsOnPlateau(testCase)
            fun = @(x) tanh(50*(x-0.3))-0.9*tanh(50*0.4) ;
            first = 0.1 ; second = 0.15 ;
            pureSecant = second-fun(second)*(second-first)/ ...
                (fun(second)-fun(first)) ;
            testCase.verifyGreaterThan(pureSecant,1) ;
            testCase.verifyGreaterThan(abs(fun(second)),1) ;
        end

        function changingErrorAtSameParameterDoesNotCreateBracket(testCase)
            state = struct('minimum',0,'maximum',1,'damping',1) ;
            [~,state] = nirp.blocks.internal.adjustStep(state,0.1,-1) ;
            [next,state] = nirp.blocks.internal.adjustStep(state,0.1,1) ;
            testCase.verifyFalse(state.bracketed) ;
            testCase.verifyNotEqual(next,0.1) ;
        end

        function contradictoryEndpointInvalidatesTransientBracket(testCase)
            state = struct('minimum',0,'maximum',1,'damping',1) ;
            [~,state] = nirp.blocks.internal.adjustStep(state,0.1,-1) ;
            [~,state] = nirp.blocks.internal.adjustStep(state,0.2,1) ;
            testCase.verifyTrue(state.bracketed) ;
            [next,state] = nirp.blocks.internal.adjustStep(state,0.2,-0.5) ;
            testCase.verifyFalse(state.bracketed) ;
            testCase.verifyNotEqual(next,0.2) ;
        end

        function exhaustedBracketRestartsBoundedSearch(testCase)
            state = struct('minimum',0,'maximum',2,'damping',1, ...
                'havePrevious',true,'previous',1+eps, ...
                'previousError',1,'errorTwoAgo',-1,'bracketed',true, ...
                'left',1,'leftError',-1,'right',1+eps,'rightError',1) ;
            [next,state] = nirp.blocks.internal.adjustStep(state,1,-1) ;
            testCase.verifyFalse(state.bracketed) ;
            testCase.verifyGreaterThan(next,1) ;
            testCase.verifyLessThanOrEqual(next,2) ;
        end

        function problem20bPfrPlateauConvergesAtDefaultSettings(testCase)
            pkg = nirp.pkg.examples.problem33Gas() ;
            rs = nirp.pkg.toReactionSys(pkg) ;
            feed = nirp.pkg.feedStream(pkg,"F1") ;
            objective = @(volume) NirpAdjustRobustnessTest.pfrConversion( ...
                volume,feed,rs)-0.736642 ;
            [volume,iterations] = NirpAdjustRobustnessTest.solve( ...
                objective,0.1,0.01,1,1e-10,60) ;
            testCase.verifyEqual(volume,0.149042202,'RelTol',1e-5) ;
            testCase.verifyLessThanOrEqual(iterations,60) ;
        end
    end

    methods (Static, Access = private)
        function [current,iterations] = solve(fun,current,minimum,maximum,tolerance,limit)
            state = struct('minimum',minimum,'maximum',maximum,'damping',1) ;
            for iterations = 1:limit
                errorValue = fun(current) ;
                if abs(errorValue) <= tolerance, return, end
                [current,state] = nirp.blocks.internal.adjustStep( ...
                    state,current,errorValue) ;
            end
            error('NirpAdjustRobustnessTest:notConverged', ...
                'The adjustment did not converge in %d iterations.',limit) ;
        end

        function value = pfrConversion(volume,feed,rs)
            product = nirp.units.pfr(struct('V',volume,'D',0.1, ...
                'heatMode','Adiabatic'),feed,rs) ;
            value = (feed.F(1)-product.F(1))/feed.F(1) ;
        end
    end
end
