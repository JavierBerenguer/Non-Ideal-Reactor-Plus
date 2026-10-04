classdef NirpPackageTest < matlab.unittest.TestCase
%NIRPPACKAGETEST Tests for user-unit packages and Simulink persistence.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 2, 2026
% =========================================================================

    methods (Test)
        function newUnitCategoriesRoundTrip(testCase)
            cases = { ...
                'Power','kcal/h',7.25 ; ...
                'MolarHeatCapacity','kJ/(kmol*K)',91.3 ; ...
                'HeatTransferCoefficient','BTU/(h*ft^2*F)',12.8 ; ...
                'MassFlow','t/h',3.4} ;
            for i = 1:size(cases,1)
                category = cases{i,1} ; unit = cases{i,2} ; value = cases{i,3} ;
                si = UnitConverterHelper.convertToSI(category,value,unit) ;
                actual = UnitConverterHelper.convertFromSI(category,si,unit) ;
                testCase.verifyEqual(actual,value,'RelTol',1e-14) ;
            end
            testCase.verifyEqual(UnitConverterHelper.convertToSI( ...
                'Power',1,'kcal/h'),4184/3600,'AbsTol',1e-15) ;
            testCase.verifyEqual(UnitConverterHelper.convertToSI( ...
                'MolarHeatCapacity',1,'kJ/(kmol*K)'),1,'AbsTol',0) ;
        end

        function validationIdentifiesMalformedFields(testCase)
            pkg = nirp.pkg.examples.firstOrderLiquid() ;
            malformed = pkg ; malformed.reactions.stoich = [-1 1 0] ;
            testCase.verifyInvalidField(malformed,'reactions.stoich') ;
            malformed = pkg ; malformed.feeds(1).P.unit = "furlong" ;
            testCase.verifyInvalidField(malformed,'feeds(1).P.unit') ;
            malformed = pkg ; malformed.reactions.kinetics.type = "mystery" ;
            testCase.verifyInvalidField(malformed,'reactions.kinetics(1).type') ;
            malformed = pkg ; malformed.feeds(1).Q = [] ;
            testCase.verifyInvalidField(malformed,'feeds(1).Q') ;
        end

        function powerLawSecondOrderMatchesSI(testCase)
            pkg = nirp.pkg.examples.firstOrderLiquid() ;
            pkg.reactions.kinetics.k0 = 0.6 ;
            pkg.reactions.kinetics.orders = [2 0] ;
            rs = nirp.pkg.toReactionSys(pkg) ;
            concentrations = [250 0; 1000 20; 3300 150] ;
            for i = 1:size(concentrations,1)
                C = concentrations(i,:) ; T = 280+30*i ;
                rs = rs.computeRate(C,T) ;
                expected = 1e-5*C(1)^2 ;
                testCase.verifyEqual(rs.r_i,expected,'RelTol',1e-12) ;
            end
        end

        function problem59MultiplePowerLaws(testCase)
            pkg = NirpPackageTest.kineticPackage(3,[-1 1 0;-1 0 0.5], ...
                "mol/L","s") ;
            ea = struct('value',0,'unit',"J/mol") ;
            pkg.reactions.kinetics = struct( ...
                'type',{"powerlaw","powerlaw"},'k0',{3,0.4}, ...
                'Ea',{ea,ea},'orders',{[2 0 0],[1 0 0]}, ...
                'reverse',{[],[]},'expression',{"",""}) ;
            rs = nirp.pkg.toReactionSys(pkg) ;
            for CA = [10 350 1100]
                rs = rs.computeRate([CA 0 0],330) ;
                testCase.verifyEqual(rs.r_i,[0.003*CA^2 0.4*CA], ...
                    'RelTol',1e-12) ;
            end
        end

        function problem62Reversible(testCase)
            pkg = NirpPackageTest.kineticPackage(2,[-1 0.5], ...
                "mol/L","min") ;
            ea = struct('value',0,'unit',"J/mol") ;
            reverse = struct('k0',0.6,'Ea',ea,'orders',[0 0.5]) ;
            pkg.reactions.kinetics = struct('type',"reversible", ...
                'k0',2,'Ea',ea,'orders',[1 0],'reverse',reverse, ...
                'expression',"") ;
            rs = nirp.pkg.toReactionSys(pkg) ;
            concentrationCases = [1000 250; 400 1600; 50 25] ;
            for i = 1:size(concentrationCases,1)
                C = concentrationCases(i,:) ;
                expected = (2*(C(1)/1000)-0.6*(C(2)/1000)^0.5)*1000/60 ;
                rs = rs.computeRate(C,400) ;
                testCase.verifyEqual(rs.r_i,expected,'RelTol',1e-12) ;
            end
        end

        function problem58Expression(testCase)
            pkg = NirpPackageTest.kineticPackage(2,[-1 1],"mol/L","h") ;
            pkg.reactions.kinetics = struct('type',"expression",'k0',[], ...
                'Ea',[],'orders',[],'reverse',[], ...
                'expression',"0.5*concentration(1)/(1+0.5*concentration(1))") ;
            rs = nirp.pkg.toReactionSys(pkg) ;
            for CA = [20 1000 4000]
                expected = (0.5*(CA/1000)/(1+0.5*(CA/1000)))*1000/3600 ;
                rs = rs.computeRate([CA 0],300) ;
                testCase.verifyEqual(rs.r_i,expected,'RelTol',1e-12) ;
            end
        end

        function namedFunctionKinetics(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.PathFixture
            folderFixture = testCase.applyFixture(TemporaryFolderFixture) ;
            testCase.applyFixture(PathFixture(folderFixture.Folder)) ;
            file = fullfile(folderFixture.Folder,'nirpTestRates.m') ;
            fid = fopen(file,'w') ;
            cleanup = onCleanup(@() fclose(fid)) ;
            fprintf(fid,['function r = nirpTestRates(concentration,T)\n' ...
                'r = [0.2*concentration(1), T/10000];\nend\n']) ;
            clear cleanup
            pkg = NirpPackageTest.kineticPackage(2,[-1 1;-1 0], ...
                "mol/L","min") ;
            pkg.reactions.kinetics = struct('type',"function",'k0',[], ...
                'Ea',[],'orders',[],'reverse',[], ...
                'expression',"nirpTestRates") ;
            rs = nirp.pkg.toReactionSys(pkg) ;
            rs = rs.computeRate([500 0],350) ;
            expected = [0.2*0.5 350/10000]*1000/60 ;
            testCase.verifyEqual(rs.r_i,expected,'RelTol',1e-12) ;
        end

        function feedBasesAndConversions(testCase)
            pkg = nirp.pkg.examples.firstOrderLiquid() ;
            template = pkg.feeds ;
            molar = template ;
            molar.name = "molar" ; molar.values = [3.6 7.2] ;
            molar.valuesUnit = "kmol/h" ;
            concentrations = template ; concentrations.name = "conc" ;
            concentrations.basis = "concentrations" ;
            concentrations.values = [1 2] ; concentrations.valuesUnit = "mol/L" ;
            concentrations.Q = struct('value',60,'unit',"L/min") ;
            total = template ; total.name = "gas" ; total.phase = "G" ;
            total.T = struct('value',25,'unit',"C") ;
            total.P = struct('value',1,'unit',"atm") ;
            total.basis = "totalAndFractions" ;
            total.values = [3.6 0.25 0.75] ; total.valuesUnit = "kmol/h" ;
            total.Q = struct('value',999,'unit',"L/s") ;
            pkg.feeds = [molar concentrations total] ;
            s1 = nirp.pkg.feedStream(pkg,"molar") ;
            testCase.verifyEqual(s1.F,[1;2],'AbsTol',1e-15) ;
            testCase.verifyEqual(s1.T,300,'AbsTol',1e-12) ;
            testCase.verifyEqual(s1.P,101325,'AbsTol',0) ;
            testCase.verifyEqual(s1.Q,1e-3,'AbsTol',1e-18) ;
            s2 = nirp.pkg.feedStream(pkg,"conc") ;
            testCase.verifyEqual(s2.F,[1;2],'AbsTol',1e-14) ;
            s3 = nirp.pkg.feedStream(pkg,"gas") ;
            testCase.verifyEqual(s3.F,[0.25;0.75],'AbsTol',1e-15) ;
            testCase.verifyEqual(s3.Q,sum(s3.F)*8.314*s3.T/s3.P, ...
                'AbsTol',1e-15) ;
            reference = nirp.pkg.feedStream( ...
                nirp.pkg.examples.firstOrderLiquid(),"F1") ;
            testCase.verifyEqual(reference,nirp.stream.create( ...
                [1;0],300,101325,0,1e-3)) ;
        end

        function firstOrderEndToEndAdiabatic(testCase)
            pkg = nirp.pkg.examples.firstOrderLiquid() ;
            rs = nirp.pkg.toReactionSys(pkg) ;
            feed = nirp.pkg.feedStream(pkg,"F1") ;
            [out,info] = nirp.units.cstr(struct('V',0.1, ... % T-101 base data: k = 0.01 1/s, V = 0.1 m^3
                'heatMode','Adiabatic'),feed,rs) ;
            conversion = (feed.F(1)-out.F(1))/feed.F(1) ;
            testCase.verifyEqual(conversion,0.5,'AbsTol',1e-8) ;
            testCase.verifyEqual(out.T,550,'AbsTol',1e-6) ;
            testCase.verifyEqual(info.status,1) ;
        end

        function problem40ParallelPackage(testCase)
            pkg = nirp.pkg.examples.problem40Gas() ;
            rs = nirp.pkg.toReactionSys(pkg) ;
            feed = nirp.pkg.feedStream(pkg,"F1") ;
            [branches,~] = nirp.units.splitter( ...
                struct('fractions',[0.5 0.5]),feed,rs) ;
            [out1,~] = nirp.units.cstr(struct('V',0.4),branches{1},rs) ;
            [out2,~] = nirp.units.cstr(struct('V',0.4),branches{2},rs) ;
            [out,~] = nirp.units.mixer([], {out1,out2},rs) ;
            conversion = (feed.F(1)-out.F(1))/feed.F(1) ;
            testCase.verifyEqual(conversion,0.578473757692,'AbsTol',1e-6) ;
        end

        function busAndDictionaryRoundTrip(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture) ;
            cleanup = onCleanup(@() Simulink.data.dictionary.closeAll('-discard')) ;
            pkg = NirpPackageTest.kineticPackage(3,[-1 1 0], ...
                "mol/m^3","s") ;
            bus = nirp.pkg.streamBus(pkg) ;
            testCase.verifyEqual({bus.Elements.Name}, ...
                {'F','T','P','phase','Q','status'}) ;
            testCase.verifyEqual(bus.Elements(1).Dimensions,[3 1]) ;
            file = fullfile(fixture.Folder,'package.sldd') ;
            nirp.pkg.writeDictionary(pkg,file) ;
            Simulink.data.dictionary.closeAll('-discard') ;
            testCase.verifyTrue(isequal(nirp.pkg.readDictionary(file),pkg)) ;
            pkg2 = nirp.pkg.examples.firstOrderLiquid() ;
            nirp.pkg.writeDictionary(pkg2,file) ;
            dictionary = Simulink.data.dictionary.open(file) ;
            section = getSection(dictionary,'Design Data') ;
            storedBus = getValue(getEntry(section,'NirpStream')) ;
            testCase.verifyEqual(storedBus.Elements(1).Dimensions,[2 1]) ;
            testCase.verifyTrue(isequal(getValue( ...
                getEntry(section,'nirpPackage')),pkg2)) ;
            close(dictionary) ;
            clear cleanup
            Simulink.data.dictionary.closeAll('-discard') ;
        end
    end

    methods (Access = private)
        function verifyInvalidField(testCase,pkg,field)
            try
                nirp.pkg.validate(pkg) ;
                testCase.assertFail('Expected validation to fail.') ;
            catch exception
                testCase.verifyEqual(exception.identifier,'nirp:pkg:invalid') ;
                testCase.verifySubstring(exception.message,field) ;
            end
        end
    end

    methods (Static, Access = private)
        function pkg = kineticPackage(nComp,stoich,concentrationUnit,timeUnit)
            pkg.meta = struct('formatVersion',1,'name',"Kinetics test") ;
            cp = struct('type',"constant",'value',100,'unit',"J/(mol*K)") ;
            component = struct('name',"",'Mw',[],'cp',cp,'hf',[]) ;
            pkg.components = repmat(component,1,nComp) ;
            for i = 1:nComp
                pkg.components(i).name = "C"+i ;
            end
            nReactions = size(stoich,1) ;
            pkg.reactions.stoich = stoich ;
            pkg.reactions.DH = struct('value',zeros(1,nReactions), ...
                'unit',"J/mol") ;
            pkg.reactions.Tref = struct('value',298.15,'unit',"K") ;
            pkg.reactions.rateUnits = struct('concentration', ...
                concentrationUnit,'time',timeUnit) ;
            ea = struct('value',0,'unit',"J/mol") ;
            pkg.reactions.kinetics = repmat(struct('type',"powerlaw", ...
                'k0',1,'Ea',ea,'orders',ones(1,nComp), ...
                'reverse',[],'expression',""),1,nReactions) ;
            pkg.feeds = struct('name',"F1",'phase',"L", ...
                'T',struct('value',298.15,'unit',"K"), ...
                'P',struct('value',101325,'unit',"Pa"), ...
                'basis',"molarFlows",'values',[1 zeros(1,nComp-1)], ...
                'valuesUnit',"mol/s", ...
                'Q',struct('value',1e-3,'unit',"m^3/s")) ;
        end
    end
end
