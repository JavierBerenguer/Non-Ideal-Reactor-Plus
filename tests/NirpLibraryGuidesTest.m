classdef NirpLibraryGuidesTest < matlab.unittest.TestCase
    % NirpLibraryGuidesTest verifies help opened from library block callbacks.
    % =====================================================================
    % Javier Berenguer Sabater
    % Created: October 17, 2026. Last update: October 22, 2026
    % =====================================================================

    methods (Test)
        function everyLibraryBlockOpensItsDialogGuide(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            root = fileparts(fileparts(mfilename('fullpath'))) ;
            fixture = testCase.applyFixture(TemporaryFolderFixture) ;
            simulinkFolder = fullfile(root, 'simulink') ;
            addpath(simulinkFolder) ;
            testCase.addTeardown(@() rmpath(simulinkFolder)) ;
            libraryFile = build_library(fixture.Folder) ;
            load_system(libraryFile) ;
            testCase.addTeardown(@() closeLibrary()) ;

            openedPath = "" ;
            setappdata(groot, 'NirpGuideOpenOverride', @recordGuidePath) ;
            testCase.addTeardown(@() clearGuideOverride()) ;
            expected = { ...
                'Stream', 'guides/flowsheet-streams.html#stream' ; ...
                'CSTR', 'guides/flowsheet-reactors.html#cstr' ; ...
                'PFR', 'guides/flowsheet-reactors.html#pfr' ; ...
                'Mixer', 'guides/flowsheet-units.html#mixer' ; ...
                'Splitter', 'guides/flowsheet-units.html#splitter' ; ...
                'Separator', 'guides/flowsheet-units.html#separator' ; ...
                'Heater', 'guides/flowsheet-units.html#heater' ; ...
                'Jacket', 'guides/flowsheet-reactors.html#jacket' ; ...
                'Recycle', 'guides/flowsheet-recycle-adjust.html#recycle' ; ...
                'Adjust', 'guides/flowsheet-recycle-adjust.html#adjust' ; ...
                'Flowsheet', 'guides/flowsheet-reactive-system.html'} ;

            for index = 1:size(expected, 1)
                openedPath = "" ;
                block = ['NirpLibrary/' expected{index, 1}] ;
                open_system(block) ;
                testCase.verifyEqual(openedPath, string(expected{index, 2}), ...
                    sprintf('Wrong guide opened by %s.', block)) ;
            end

            function recordGuidePath(relativePath)
                openedPath = string(relativePath) ;
            end
        end

        function everyTracerLibraryBlockOpensItsTopicGuide(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            root = fileparts(fileparts(mfilename('fullpath'))) ;
            fixture = testCase.applyFixture(TemporaryFolderFixture) ;
            simulinkFolder = fullfile(root, 'simulink') ;
            addpath(simulinkFolder) ;
            testCase.addTeardown(@() rmpath(simulinkFolder)) ;
            libraryFile = build_tracer_library(fixture.Folder) ;
            load_system(libraryFile) ;
            testCase.addTeardown(@() closeTracerLibrary()) ;

            openedPath = "" ;
            setappdata(groot, 'NirpGuideOpenOverride', @recordGuidePath) ;
            testCase.addTeardown(@() clearGuideOverride()) ;
            expected = { ...
                'Tracer Flowsheet', 'guides/tracer-flowsheet.html#dialog' ; ...
                'Tracer Source', 'guides/tracer-source.html#dialog' ; ...
                'Non-ideal Vessel', 'guides/tracer-vessel.html#dialog' ; ...
                'Tracer Splitter', 'guides/tracer-splitter.html#dialog' ; ...
                'Tracer Mixer', 'guides/tracer-mixer.html#dialog' ; ...
                'Tracer Monitor', 'guides/tracer-monitor-results.html#dialog'} ;
            dialogTags = ["NirpTracerFlowsheetDialog", ...
                "NirpTracerSourceDialog", "NirpTracerVesselDialog", ...
                "NirpTracerSplitterDialog", "NirpTracerMixerDialog", ...
                "NirpTracerMonitorDialog"] ;

            for index = 1:size(expected, 1)
                openedPath = "" ;
                block = ['NirpTracerLibrary/' expected{index, 1}] ;
                open_system(block) ;
                testCase.verifyEqual(openedPath, string(expected{index, 2}), ...
                    sprintf('Wrong guide opened by %s.', block)) ;
                testCase.verifyEmpty(findall(groot, 'Tag', dialogTags(index)), ...
                    sprintf('%s opened a dialog from the library.', block)) ;
            end

            function recordGuidePath(relativePath)
                openedPath = string(relativePath) ;
            end
        end
    end
end

function closeLibrary()
    if bdIsLoaded('NirpLibrary')
        close_system('NirpLibrary', 0) ;
    end
end

function closeTracerLibrary()
    if bdIsLoaded('NirpTracerLibrary')
        close_system('NirpTracerLibrary', 0) ;
    end
end

function clearGuideOverride()
    if isappdata(groot, 'NirpGuideOpenOverride')
        rmappdata(groot, 'NirpGuideOpenOverride') ;
    end
end
