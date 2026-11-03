classdef NirpTracerReactiveBlocksTest < matlab.unittest.TestCase
    % Compatibility tests for tracer models saved with reactive settings.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 25, 2026. Last update: November 3, 2026
    % =========================================================================
    properties,Folder;end
    methods (TestMethodSetup)
        function setup(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);testCase.Folder=fixture.Folder;
            identifier='nirp:tracerblocks:ReactiveCalculationsMoved';state=warning('query',identifier);warning('on',identifier);
            testCase.addTeardown(@()warning(state));testCase.addTeardown(@()cleanup());evalin('base','clear nirpTracerResults');
        end
    end
    methods (Test)
        function savedFiveComponentModelSimulatesAsTracerOnly(testCase)
            name='legacy_reactive_tracer';dt=0.05;tFinal=20;
            [modelFile,dictionary]=nirp.tracerflowsheet.new(name,testCase.Folder,'Dt',dt,'TFinal',tFinal,'OpenModel',false);
            load_system(modelFile);flowsheet=[name '/Tracer Flowsheet'];
            rs=ReactionSys;rs.componentNames={'A','B','C','D','E'};rs.stochiometricMatrix=[-1 1 0 0 0];rs.k0=0.2;
            reactionFile=fullfile(testCase.Folder,'legacy_reaction.mat');save(reactionFile,'rs','-mat');
            nirp.tracerflowsheet.writeDictionary(dictionary,nirp.tracer.grid(dt,tFinal),5);
            set_param(flowsheet,'Micromixing','Both','ReactionOrigin','File', ...
                'ReactionReference',reactionFile,'KeyComponent','3', ...
                'Temperature','315','TemperatureUnit','K');
            addTracer(name,'Source','nirp.tracerblocks.Source',[40 150 170 210], ...
                {'DataTime','[0 20]','DataConcentration','[1 1]', ...
                'FeedConcentrations','[10 20 30 40 50]','ConcentrationUnit','mol/m^3'});
            addTracer(name,'Vessel','nirp.tracerblocks.Vessel',[230 150 370 210],{'Tau','2'});
            addTracer(name,'Monitor','nirp.tracerblocks.Monitor',[430 150 560 210],{'ShowViewer','0'});
            add_line(name,'Source/1','Vessel/1');add_line(name,'Vessel/1','Monitor/1');set_param(name,'StopTime','0');save_system(name);close_system(name,0);

            load_system(modelFile);
            testCase.verifyEqual(get_param(flowsheet,'Micromixing'),'Both');
            testCase.verifyEqual(get_param([name '/Source'],'FeedConcentrations'),'[10 20 30 40 50]');
            lastwarn('');sim(name);[message,identifier]=lastwarn;legacy=evalin('base','nirpTracerResults.legacy_reactive_tracer_Monitor');
            testCase.verifyEqual(identifier,'nirp:tracerblocks:ReactiveCalculationsMoved');
            testCase.verifyEqual(message,['Reactive calculations moved to the Non-ideal Reactor block of the flowsheet library; ' ...
                'this tracer flowsheet now computes tracer signals and RTDs only.']);
            % (simulated above, where Flowsheet.setupImpl issues the notice)
            testCase.verifyFalse(isfield(legacy,'reaction'));
            testCase.verifyEqual(legacy.stream.C0,zeros(1,5));testCase.verifyEqual(legacy.stream.Cseg,zeros(1,5));
            testCase.verifyEqual(legacy.stream.Cmm,zeros(1,5));testCase.verifyEqual(legacy.stream.reactiveMode,uint8(0));

            set_param(flowsheet,'Micromixing','None');evalin('base','clear nirpTracerResults');sim(name);
            inert=evalin('base','nirpTracerResults.legacy_reactive_tracer_Monitor');
            testCase.verifyEqual(legacy.stream.C,inert.stream.C,'AbsTol',0);
            testCase.verifyEqual(legacy.stream.E,inert.stream.E,'AbsTol',0);
        end
        function legacyPropertiesRemainBlockParameters(testCase)
            flowsheetMeta=?nirp.tracerblocks.Flowsheet;sourceMeta=?nirp.tracerblocks.Source;
            verifyBlockParameter(testCase,flowsheetMeta,{'Micromixing','ReactionOrigin','ReactionReference','KeyComponent','Temperature','TemperatureUnit'});
            verifyBlockParameter(testCase,sourceMeta,{'FeedConcentrations','ConcentrationUnit'});
        end
    end
end
function verifyBlockParameter(testCase,metaClass,names)
properties=metaClass.PropertyList;
for k=1:numel(names),property=properties(strcmp({properties.Name},names{k}));testCase.verifyNumElements(property,1);testCase.verifyFalse(property.Hidden,names{k});end
end
function addTracer(model,name,system,position,parameters),block=[model '/' name];add_block('simulink/User-Defined Functions/MATLAB System',block,'System',system,'Position',position);for k=1:2:numel(parameters),set_param(block,parameters{k},parameters{k+1});end;nirp.tracerflowsheet.setupBlock(block);end
function cleanup(),bdclose('all');Simulink.data.dictionary.closeAll('-discard');evalin('base','clear nirpTracerResults');end
