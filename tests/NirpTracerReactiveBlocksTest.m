classdef NirpTracerReactiveBlocksTest < matlab.unittest.TestCase
    % Integration tests for reactive non-ideal flowsheet blocks and dialogs.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 25, 2026. Last update: October 25, 2026
    % =========================================================================
    properties,Folder;end
    methods (TestMethodSetup)
        function setup(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);testCase.Folder=fixture.Folder;
            testCase.addTeardown(@()cleanup());evalin('base','clear nirpTracerResults nirpTracerReactiveCalls tracerTestRS');
        end
    end
    methods (Test)
        function firstOrderTwoCstrsMatchAnalyticalAndAreCached(testCase)
            rs=makeRs(1,0.4);assignin('base','tracerTestRS',rs);
            name='reactive_two_cstr';createModel(testCase.Folder,name,0.02,40,rs,'Both','Workspace','tracerTestRS');
            addTracer(name,'Source','nirp.tracerblocks.Source',[40 150 170 210],{'Q','1','DataTime','[0 40]','DataConcentration','[1 1]','FeedConcentrations','[10 0]'});
            addTracer(name,'Vessel 1','nirp.tracerblocks.Vessel',[230 150 370 210],{'Tau','2'});addTracer(name,'Vessel 2','nirp.tracerblocks.Vessel',[430 150 570 210],{'Tau','2'});addTracer(name,'Monitor','nirp.tracerblocks.Monitor',[630 150 760 210],{'ShowViewer','0'});
            add_line(name,'Source/1','Vessel 1/1');add_line(name,'Vessel 1/1','Vessel 2/1');add_line(name,'Vessel 2/1','Monitor/1');set_param(name,'StopTime','0.08');sim(name);
            result=evalin('base','nirpTracerResults.reactive_two_cstr_Monitor');expected=1-(1+0.4*2)^-2;
            testCase.verifyEqual([result.reaction.Xseg result.reaction.Xmm],expected*[1 1],'RelTol',4e-3);
            calls=evalin('base','nirpTracerReactiveCalls');testCase.verifyEqual(calls.reactive_two_cstr_Vessel1,1);testCase.verifyEqual(calls.reactive_two_cstr_Vessel2,2);
            testCase.verifyFalse(result.reaction.rtdTruncated);testCase.verifySubstring(result.reaction.warning,'First-order');
        end
        function parallelSecondOrderProducesGuaranteedOrderedInterval(testCase)
            rs=makeRs(2,0.004);assignin('base','tracerTestRS',rs);
            name='reactive_parallel';createModel(testCase.Folder,name,0.02,35,rs,'Both','Workspace','tracerTestRS');
            addTracer(name,'Source','nirp.tracerblocks.Source',[30 180 150 240],{'DataTime','[0 35]','DataConcentration','[1 1]','FeedConcentrations','[10 0]'});addTracer(name,'Splitter','nirp.tracerblocks.Splitter',[190 170 310 250],{'Fractions','0.5'});
            addTracer(name,'PFR','nirp.tracerblocks.Vessel',[360 90 480 150],{'Model','PFR','Tau','2'});addTracer(name,'CSTR','nirp.tracerblocks.Vessel',[360 280 480 340],{'Model','CSTR','Tau','2'});addTracer(name,'Mixer','nirp.tracerblocks.Mixer',[530 170 650 250],{});addTracer(name,'Monitor','nirp.tracerblocks.Monitor',[700 180 820 240],{'ShowViewer','0'});
            add_line(name,'Source/1','Splitter/1');add_line(name,'Splitter/1','PFR/1');add_line(name,'Splitter/2','CSTR/1');add_line(name,'PFR/1','Mixer/1');add_line(name,'CSTR/1','Mixer/2');add_line(name,'Mixer/1','Monitor/1');sim(name);
            reaction=evalin('base','nirpTracerResults.reactive_parallel_Monitor.reaction');
            testCase.verifyGreaterThan(reaction.Xseg,reaction.Xmm);testCase.verifyTrue(reaction.validity.guaranteed);testCase.verifyEqual(reaction.lowerModel,'Max mixedness');testCase.verifyEqual(reaction.upperModel,'Segregation');testCase.verifySubstring(reaction.warning,'Guaranteed bounds');
        end
        function sessionAndWorkspaceReferencesPersistAndResizeBus(testCase)
            rs=makeRs(1,0.2);sessionData=struct('prediction',struct('rs',rs));session=fullfile(testCase.Folder,'reaction_session.mat');save(session,'sessionData','-mat');
            name='reactive_reference';nirp.tracerflowsheet.new(name,testCase.Folder,'OpenModel',false);load_system(fullfile(testCase.Folder,[name '.slx']));block=[name '/Tracer Flowsheet'];
            dialog=nirp.tracerflowsheet.FlowsheetDialog(block,'Visible','off');dialog.setReaction('Session',session,'Both',1,25,[char(176) 'C']);testCase.verifyTrue(dialog.apply(),dialog.StatusLabel.Text);delete(dialog);
            testCase.verifyEqual(get_param(block,'ReactionReference'),session);testCase.verifyEqual(get_param(block,'ReactionOrigin'),'Session');
            dictionary=Simulink.data.dictionary.open(fullfile(testCase.Folder,[name '.sldd']));cleanupDictionary=onCleanup(@()close(dictionary));bus=getValue(getEntry(getSection(dictionary,'Design Data'),'NirpTracer'));testCase.verifyEqual(bus.Elements(7).Dimensions,[2 1]);clear cleanupDictionary
            assignin('base','tracerTestRS',rs);dialog=nirp.tracerflowsheet.FlowsheetDialog(block,'Visible','off');dialog.setReaction('Workspace','tracerTestRS','Segregation',1,298.15,'K');testCase.verifyTrue(dialog.apply(),dialog.StatusLabel.Text);delete(dialog);save_system(name);close_system(name,0);load_system(fullfile(testCase.Folder,[name '.slx']));
            testCase.verifyEqual(get_param(block,'ReactionOrigin'),'Workspace');testCase.verifyEqual(get_param(block,'ReactionReference'),'tracerTestRS');testCase.verifyEqual(get_param(block,'Micromixing'),'Segregation');
        end
        function sourceAndMonitorDialogsExposeReactiveTables(testCase)
            rs=makeRs(2,0.004);assignin('base','tracerTestRS',rs);name='reactive_dialogs';createModel(testCase.Folder,name,0.05,20,rs,'Both','Workspace','tracerTestRS');
            addTracer(name,'Source','nirp.tracerblocks.Source',[40 150 170 210],{'DataTime','[0 20]','DataConcentration','[1 1]'});addTracer(name,'Vessel','nirp.tracerblocks.Vessel',[230 150 370 210],{'Tau','2'});addTracer(name,'Monitor','nirp.tracerblocks.Monitor',[430 150 560 210],{'ShowViewer','0'});add_line(name,'Source/1','Vessel/1');add_line(name,'Vessel/1','Monitor/1');
            source=nirp.tracerflowsheet.SourceDialog([name '/Source'],'Visible','off');testCase.verifyEqual(string(source.CompositionTable.Visible),"on");testCase.verifyEqual(source.CompositionTable.Data(:,1),{'A';'B'});source.setFeedConcentrations([10 0],'mol/m^3');testCase.verifyTrue(source.apply(),source.StatusLabel.Text);delete(source);sim(name);
            monitor=nirp.tracerflowsheet.MonitorDialog([name '/Monitor'],'Visible','off');testCase.verifyEqual(size(monitor.ResultsTable.Data,1),2);testCase.verifyEqual(numel(monitor.ResultsTable.ColumnName),5);testCase.verifySubstring(monitor.ValidityLabel.Text,'Conversion interval');delete(monitor);
            result=evalin('base','nirpTracerResults.reactive_dialogs_Monitor');viewer=nirp.tracerflowsheet.showResults(result,'Visible','off');testCase.verifyEqual(numel(viewer.ReactionTable.ColumnName),5);delete(viewer.Figure);
            result.reaction.mode='Segregation';viewer=nirp.tracerflowsheet.showResults(result,'Visible','off');testCase.verifyEqual(numel(viewer.ReactionTable.ColumnName),3);delete(viewer.Figure);
        end
        function multipleReactionsAreReportedAsNotGuaranteed(testCase)
            rs=ReactionSys;rs.componentNames={'A','B','C'};rs.stochiometricMatrix=[-1 1 0;-1 0 1];rs.k0=[0.1 0.2];assignin('base','tracerTestRS',rs);
            name='reactive_multiple';createModel(testCase.Folder,name,0.05,20,rs,'Both','Workspace','tracerTestRS');addTracer(name,'Source','nirp.tracerblocks.Source',[40 150 170 210],{'DataTime','[0 20]','DataConcentration','[1 1]','FeedConcentrations','[10 0 0]'});addTracer(name,'Vessel','nirp.tracerblocks.Vessel',[230 150 370 210],{'Tau','2'});addTracer(name,'Monitor','nirp.tracerblocks.Monitor',[430 150 560 210],{'ShowViewer','0'});add_line(name,'Source/1','Vessel/1');add_line(name,'Vessel/1','Monitor/1');sim(name);
            reaction=evalin('base','nirpTracerResults.reactive_multiple_Monitor.reaction');testCase.verifyFalse(reaction.validity.guaranteed);testCase.verifySubstring(reaction.warning,'Bounds not guaranteed');testCase.verifySubstring(reaction.warning,'exactly one reaction');
        end
    end
end
function rs=makeRs(order,k),rs=ReactionSys;rs.componentNames={'A','B'};rs.stochiometricMatrix=[-order 1];rs.k0=k;rs.Ea=0;end
function createModel(folder,name,dt,tFinal,rs,mode,origin,reference)
[~,dictionary]=nirp.tracerflowsheet.new(name,folder,'Dt',dt,'TFinal',tFinal,'OpenModel',false);load_system(fullfile(folder,[name '.slx']));block=[name '/Tracer Flowsheet'];set_param(block,'Micromixing',mode,'ReactionOrigin',origin,'ReactionReference',reference,'KeyComponent','1','Temperature','298.15');nirp.tracerflowsheet.writeDictionary(dictionary,nirp.tracer.grid(dt,tFinal),rs.nComponents);set_param(name,'StopTime','0');
end
function addTracer(model,name,system,position,parameters),block=[model '/' name];add_block('simulink/User-Defined Functions/MATLAB System',block,'System',system,'Position',position);for k=1:2:numel(parameters),set_param(block,parameters{k},parameters{k+1});end;nirp.tracerflowsheet.setupBlock(block);end
function cleanup(),figures=findall(groot,'Type','Figure');for k=1:numel(figures),try,delete(figures(k));catch,end,end;bdclose('all');Simulink.data.dictionary.closeAll('-discard');evalin('base','clear nirpTracerResults nirpTracerReactiveCalls tracerTestRS');end
