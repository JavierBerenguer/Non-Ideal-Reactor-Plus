classdef (SharedTestFixtures={nirptest.ExamplesFixture}) ...
        NirpCollectionProblems6Test < matlab.unittest.TestCase
    % NirpCollectionProblems6Test verifies problems 16 and 35 (T-135).
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 9, 2026. Last update: October 9, 2026
    % =========================================================================

    properties
        Folder
        Files
    end

    methods (TestClassSetup)
        function createExamples(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture) ;
            testCase.Folder = fixture.Folder ; addpath(testCase.Folder) ;
            testCase.addTeardown(@() removePath(testCase.Folder)) ;
            examples = testCase.getSharedTestFixtures('nirptest.ExamplesFixture') ;
            testCase.Files = examples.Files ;
        end
    end

    methods (TestMethodTeardown)
        function closeModels(~)
            bdclose('all') ; Simulink.data.dictionary.closeAll('-discard') ;
            evalin('base','clear nirpResults') ;
        end
    end

    methods (Test)
        function packagesAndExamplesAreRegistered(testCase)
            testCase.verifyWarningFree(@() nirp.pkg.validate( ...
                nirp.pkg.examples.problem16EmpiricalGas())) ;
            testCase.verifyWarningFree(@() nirp.pkg.validate( ...
                nirp.pkg.examples.problem35NOReduction())) ;
            [names,descriptions] = nirp.flowsheet.exampleNames() ;
            testCase.verifyEqual(names(45:47), ...
                ["ex45_problem16_pfr_space_time"; ...
                "ex46_problem35_isothermal_cstr"; ...
                "ex47_problem35_adiabatic_feed_T"]) ;
            testCase.verifyTrue(all(strlength(descriptions(45:47)) > 20)) ;
            testCase.verifyEqual(numel(testCase.Files),50) ;
        end

        function problem16MatchesScriptAndReferences(testCase)
            results = simulateExample(testCase.Files(45), ...
                "ex45_problem16_pfr_space_time") ;
            volume = diagnosticParameter(results, ...
                "ex45_problem16_pfr_space_time","Adjust") ;
            pkg = nirp.pkg.examples.problem16EmpiricalGas() ;
            rs = nirp.pkg.toReactionSys(pkg) ; feed = nirp.pkg.feedStream(pkg,"F1") ;
            adjusted = nirp.units.pfr(struct('V',volume,'D',1),feed,rs) ;
            fixed = nirp.units.pfr(struct('V',50,'D',1),feed,rs) ;
            verifyStream(testCase,results.Streams.ProductAdjusted.streamSI, ...
                adjusted,1e-9) ;
            verifyStream(testCase,results.Streams.Product50000L.streamSI, ...
                fixed,1e-9) ;
            testCase.verifyEqual(volume,75.081,'RelTol',1e-4) ;
            testCase.verifyEqual(volume/feed.Q/60,0.9730,'RelTol',1e-4) ;
            testCase.verifyEqual(fixed.F(3)*3.6,29.583,'RelTol',1e-4) ;
        end

        function problem35IsothermalMatchesScriptAndReferences(testCase)
            pkg = nirp.pkg.examples.problem35NOReduction() ;
            rs = nirp.pkg.toReactionSys(pkg) ; feed = nirp.pkg.feedStream(pkg,"F1") ;
            temperatures = (350:50:600)' ;
            % Full-precision script values corresponding to Claude's
            % independently calculated references in the task sheet.
            reference = [3.52983437036e-6 6.13837458060e-8; ...
                4.33604520292e-5 2.24390114565e-6; ...
                2.19836158920e-4 2.84179463060e-5; ...
                4.45120447118e-4 1.22832014195e-4; ...
                5.43089274680e-4 2.12579186109e-4; ...
                4.02701793684e-4 3.94933491792e-4] ;
            actual = zeros(size(reference)) ;
            for i = 1:numel(temperatures)
                inlet = atTemperature(feed,temperatures(i)) ;
                product = nirp.units.cstr(struct('V',0.2),inlet,rs) ;
                actual(i,:) = reactionExtents(inlet,product,rs) ;
            end
            testCase.verifyEqual(actual,reference,'RelTol',1e-6) ;
            results = simulateExample(testCase.Files(46), ...
                "ex46_problem35_isothermal_cstr") ;
            expected = nirp.units.cstr(struct('V',0.2),feed,rs) ;
            verifyStream(testCase,results.Streams.Product.streamSI,expected,1e-9) ;
            testCase.verifyEqual(reactionExtents(feed, ...
                results.Streams.Product.streamSI,rs),actual(4,:),'RelTol',1e-9) ;
        end

        function problem35AdiabaticFeedTemperatureMatchesReference(testCase)
            results = simulateExample(testCase.Files(47), ...
                "ex47_problem35_adiabatic_feed_T") ;
            temperature = diagnosticParameter(results, ...
                "ex47_problem35_adiabatic_feed_T","Adjust") ;
            pkg = nirp.pkg.examples.problem35NOReduction() ;
            rs = nirp.pkg.toReactionSys(pkg) ; feed = nirp.pkg.feedStream(pkg,"F1") ;
            scriptTemperature = fzero(@(value) adiabaticCstrTemperature( ...
                value,feed,rs)-500,[299 300]) ;
            inlet = atTemperature(feed,temperature) ;
            expected = nirp.units.cstr(struct('V',0.2,'heatMode','Adiabatic', ...
                'initialTemperatureGuess',500),inlet,rs) ;
            verifyStream(testCase,results.Streams.Product.streamSI,expected,1e-9) ;
            testCase.verifyEqual(temperature,scriptTemperature,'RelTol',1e-5) ;
            testCase.verifyEqual(temperature,299.730,'RelTol',1e-6) ;
            testCase.verifyEqual(expected.T,500,'RelTol',1e-9) ;
        end
    end
end

function results = simulateExample(file,name)
    evalin('base','clear nirpResults') ; load_system(char(file)) ;
    sim(char(name)) ; results = evalin('base','nirpResults') ;
    close_system(char(name),0) ; Simulink.data.dictionary.closeAll('-discard') ;
end

function value = diagnosticParameter(results,model,block)
    field = matlab.lang.makeValidName(model+"_"+block) ;
    value = results.Diagnostics.(field).lastInfo.value ;
end

function stream = atTemperature(stream,temperature)
    stream.T = temperature ; stream = nirp.stream.refresh(stream) ;
end

function extents = reactionExtents(feed,product,rs)
    extents = (rs.stochiometricMatrix'\(product.F-feed.F))' ;
end

function value = adiabaticCstrTemperature(temperature,feed,rs)
    inlet = atTemperature(feed,temperature) ;
    product = nirp.units.cstr(struct('V',0.2,'heatMode','Adiabatic', ...
        'initialTemperatureGuess',500),inlet,rs) ;
    value = product.T ;
end

function verifyStream(testCase,actual,expected,tolerance)
    testCase.verifyEqual(actual.F,expected.F,'RelTol',tolerance, ...
        'AbsTol',1e-12) ;
    testCase.verifyEqual(actual.T,expected.T,'RelTol',tolerance) ;
    testCase.verifyEqual(actual.P,expected.P,'RelTol',tolerance) ;
    testCase.verifyEqual(actual.Q,expected.Q,'RelTol',tolerance) ;
end

function removePath(folder)
    if contains([path pathsep],[folder pathsep]), rmpath(folder) ; end
end
