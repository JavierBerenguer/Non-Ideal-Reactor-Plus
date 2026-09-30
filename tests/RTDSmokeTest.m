classdef RTDSmokeTest < matlab.unittest.TestCase
    % RTDSmokeTest verifies the basic behavior of the RTD class.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: September 30, 2026. Last update: September 30, 2026
    % =========================================================================

    methods (Test)
        function computesNumericalCSTRMoments(testCase)
            tau = 5 ; % s
            t = linspace(0, 20 * tau, 4001) ; % s
            Et = exp(-t / tau) / tau ; % 1/s

            obj = RTD(t, Et) ;

            testCase.verifyEqual(obj.tau, tau, 'RelTol', 1e-3) ;
            testCase.verifyEqual(obj.sigma2, tau^2, 'RelTol', 1e-2) ;
        end

        function normalizesDistribution(testCase)
            tau = 5 ; % s
            t = linspace(0, 20 * tau, 4001) ; % s
            Et = 3 * exp(-t / tau) / tau ; % 1/s

            obj = RTD(t, Et) ;

            testCase.verifyEqual(trapz(obj.t, obj.Et), 1, 'AbsTol', 1e-9) ;
        end

        function generatesTanksInSeriesDistribution(testCase)
            obj = RTD.tanks_in_series(4, 10) ;

            testCase.verifyEqual(trapz(obj.t, obj.Et), 1, 'AbsTol', 1e-3) ;
            testCase.verifyEqual(obj.tau, 10, 'RelTol', 1e-12) ;
            testCase.verifyEqual(obj.sigma2, 25, 'RelTol', 1e-12) ;
        end

        function rejectsInvalidInputs(testCase)
            testCase.verifyError(@() RTD(0:2, [1 1]), ?MException) ;
            testCase.verifyError(@() RTD([-1 0 1], [1 1 1]), ?MException) ;
        end
    end
end
