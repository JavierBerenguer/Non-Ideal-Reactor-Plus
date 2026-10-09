classdef (SharedTestFixtures={nirptest.ExamplesFixture}) ...
        NirpCollectionProblemsTest < matlab.unittest.TestCase
    % NirpCollectionProblemsTest verifies collection-problem flowsheets.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 3, 2026. Last update: October 3, 2026
    % =========================================================================

    properties
        Folder
        ExamplesFolder
        Files
    end

    methods (TestMethodSetup)
        function createTemporaryWorkspace(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture) ;
            testCase.Folder = fixture.Folder ;
            examples = testCase.getSharedTestFixtures( ...
                'nirptest.ExamplesFixture') ;
            testCase.ExamplesFolder = examples.Folder ;
            testCase.Files = examples.Files ;
            addpath(testCase.Folder) ;
            testCase.addTeardown(@() removePath(testCase.Folder)) ;
            testCase.addTeardown(@() closeModels()) ;
        end
    end

    methods (Test)
        function diagramsMatchScriptsAndPublishedSolutions(testCase)
            files = testCase.Files ;
            testCase.verifyProblem37(files(8)) ;
            testCase.verifyProblem40(files(9)) ;
            mutableFiles = copyExamplePairs(files(10:11),testCase.Folder) ;
            testCase.verifyProblem42(mutableFiles) ;
            testCase.verifyProblem19(files(12)) ;
        end

        function examplesAreRegistered(testCase)
            [names,descriptions] = nirp.flowsheet.exampleNames() ;
            expected = ["ex8_problem37a_series";"ex9_problem40a_series"; ...
                "ex10_problem42_cstr_pfr";"ex11_problem42_pfr_cstr"; ...
                "ex12_problem19_adiabatic_pfr"] ;
            testCase.verifyEqual(names(8:12),expected) ;
            testCase.verifyTrue(all(strlength(descriptions(8:12)) > 20)) ;
        end
    end

    methods (Access=private)
        function verifyProblem37(testCase,file)
            pkg = nirp.pkg.examples.problem37Liquid() ;
            rs = nirp.pkg.toReactionSys(pkg) ;
            feedA = nirp.pkg.feedStream(pkg,"Feed A") ;
            feedB = nirp.pkg.feedStream(pkg,"Feed B") ;
            mixed = nirp.units.mixer([],{feedA,feedB},rs) ;
            first = nirp.units.cstr(struct('V',0.2),mixed,rs) ;
            expected = nirp.units.cstr(struct('V',0.2),first,rs) ;
            results = simulateExample(file,"ex8_problem37a_series") ;
            actualFirst = results.Streams.CSTR1Outlet.streamSI ;
            actual = results.Streams.Product.streamSI ;
            testCase.verifyStream(actualFirst,first) ;
            testCase.verifyStream(actual,expected) ;
            concentrations1 = nirp.stream.concentration(actualFirst)/1000 ;
            concentrations2 = nirp.stream.concentration(actual)/1000 ;
            conversion = results.Streams.Product.conversion ;
            testCase.verifyEqual(concentrations1(1),0.828427,'AbsTol',1e-6) ;
            testCase.verifyEqual(concentrations2(1),0.704387,'AbsTol',1e-6) ;
            testCase.verifyEqual(conversion,0.295613,'AbsTol',1e-6) ;
            testCase.verifyEqual(round(concentrations1(1),3),0.828) ;
            testCase.verifyEqual(round(concentrations2(1),3),0.704) ;
            testCase.verifyEqual(round(conversion,3),0.296) ;
        end

        function verifyProblem40(testCase,file)
            pkg = nirp.pkg.examples.problem40Gas() ;
            rs = nirp.pkg.toReactionSys(pkg) ;
            feed = nirp.pkg.feedStream(pkg,"F1") ;
            first = nirp.units.cstr(struct('V',0.4),feed,rs) ;
            expected = nirp.units.cstr(struct('V',0.4),first,rs) ;
            results = simulateExample(file,"ex9_problem40a_series") ;
            actual = results.Streams.Product.streamSI ;
            testCase.verifyStream(actual,expected) ;
            conversion = results.Streams.Product.conversion ;
            testCase.verifyEqual(conversion,0.663483,'AbsTol',1e-6) ;
            testCase.verifyEqual(round(conversion,3),0.663) ;
        end

        function verifyProblem42(testCase,files)
            references = [1 1;0.595646 0.595646;0.464102 0.472475] ;
            official = [1 1;0.596 0.596;0.464 0.472] ;
            names = ["ex10_problem42_cstr_pfr","ex11_problem42_pfr_cstr"] ;
            for order = 0:2
                pkg = nirp.pkg.examples.problem42SecondOrder() ;
                pkg.meta.name = "Problem 42 order "+order ;
                pkg.reactions.kinetics.orders = [order 0] ;
                rs = nirp.pkg.toReactionSys(pkg) ;
                feed = nirp.pkg.feedStream(pkg,"F1") ;
                for arrangement = 1:2
                    closeModels() ;
                    dictionary = replace(files(arrangement),".slx",".sldd") ;
                    nirp.pkg.writeDictionary(pkg,dictionary) ;
                    if arrangement == 1
                        first = nirp.units.cstr(struct('V',1),feed,rs) ;
                        expected = nirp.units.pfr( ...
                            struct('V',1,'D',0.1),first,rs) ;
                    else
                        first = nirp.units.pfr( ...
                            struct('V',1,'D',0.1),feed,rs) ;
                        expected = nirp.units.cstr(struct('V',1),first,rs) ;
                    end
                    results = simulateExample(files(arrangement),names(arrangement)) ;
                    actual = results.Streams.Product.streamSI ;
                    testCase.verifyStream(actual,expected) ;
                    conversion = results.Streams.Product.conversion ;
                    testCase.verifyEqual(conversion,references(order+1,arrangement), ...
                        'AbsTol',1e-6) ;
                    testCase.verifyEqual(round(conversion,3), ...
                        official(order+1,arrangement)) ;
                end
            end
        end

        function verifyProblem19(testCase,file)
            pkg = nirp.pkg.examples.problem19Gas() ;
            rs = nirp.pkg.toReactionSys(pkg) ;
            feed = nirp.pkg.feedStream(pkg,"F1") ;
            expected = nirp.units.pfr(struct('V',1.5,'D',0.1, ...
                'heatMode','Adiabatic'),feed,rs) ;
            results = simulateExample(file,"ex12_problem19_adiabatic_pfr") ;
            actual = results.Streams.Product.streamSI ;
            testCase.verifyStream(actual,expected) ;
            conversion = results.Streams.Product.conversion ;
            testCase.verifyEqual(conversion,0.600220,'AbsTol',1e-6) ;
            testCase.verifyEqual(round(conversion,3),0.600) ;
            testCase.verifyEqual(round(actual.T,2),779.53) ;
        end

        function verifyStream(testCase,actual,expected)
            testCase.verifyEqual(actual.F,expected.F, ...
                'RelTol',1e-9,'AbsTol',1e-14) ;
            testCase.verifyEqual(actual.T,expected.T,'RelTol',1e-9) ;
            testCase.verifyEqual(actual.P,expected.P,'RelTol',1e-9) ;
        end
    end
end

function results = simulateExample(file,name)
    evalin('base','clear nirpResults') ;
    load_system(char(file)) ; sim(char(name)) ;
    results = evalin('base','nirpResults') ;
    close_system(char(name),0) ;
    Simulink.data.dictionary.closeAll('-discard') ;
end

function closeModels()
    bdclose('all') ;
    Simulink.data.dictionary.closeAll('-discard') ;
    evalin('base','clear nirpResults') ;
end

function removePath(folder)
    if contains([path pathsep],[folder pathsep]), rmpath(folder) ; end
end

function copies = copyExamplePairs(files,folder)
    copies = strings(size(files)) ;
    for i = 1:numel(files)
        [~,name,extension] = fileparts(files(i)) ;
        copies(i) = fullfile(folder,name+extension) ;
        copyfile(files(i),copies(i)) ;
        sourceDictionary = replace(files(i),".slx",".sldd") ;
        targetDictionary = fullfile(folder,name+".sldd") ;
        copyfile(sourceDictionary,targetDictionary) ;
    end
end
