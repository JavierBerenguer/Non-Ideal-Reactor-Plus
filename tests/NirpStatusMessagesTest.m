classdef NirpStatusMessagesTest < matlab.unittest.TestCase
    % NirpStatusMessagesTest verifies latest-run block colors and messages.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 9, 2026. Last update: October 9, 2026
    % =========================================================================

    properties
        Folder
        SimulinkFolder
        Files
        FileGenerationConfig
    end

    methods (TestClassSetup)
        function createExamples(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture) ;
            testCase.Folder = fixture.Folder ;
            testCase.SimulinkFolder = fullfile( ...
                fileparts(fileparts(mfilename('fullpath'))),'simulink') ;
            addpath(testCase.SimulinkFolder) ; addpath(testCase.Folder) ;
            testCase.FileGenerationConfig = Simulink.fileGenControl('getConfig') ;
            Simulink.fileGenControl('set', ...
                'CacheFolder',fullfile(testCase.Folder,'cache'), ...
                'CodeGenFolder',fullfile(testCase.Folder,'codegen'), ...
                'createDir',true) ;
            testCase.Files = build_examples(testCase.Folder) ;
            testCase.addTeardown(@() restoreEnvironment(testCase)) ;
        end
    end

    methods (TestMethodTeardown)
        function closeRun(testCase) %#ok<MANU>
            figures = findall(groot,'Type','Figure') ;
            if ~isempty(figures), delete(figures) ; end
            bdclose('all') ; Simulink.data.dictionary.closeAll('-discard') ;
            evalin('base','clear nirpResults') ;
        end
    end

    methods (Test)
        function successfulRunIsGreenCleanAndHasInfoMessage(testCase)
            load_system(char(testCase.Files(1))) ;
            testCase.verifyEqual(get_param('ex1_cstr_isothermal','Dirty'),'off') ;
            sim('ex1_cstr_isothermal') ;
            blocks = statusBlocks('ex1_cstr_isothermal') ;
            for i = 1:numel(blocks)
                testCase.verifyEqual(blockColor(blocks{i}),[0.80 0.95 0.80], ...
                    'AbsTol',1e-12) ;
            end
            testCase.verifyEqual(get_param('ex1_cstr_isothermal','Dirty'),'off') ;
            tables = nirp.flowsheet.showResults( ...
                'ex1_cstr_isothermal','NoWindow',true) ;
            testCase.verifyEqual(tables.Messages.Severity,"Info") ;
            testCase.verifyEqual(tables.Messages.Block,"Flowsheet") ;
            testCase.verifyEqual(tables.Messages.Message,"No warnings or errors") ;
        end

        function nonconvergedAdjustIsYellowAndCounted(testCase)
            load_system(char(testCase.Files(6))) ;
            flowsheet = flowsheetBlock('ex6_adjust_volume') ;
            set_param(flowsheet,'MaxIterations','1') ;
            nirp.flowsheet.configure('ex6_adjust_volume') ;
            sim('ex6_adjust_volume') ;
            testCase.verifyEqual(blockColor('ex6_adjust_volume/Adjust'), ...
                [1.00 0.95 0.70],'AbsTol',1e-12) ;
            streams = streamBlocks('ex6_adjust_volume') ;
            testCase.verifyNotEmpty(streams) ;
            for i = 1:numel(streams)
                testCase.verifyEqual(blockColor(streams{i}), ...
                    [1.00 0.95 0.70],'AbsTol',1e-12) ;
            end
            tables = nirp.flowsheet.showResults( ...
                'ex6_adjust_volume','NoWindow',true) ;
            row = tables.Messages.Block == "Adjust" & ...
                tables.Messages.Severity == "Warning" ;
            testCase.verifyTrue(any(row)) ;
            testCase.verifySubstring(tables.Messages.Message(find(row,1)), ...
                "did not converge") ;
            testCase.verifyFalse(any(tables.Messages.Severity == "Error")) ;
            streamRows = ismember(tables.Messages.Block, ...
                string(cellfun(@(block) get_param(block,'Name'),streams, ...
                'UniformOutput',false))) ;
            testCase.verifyEqual(nnz(streamRows),numel(streams)) ;
            testCase.verifyTrue(all(tables.Messages.Severity(streamRows) == ...
                "Warning")) ;
            testCase.verifyTrue(all(tables.Messages.Message(streamRows) == ...
                "Flowsheet did not converge; values are from the last iteration.")) ;
            flowsheetRow = tables.Messages.Block == "Flowsheet" ;
            testCase.verifyTrue(any(flowsheetRow)) ;
            testCase.verifyFalse(any(contains( ...
                tables.Messages.Message(flowsheetRow),"ex6_adjust_volume/"))) ;
            nirp.flowsheet.showResults('ex6_adjust_volume','Visible','off') ;
            tabs = findall(groot,'Type','uitab') ;
            titles = string({tabs.Title}) ;
            title = titles(startsWith(titles,"Messages (")) ;
            testCase.verifyNotEmpty(title) ;
            warningCount = nnz(tables.Messages.Severity == "Warning") ;
            testCase.verifyTrue(any(contains(title, ...
                warningCount+" warnings"))) ;
        end

        function failedUnitIsRedAndReportedAsError(testCase)
            load_system(char(testCase.Files(1))) ; sim('ex1_cstr_isothermal') ;
            results = evalin('base','nirpResults') ;
            field = 'ex1_cstr_isothermal_CSTR' ;
            results.Diagnostics.(field).lastInfo.status = -1 ;
            results.Diagnostics.(field).lastInfo.message = ...
                'Nonlinear solver did not converge.' ;
            assignin('base','nirpResults',results) ;
            nirp.flowsheet.paintStatus('ex1_cstr_isothermal') ;
            testCase.verifyEqual(blockColor('ex1_cstr_isothermal/CSTR'), ...
                [1.00 0.80 0.80],'AbsTol',1e-12) ;
            tables = nirp.flowsheet.showResults( ...
                'ex1_cstr_isothermal','NoWindow',true) ;
            row = tables.Messages.Block == "CSTR" & ...
                tables.Messages.Severity == "Error" ;
            testCase.verifyTrue(any(row)) ;
            testCase.verifyEqual(tables.Messages.Message(row), ...
                "Nonlinear solver did not converge.") ;
        end

        function secondRunDiscardsFirstRunError(testCase)
            load_system(char(testCase.Files(1))) ; sim('ex1_cstr_isothermal') ;
            results = evalin('base','nirpResults') ;
            results.Diagnostics.ex1_cstr_isothermal_CSTR.lastInfo.status = -1 ;
            results.Diagnostics.ex1_cstr_isothermal_CSTR.lastInfo.message = ...
                'First-run failure.' ;
            assignin('base','nirpResults',results) ;
            nirp.flowsheet.paintStatus('ex1_cstr_isothermal') ;
            testCase.verifyEqual(blockColor('ex1_cstr_isothermal/CSTR'), ...
                [1.00 0.80 0.80],'AbsTol',1e-12) ;
            sim('ex1_cstr_isothermal') ;
            blocks = statusBlocks('ex1_cstr_isothermal') ;
            for i = 1:numel(blocks)
                testCase.verifyGreaterThan(max(abs(blockColor(blocks{i})- ...
                    [1.00 0.80 0.80])),1e-12) ;
            end
            tables = nirp.flowsheet.showResults( ...
                'ex1_cstr_isothermal','NoWindow',true) ;
            testCase.verifyFalse(any(contains(tables.Messages.Message, ...
                "First-run failure"))) ;
        end

        function resetLeavesEveryStatusBlockWhite(testCase)
            load_system(char(testCase.Files(1))) ; sim('ex1_cstr_isothermal') ;
            nirp.flowsheet.paintStatus('ex1_cstr_isothermal','reset') ;
            blocks = statusBlocks('ex1_cstr_isothermal') ;
            for i = 1:numel(blocks)
                testCase.verifyEqual(blockColor(blocks{i}),[1 1 1], ...
                    'AbsTol',1e-12) ;
            end
        end

        function reactorDialogShowsSolvedAfterSuccessfulRun(testCase)
            load_system(char(testCase.Files(1))) ; sim('ex1_cstr_isothermal') ;
            dialog = nirp.flowsheet.ReactorDialog( ...
                'ex1_cstr_isothermal/CSTR','Visible','off') ;
            testCase.addTeardown(@() deleteValid(dialog)) ;
            testCase.verifyEqual(string(dialog.StatusLabel.Text),"Solved") ;
        end
    end
end

function blocks = statusBlocks(model)
    supported = ["nirp.blocks.CSTR","nirp.blocks.PFR","nirp.blocks.Heater", ...
        "nirp.blocks.Jacket","nirp.blocks.Mixer","nirp.blocks.Splitter", ...
        "nirp.blocks.Recycle","nirp.blocks.Adjust","nirp.blocks.Stream"] ;
    candidates = find_system(model,'SearchDepth',1,'BlockType','MATLABSystem') ;
    blocks = cell(0,1) ;
    for i = 1:numel(candidates)
        if any(string(get_param(candidates{i},'System')) == supported)
            blocks{end+1,1} = candidates{i} ; %#ok<AGROW>
        end
    end
end

function blocks = streamBlocks(model)
    candidates = find_system(model,'SearchDepth',1, ...
        'BlockType','MATLABSystem') ;
    blocks = cell(0,1) ;
    for i = 1:numel(candidates)
        if string(get_param(candidates{i},'System')) == "nirp.blocks.Stream"
            blocks{end+1,1} = candidates{i} ; %#ok<AGROW>
        end
    end
end

function color = blockColor(block)
    value = string(get_param(block,'BackgroundColor')) ;
    if value == "white"
        color = [1 1 1] ;
    else
        color = str2num(char(value)) ; %#ok<ST2NM>
    end
end

function block = flowsheetBlock(model)
    candidates = find_system(model,'SearchDepth',1,'BlockType','SubSystem') ;
    block = '' ;
    for i = 1:numel(candidates)
        if any(strcmp(get_param(candidates{i},'MaskNames'),'MaxIterations'))
            block = candidates{i} ; return
        end
    end
    error('NirpStatusMessagesTest:noFlowsheet','Flowsheet block not found.') ;
end

function restoreEnvironment(testCase)
    bdclose('all') ; Simulink.data.dictionary.closeAll('-discard') ;
    if contains([path pathsep],[testCase.SimulinkFolder pathsep])
        rmpath(testCase.SimulinkFolder) ;
    end
    if contains([path pathsep],[testCase.Folder pathsep]), rmpath(testCase.Folder) ; end
    Simulink.fileGenControl('setConfig','config',testCase.FileGenerationConfig) ;
end

function deleteValid(value)
    try
        if isvalid(value), delete(value) ; end
    catch
    end
end
