classdef NirpApiTest < matlab.unittest.TestCase
    % NirpApiTest verifies the common SI stream and unit-operation API.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 1, 2026. Last update: October 1, 2026
    % =========================================================================

    methods (Test)
        function streamCreationValidationAndConcentration(testCase)
            s = nirp.stream.create([1;0],300,101325,0,1e-3) ;
            testCase.verifyEqual(fieldnames(s), ...
                {'F';'T';'P';'phase';'Q';'status'}) ;
            testCase.verifyEqual(nirp.stream.concentration(s),[1000;0], ...
                'AbsTol',0) ;
            testCase.verifyTrue(nirp.stream.isValid(s)) ;
            testCase.verifyError(@() nirp.stream.create([-1;0], ...
                300,101325,0,1e-3),'nirp:stream:invalid') ;
            testCase.verifyError(@() nirp.stream.create([1;0], ...
                0,101325,0,1e-3),'nirp:stream:invalid') ;
            testCase.verifyError(@() nirp.stream.create([1;0], ...
                300,101325,2,1e-3),'nirp:stream:invalid') ;
            testCase.verifyError(@() nirp.stream.create([1;0], ...
                300,101325,0,0),'nirp:stream:invalid') ;
            testCase.verifyError(@() nirp.stream.concentration( ...
                nirp.stream.empty(2,300,101325,0)), ...
                'nirp:stream:zeroFlow') ;
        end

        function streamGasRefreshAndRoundTrips(testCase)
            gas = nirp.stream.create([2;1],400,2e5,1,999) ;
            expectedQ = 3*8.314*400/2e5 ;
            testCase.verifyEqual(gas.Q,expectedQ,'RelTol',1e-12) ;
            gas.T = 500 ;
            gas.Q = 3*8.314*400/2e5 ;
            gas = nirp.stream.refresh(gas) ;
            testCase.verifyEqual(gas.Q,3*8.314*500/2e5,'RelTol',1e-12) ;

            liquid = nirp.stream.create([1;2],310,150000,0,2e-3) ;
            roundTrips = {liquid,gas} ;
            for i = 1:numel(roundTrips)
                actual = nirp.stream.fromStream( ...
                    nirp.stream.toStream(roundTrips{i})) ;
                NirpApiTest.verifyStream(testCase,actual,roundTrips{i},1e-12) ;
            end

            legacy = Stream ;
            legacy.phase = 'L' ;
            legacy.molarFlow = [] ;
            legacy.concentration = [500 250] ; % mol/m^3
            legacy.volumetricFlow = 2e-3 ; % m^3/s
            legacy.T = 300 ;
            legacy.P = 101325 ;
            derived = nirp.stream.fromStream(legacy) ;
            testCase.verifyEqual(derived.F,[1;0.5],'AbsTol',0) ;
        end

        function cstrApiMatchesClassAllModes(testCase)
            [in,rs] = NirpApiTest.baseCase() ;
            cases = { ...
                struct('V',0.1,'heatMode','Isothermal'), ...
                struct('V',0.1,'heatMode','Adiabatic'), ...
                struct('V',0.1,'heatMode','Other','U',1000,'A',1, ...
                    'utilityTin',290), ...
                struct('V',0.1,'heatMode','Specified T','specifiedT',350), ...
                struct('V',0.1,'heatMode','Specified Q','specifiedQ',0)} ;
            for i = 1:numel(cases)
                params = cases{i} ;
                [actual,info] = nirp.units.cstr(params,in,rs) ;
                direct = NirpApiTest.cstrFromParams(params) ;
                [expected,direct] = direct.compute_output( ...
                    nirp.stream.toStream(in),rs) ;
                testCase.verifyEqual(actual.F,expected.molarFlow(:), ...
                    'RelTol',1e-12) ;
                testCase.verifyEqual(actual.T,expected.T,'RelTol',1e-12) ;
                testCase.verifyEqual(info.heatDuty,direct.heatDuty, ...
                    'RelTol',1e-12) ;
                if strcmp(params.heatMode,'Adiabatic')
                    testCase.verifyEqual(actual.T,550,'RelTol',1e-8) ;
                end
            end
        end

        function pfrApiMatchesClassByVolumeAndLength(testCase)
            [in,rs] = NirpApiTest.baseCase() ;
            modes = {'Isothermal','Adiabatic'} ;
            for i = 1:numel(modes)
                volumeParams = struct('V',0.1,'D',0.1,'nTubes',1, ...
                    'heatMode',modes{i}) ;
                [actual,info] = nirp.units.pfr(volumeParams,in,rs) ;
                direct = NirpApiTest.pfrFromParams(volumeParams) ;
                [expected,direct] = direct.compute_output( ...
                    nirp.stream.toStream(in),rs) ;
                testCase.verifyEqual(actual.F,expected.molarFlow(:), ...
                    'RelTol',1e-10) ;
                testCase.verifyEqual(actual.T,expected.T,'RelTol',1e-10) ;
                testCase.verifyEqual(info.heatDuty,direct.heatDuty, ...
                    'RelTol',1e-10) ;
                if strcmp(modes{i},'Adiabatic')
                    testCase.verifyEqual(actual.T,616.0602794,'RelTol',1e-6) ;
                end

                lengthParams = rmfield(volumeParams,'V') ;
                lengthParams.L = direct.L ;
                lengthActual = nirp.units.pfr(lengthParams,in,rs) ;
                testCase.verifyEqual(lengthActual.F,actual.F,'RelTol',1e-10) ;
                testCase.verifyEqual(lengthActual.T,actual.T,'RelTol',1e-10) ;
            end
        end

        function idealReactorsMatchNonidealReferenceSolvers(testCase)
            [in,rs] = NirpApiTest.baseCase() ;
            systems = {rs,NirpApiTest.secondOrderSystem()} ;
            for i = 1:numel(systems)
                system = systems{i} ;
                C0 = in.F'/in.Q ;
                tau = 0.1/in.Q ;
                cstrOut = nirp.units.cstr(struct('V',0.1),in,system) ;
                pfrOut = nirp.units.pfr( ...
                    struct('V',0.1,'D',0.1),in,system) ;
                cstrReference = TanksInSeries.solve_sequential( ...
                    1,system,C0,tau) ;
                pfrReference = TanksInSeries.solve_PFR(system,C0,tau) ;
                testCase.verifyEqual(cstrOut.F'/in.Q,cstrReference, ...
                    'RelTol',1e-8) ;
                testCase.verifyEqual(pfrOut.F'/in.Q,pfrReference, ...
                    'RelTol',1e-8) ;
            end
        end

        function mixerBalancesEnthalpyAndRejectsMixedPhases(testCase)
            rs = NirpApiTest.variableCpSystem() ;
            first = nirp.stream.create(1,300,2e5,0,1e-3) ;
            second = nirp.stream.create(1,400,1.5e5,0,2e-3) ;
            out = nirp.units.mixer([], {first,second},rs) ;
            testCase.verifyEqual(out.T,352.268050855,'RelTol',1e-9) ;
            testCase.verifyEqual(out.F,2,'AbsTol',0) ;
            testCase.verifyEqual(out.Q,3e-3,'AbsTol',0) ;
            testCase.verifyEqual(out.P,1.5e5,'AbsTol',0) ;

            firstGas = nirp.stream.create(1,300,2e5,1) ;
            secondGas = nirp.stream.create(1,400,1.5e5,1) ;
            gas = nirp.units.mixer([], {firstGas,secondGas},rs) ;
            testCase.verifyEqual(gas.Q,sum(gas.F)*8.314*gas.T/gas.P, ...
                'RelTol',1e-12) ;
            testCase.verifyError(@() nirp.units.mixer( ...
                [],{first,firstGas},rs),'nirp:units:phaseMismatch') ;
        end

        function splitterConservesFlowAndValidatesFractions(testCase)
            [in,rs] = NirpApiTest.baseCase() ;
            out = nirp.units.splitter(struct('fractions',[0.3 0.7]),in,rs) ;
            testCase.verifyEqual(out{1}.F,in.F*0.3,'AbsTol',0) ;
            testCase.verifyEqual(out{2}.F,in.F*0.7,'AbsTol',0) ;
            testCase.verifyEqual(out{1}.F+out{2}.F,in.F,'AbsTol',0) ;
            testCase.verifyEqual(out{1}.Q+out{2}.Q,in.Q,'AbsTol',0) ;
            testCase.verifyError(@() nirp.units.splitter( ...
                struct('fractions',[0.2 0.7]),in,rs), ...
                'nirp:units:invalidFractions') ;
        end

        function heaterHandlesTemperatureDutyPressureAndGas(testCase)
            variableRs = NirpApiTest.variableCpSystem() ;
            liquid = nirp.stream.create(1,300,101325,0,1e-3) ;
            [heated,info] = nirp.units.heater( ...
                struct('mode','Outlet T','Tout',400),liquid,variableRs) ;
            testCase.verifyEqual(heated.T,400,'AbsTol',0) ;
            testCase.verifyEqual(info.heatDuty,5500,'RelTol',1e-12) ;
            recovered = nirp.units.heater( ...
                struct('mode','Duty','Q',5500),liquid,variableRs) ;
            testCase.verifyEqual(recovered.T,400,'RelTol',1e-9) ;

            [base,rs] = NirpApiTest.baseCase() ;
            [constant,info] = nirp.units.heater(struct( ...
                'mode','Outlet T','Tout',400,'dP',1e4),base,rs) ;
            testCase.verifyEqual(info.heatDuty,10000,'AbsTol',0) ;
            testCase.verifyEqual(constant.P,base.P-1e4,'AbsTol',0) ;
            gas = nirp.stream.create([1;0],300,101325,1) ;
            gas = nirp.units.heater(struct( ...
                'mode','Outlet T','Tout',400,'dP',1e4),gas,rs) ;
            testCase.verifyEqual(gas.Q,sum(gas.F)*8.314*gas.T/gas.P, ...
                'RelTol',1e-12) ;
        end

        function statusPropagationAndEmptyShortCircuit(testCase)
            [in,rs] = NirpApiTest.baseCase() ;
            in.status = -1 ;
            [out,info] = nirp.units.cstr(struct('V',0.1),in,rs) ;
            testCase.verifyEqual(out.status,-1) ;
            testCase.verifyEqual(info.status,-1) ;
            empty = nirp.stream.empty(2,300,101325,0) ;
            [out,info] = nirp.units.cstr(struct(),empty,rs) ;
            testCase.verifyEqual(out.status,0) ;
            testCase.verifyEqual(out.F,zeros(2,1),'AbsTol',0) ;
            testCase.verifyEqual(info.status,0) ;

            [warningInput,warningRs] = NirpApiTest.problem32Case() ; %#ok<ASGLU>
            warningParams = struct('V',18e-3,'heatMode','Adiabatic', ...
                'initialTemperatureGuess',-1e9) ; %#ok<NASGU>
            commandOutput = evalc(['[warningOut,warningInfo] = ' ...
                'nirp.units.cstr(warningParams,warningInput,warningRs);']) ;
            testCase.verifyEqual(commandOutput,'') ;
            testCase.verifyEqual(warningOut.status,-1) ;
            testCase.verifyEqual(warningInfo.status,-1) ;
            testCase.verifyEqual(warningInfo.warnings,{'CSTR:notConverged'}) ;
        end

        function problem32AndNoConsoleOutput(testCase)
            [in,rs] = NirpApiTest.problem32Case() ; %#ok<ASGLU>
            params = struct('V',18e-3,'heatMode','Adiabatic', ...
                'initialTemperatureGuess',450) ; %#ok<NASGU>
            commandOutput = evalc( ...
                '[out,info] = nirp.units.cstr(params,in,rs);') ;
            conversion = 1-out.F(1)/in.F(1) ;
            testCase.verifyEqual(conversion,0.9851403691,'RelTol',1e-6) ;
            testCase.verifyEqual(out.T,445.77105537,'RelTol',1e-6) ;
            testCase.verifyEqual(commandOutput,'') ;
            testCase.verifyEqual(info.message,'') ;

            [base,baseRs] = NirpApiTest.baseCase() ;
            quietOutput = evalc(['nirp.units.pfr(' ...
                'struct(''V'',0.1,''D'',0.1),base,baseRs); ' ...
                'nirp.units.mixer([], {base,base},baseRs); ' ...
                'nirp.units.splitter(struct(''fractions'',[0.5 0.5]),' ...
                'base,baseRs); nirp.units.heater(struct(''mode'',' ...
                '''Outlet T'',''Tout'',350),base,baseRs);']) ;
            testCase.verifyEqual(quietOutput,'') ;
            testCase.verifyError(@() nirp.units.cstr(struct(),base,baseRs), ...
                'nirp:units:missingParameter') ;
        end
    end

    methods (Static, Access = private)
        function [in,rs] = baseCase()
            in = nirp.stream.create([1;0],300,101325,0,1e-3) ;
            rs = ReactionSys ;
            rs.stochiometricMatrix = [-1 1] ;
            rs.k0 = 0.01 ;
            rs.Ea = 0 ;
            rs.componentCp = [100 100] ;
            rs.DHref = -50000 ;
            rs.componentMw = [18 18] ;
        end

        function rs = secondOrderSystem()
            rs = ReactionSys ;
            rs.stochiometricMatrix = [-2 1] ;
            rs.userDefinedKinetics = @(C,T) 1e-5*C(1)^2 ;
            rs.componentCp = [100 100] ;
            rs.DHref = -50000 ;
        end

        function rs = variableCpSystem()
            rs = ReactionSys ;
            rs.stochiometricMatrix = -1 ;
            rs.componentCp = struct('option','Cp = f(T)', ...
                'Function',{{@(T) 20+0.1*T}}) ;
        end

        function [in,rs] = problem32Case()
            in = nirp.stream.create([0.18;0],298,101325,0,6e-5) ;
            rs = ReactionSys ;
            rs.stochiometricMatrix = [-1 1] ;
            rs.k0 = 4.48e6 ;
            rs.Ea = 7500*8.314 ;
            rs.componentCp = [1393.333333 1393.333333] ;
            rs.DHref = -209000 ;
        end

        function reactor = cstrFromParams(params)
            reactor = CSTR ;
            reactor.V = params.V ;
            reactor.heatMode = params.heatMode ;
            if isfield(params,'specifiedT'), reactor.specifiedT = params.specifiedT ; end
            if isfield(params,'specifiedQ'), reactor.specifiedQ = params.specifiedQ ; end
            if isfield(params,'U'), reactor.U = params.U ; end
            if isfield(params,'A'), reactor.heatTransferArea = params.A ; end
            if isfield(params,'utilityTin')
                reactor.inletUtilityTemperature = params.utilityTin ;
            end
        end

        function reactor = pfrFromParams(params)
            reactor = PFR ;
            reactor.L = [] ;
            reactor.V = params.V ;
            reactor.diameterTubes = params.D ;
            reactor.nTubes = params.nTubes ;
            reactor.heatMode = params.heatMode ;
        end

        function verifyStream(testCase,actual,expected,tolerance)
            testCase.verifyEqual(actual.F,expected.F,'RelTol',tolerance) ;
            testCase.verifyEqual(actual.T,expected.T,'RelTol',tolerance) ;
            testCase.verifyEqual(actual.P,expected.P,'RelTol',tolerance) ;
            testCase.verifyEqual(actual.phase,expected.phase) ;
            testCase.verifyEqual(actual.Q,expected.Q,'RelTol',tolerance) ;
            testCase.verifyEqual(actual.status,expected.status) ;
        end
    end
end
