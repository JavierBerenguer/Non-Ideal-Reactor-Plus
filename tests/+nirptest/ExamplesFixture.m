classdef ExamplesFixture < matlab.unittest.fixtures.Fixture
    % ExamplesFixture builds the Simulink examples once for a test suite.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 9, 2026. Last update: October 9, 2026
    % =========================================================================

    properties (SetAccess=private)
        Folder
        Files
    end

    properties (Access=private)
        FileGenerationConfig
        SimulinkFolder
    end

    methods
        function setup(fixture)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            temporaryFolder = fixture.applyFixture(TemporaryFolderFixture) ;
            fixture.Folder = temporaryFolder.Folder ;
            fixture.SimulinkFolder = fullfile( ...
                fileparts(fileparts(fileparts(mfilename('fullpath')))), ...
                'simulink') ;
            fixture.FileGenerationConfig = Simulink.fileGenControl('getConfig') ;
            fixture.addTeardown(@() fixture.restoreEnvironment()) ;

            addpath(fixture.SimulinkFolder) ;
            addpath(fixture.Folder) ;
            Simulink.fileGenControl('set', ...
                'CacheFolder',fullfile(fixture.Folder,'cache'), ...
                'CodeGenFolder',fullfile(fixture.Folder,'codegen'), ...
                'createDir',true) ;
            fixture.Files = build_examples(fixture.Folder) ;
        end
    end

    methods (Access=protected)
        function tf = isCompatible(~,other)
            tf = isa(other,'nirptest.ExamplesFixture') ;
        end
    end

    methods (Access=private)
        function restoreEnvironment(fixture)
            bdclose('all') ;
            Simulink.data.dictionary.closeAll('-discard') ;
            Simulink.fileGenControl('setConfig', ...
                'config',fixture.FileGenerationConfig) ;
            removePath(fixture.Folder) ;
            removePath(fixture.SimulinkFolder) ;
        end
    end
end

function removePath(folder)
    if contains([path pathsep],[folder pathsep])
        rmpath(folder) ;
    end
end
