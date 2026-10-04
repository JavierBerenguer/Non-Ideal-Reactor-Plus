classdef CstrRobustnessTest < matlab.unittest.TestCase
    % CstrRobustnessTest verifies scaled-residual CSTR convergence.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 3, 2026. Last update: October 3, 2026
    % =========================================================================

    methods (Test)
        function problem30ConvergesWithAndWithoutEstimate(testCase)
            [feed,rs] = CstrRobustnessTest.problem30() ;
            baseParams = struct('V',1.136,'heatMode','Adiabatic') ;

            [withoutEstimate,info] = nirp.units.cstr(baseParams,feed,rs) ;
            testCase.verifyEqual(info.status,1) ;
            testCase.verifyEqual(withoutEstimate.T,340.6551,'AbsTol',0.01) ;
            testCase.verifyEqual(CstrRobustnessTest.conversion( ...
                feed,withoutEstimate),0.852987,'AbsTol',1e-5) ;

            estimatedParams = baseParams ;
            estimatedParams.initialTemperatureGuess = 340 ;
            [withEstimate,info] = nirp.units.cstr(estimatedParams,feed,rs) ;
            testCase.verifyEqual(info.status,1) ;
            testCase.verifyEqual(withEstimate.T,340.6551,'AbsTol',0.01) ;
            testCase.verifyEqual(CstrRobustnessTest.conversion( ...
                feed,withEstimate),0.852987,'AbsTol',1e-5) ;
        end

        function problem27TemperatureSweepIsContinuous(testCase)
            rs = CstrRobustnessTest.problem27ReactionSystem() ;
            params = struct('V',0.2,'heatMode','Other','U',300, ...
                'A',9,'utilityTin',273) ;
            inletTemperatures = 285:305 ; % K
            conversions = zeros(size(inletTemperatures)) ;
            for i = 1:numel(inletTemperatures)
                feed = CstrRobustnessTest.problem27Feed(inletTemperatures(i)) ;
                [product,info] = nirp.units.cstr(params,feed,rs) ;
                testCase.verifyEqual(info.status,1,sprintf( ...
                    'CSTR failed for P27 inlet temperature %.1f K.', ...
                    inletTemperatures(i))) ;
                conversions(i) = CstrRobustnessTest.conversion(feed,product) ;
            end
            testCase.verifyTrue(all(diff(conversions) > 0), ...
                'P27 conversion must increase monotonically with inlet temperature.') ;

            feed = CstrRobustnessTest.problem27Feed(298.5571) ;
            [product,info] = nirp.units.cstr(params,feed,rs) ;
            testCase.verifyEqual(info.status,1) ;
            testCase.verifyEqual(CstrRobustnessTest.conversion( ...
                feed,product),0.8,'AbsTol',2e-4) ;
        end

        function problem31SelectsLowTemperatureState(testCase)
            [feed,rs] = CstrRobustnessTest.problem30() ;
            params = struct('V',1.136,'heatMode','Other','U',567.7, ...
                'A',3.7,'utilityTin',302.65) ;

            [product,info] = nirp.units.cstr(params,feed,rs) ;

            testCase.verifyEqual(info.status,1) ;
            testCase.verifyEqual(product.T,311.5865,'AbsTol',0.01) ;
            testCase.verifyEqual(CstrRobustnessTest.conversion( ...
                feed,product),0.326500,'AbsTol',1e-5) ;
        end

        function problem45bRemainsRobust(testCase)
            rs = CstrRobustnessTest.problem45ReactionSystem() ;
            params = struct('V',0.250480335,'heatMode','Adiabatic') ;
            inletTemperatures = 335:2:355 ; % K
            for inletTemperature = inletTemperatures
                feed = CstrRobustnessTest.problem45Feed(inletTemperature) ;
                [~,info] = nirp.units.cstr(params,feed,rs) ;
                testCase.verifyEqual(info.status,1,sprintf( ...
                    'CSTR failed for P45b inlet temperature %.1f K.', ...
                    inletTemperature)) ;
            end

            feed = CstrRobustnessTest.problem45Feed(346.8439) ;
            [product,info] = nirp.units.cstr(params,feed,rs) ;
            testCase.verifyEqual(info.status,1) ;
            testCase.verifyEqual(product.T,368.15,'AbsTol',0.01) ;
        end
    end

    methods (Static, Access = private)
        function [feed,rs] = problem30()
            temperature = 24+273.15 ; % K
            pressure = 101325 ; % Pa
            firstFlow = [1134/58.08 0 0 32.6]'*1000/3600 ; % mol/s
            firstQ = (1134/0.859+32.6*32.04/0.7914)/1000/3600 ; % m^3/s
            secondFlow = [0 364.14 0 0]'*1000/3600 ; % mol/s
            secondQ = (364.14*18.02/0.9941)/1000/3600 ; % m^3/s
            first = nirp.stream.create(firstFlow,temperature,pressure,0,firstQ) ;
            second = nirp.stream.create(secondFlow,temperature,pressure,0,secondQ) ;

            rs = ReactionSys ;
            rs.stochiometricMatrix = [-1 -1 1 0] ;
            rs.userDefinedKinetics = @(concentration,T) ...
                (16.96e12/3600)*exp(-9064/T)*concentration(1) ;
            rs.componentCp = [35 18 46 19.5]*4.184 ; % J/(mol*K)
            rs.DHref = -84663.7 ; % J/mol
            rs.Tref = 293.15 ; % K
            [feed,info] = nirp.units.mixer(struct(),{first,second},rs) ;
            assert(info.status == 1) ;
        end

        function rs = problem27ReactionSystem()
            referenceTemperature = 313.15 ; % K
            activationEnergy = 8.314*log(1.421/1.127) / ...
                (1/referenceTemperature-1/323.15) ; % J/mol
            rateAtReference = 1.127/60 ; % 1/s
            rs = ReactionSys ;
            rs.stochiometricMatrix = [-1 1] ;
            rs.k0 = rateAtReference/exp( ...
                -activationEnergy/(8.314*referenceTemperature)) ; % 1/s
            rs.Ea = activationEnergy ;
            rs.componentCp = [180 180] ; % J/(mol*K)
            rs.DHref = -22500 ; % J/mol
            rs.Tref = 298.15 ; % K
        end

        function feed = problem27Feed(temperature)
            feed = nirp.stream.create([1000/60 0],temperature,101325,0, ...
                0.1/60) ;
        end

        function rs = problem45ReactionSystem()
            rs = ReactionSys ;
            rs.stochiometricMatrix = [-1 1] ;
            rs.k0 = 4e6 ; % 1/s
            rs.Ea = 7900*8.314 ; % J/mol
            rs.componentCp = [4200 4200] ; % J/(mol*K)
            rs.DHref = -167000 ; % J/mol
            rs.Tref = 298.15 ; % K
        end

        function feed = problem45Feed(temperature)
            feed = nirp.stream.create([0.416 0],temperature,101325,0, ...
                0.416e-3) ;
        end

        function value = conversion(feed,product)
            value = (feed.F(1)-product.F(1))/feed.F(1) ;
        end
    end
end
