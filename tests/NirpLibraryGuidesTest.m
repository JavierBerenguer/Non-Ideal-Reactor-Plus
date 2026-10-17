classdef NirpLibraryGuidesTest < matlab.unittest.TestCase
    % NirpLibraryGuidesTest verifies help opened from library block callbacks.
    % =====================================================================
    % Javier Berenguer Sabater
    % Created: October 17, 2026. Last update: October 17, 2026
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
    end
end

function closeLibrary()
    if bdIsLoaded('NirpLibrary')
        close_system('NirpLibrary', 0) ;
    end
end

function clearGuideOverride()
    if isappdata(groot, 'NirpGuideOpenOverride')
        rmappdata(groot, 'NirpGuideOpenOverride') ;
    end
end
