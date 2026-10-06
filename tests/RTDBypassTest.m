classdef RTDBypassTest < matlab.unittest.TestCase
    % RTDBypassTest verifies the CSTR bypass RTD models (E-004).
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 6, 2026. Last update: October 6, 2026
    % =========================================================================

    properties (TestParameter)
        beta = {0, 0.1, 0.2, 0.4, 0.8}
    end

    methods (Test)
        function analyticalVarianceIncludesBypassTerm(testCase,beta)
            tau = 10 ; % s
            tauS = tau/(1-beta) ; % s
            obj = RTD.cstr_with_bypass(tau,beta) ;

            testCase.verifyEqual(obj.tau,tau,'RelTol',1e-12) ;
            testCase.verifyEqual(obj.sigma2,(1-beta)*(1+beta)*tauS^2, ...
                'RelTol',1e-12) ;
        end

        function numericalCurveMatchesAnalyticalMoments(testCase,beta)
            tau = 10 ; % s
            tauS = tau/(1-beta) ; % s
            obj = RTD.cstr_with_bypass(tau,beta) ;

            mean = trapz(obj.t,obj.t.*obj.Et) ; % s
            variance = trapz(obj.t,(obj.t-mean).^2.*obj.Et) ; % s^2

            testCase.verifyEqual(mean,tau,'RelTol',1e-2) ;
            testCase.verifyEqual(variance,(1-beta)*(1+beta)*tauS^2, ...
                'RelTol',2e-2) ;
        end

        function numericalCurveCarriesTheWholeBypassFraction(testCase,beta)
            tau = 10 ; % s
            tauS = tau/(1-beta) ; % s
            obj = RTD.cstr_with_bypass(tau,beta) ;

            width = max(tau/200,2*median(diff(obj.t))) ; % width used by RTD
            early = obj.t <= 10*width ; % ten widths of the delta approximation
            earlyMass = trapz(obj.t(early),obj.Et(early)) ;
            stirredMass = (1-beta)*(1-exp(-max(obj.t(early))/tauS)) ;

            testCase.verifyEqual(earlyMass-stirredMass,beta,'AbsTol',5e-3) ;
        end

        function deadVolumeVariantUsesSameMoments(testCase)
            tau = 10 ; alpha = 0.8 ; bypass = 0.2 ;
            tauS = alpha*tau/(1-bypass) ; % s
            obj = RTD.cstr_with_bypass_and_dead(tau,alpha,bypass) ;

            mean = trapz(obj.t,obj.t.*obj.Et) ; % s
            variance = trapz(obj.t,(obj.t-mean).^2.*obj.Et) ; % s^2

            testCase.verifyEqual(obj.tau,alpha*tau,'RelTol',1e-12) ;
            testCase.verifyEqual(obj.sigma2,(1-bypass)*(1+bypass)*tauS^2, ...
                'RelTol',1e-12) ;
            testCase.verifyEqual(mean,alpha*tau,'RelTol',1e-2) ;
            testCase.verifyEqual(variance,obj.sigma2,'RelTol',2e-2) ;
        end
    end
end
