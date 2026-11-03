classdef NirpNonIdealReactorBlockTest < matlab.unittest.TestCase
    % NirpNonIdealReactorBlockTest verifies the ideal-flowsheet RTD reactor.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: November 3, 2026. Last update: November 3, 2026
    % =========================================================================

    properties
        Folder
    end

    methods (TestMethodSetup)
        function createTemporaryWorkspace(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture=testCase.applyFixture(TemporaryFolderFixture);
            testCase.Folder=fixture.Folder;addpath(testCase.Folder);
            testCase.addTeardown(@() removePath(testCase.Folder));
            testCase.addTeardown(@() closeModels());
            evalin('base','clear nirpResults');
        end
    end

    methods (Test)
        function cstrMaximumMixednessMatchesIdeal(testCase)
            name='nonideal_cstr_equivalence';
            createModel(testCase,name,nirp.pkg.examples.firstOrderLiquid());
            addStream(name,'F1','Feed',[20 100 100 150]);
            addUnit(name,'Non ideal','nirp.blocks.NonIdealReactor',[180 50 330 125], ...
                'RTDOrigin','Model','Model','CSTR','SizeBasis','Residence time', ...
                'Tau','2','Micromixing','Maximum mixedness');
            addUnit(name,'CSTR','nirp.blocks.CSTR',[180 190 330 260],'V','0.002');
            addStream(name,'Non ideal product','Product',[410 75 540 125]);
            addStream(name,'Ideal product','Product',[410 205 540 255]);
            add_line(name,'F1/1','Non ideal/1');add_line(name,'F1/1','CSTR/1');
            add_line(name,'Non ideal/1','Non ideal product/1');
            add_line(name,'CSTR/1','Ideal product/1');finishModel(name);sim(name);
            results=evalin('base','nirpResults');
            actual=results.Streams.NonIdealProduct.streamSI;
            ideal=results.Streams.IdealProduct.streamSI;
            testCase.verifyEqual(actual.F,ideal.F,'RelTol',1e-4,'AbsTol',1e-14);
            info=results.Diagnostics.nonideal_cstr_equivalence_NonIdeal.lastInfo;
            testCase.verifyEqual(info.tau,2,'RelTol',1e-12);
            testCase.verifyEqual(info.meanResidenceTime,2,'RelTol',1e-12);
        end

        function pfrBothModelsMatchIdeal(testCase)
            name='nonideal_pfr_equivalence';
            createModel(testCase,name,nirp.pkg.examples.firstOrderLiquid());
            addStream(name,'F1','Feed',[20 130 100 180]);
            modes={'Segregation','Maximum mixedness'};blocks={'SEG','MM'};
            y=[30 130];
            for i=1:2
                addUnit(name,blocks{i},'nirp.blocks.NonIdealReactor', ...
                    [180 y(i) 330 y(i)+70],'RTDOrigin','Model','Model','PFR', ...
                    'SizeBasis','Residence time','Tau','2','Micromixing',modes{i});
                addStream(name,[blocks{i} ' product'],'Product',[410 y(i)+10 540 y(i)+60]);
                add_line(name,'F1/1',[blocks{i} '/1']);
                add_line(name,[blocks{i} '/1'],[blocks{i} ' product/1']);
            end
            addUnit(name,'PFR','nirp.blocks.PFR',[180 250 330 320], ...
                'GeometryMode','Volume','V','0.002');
            addStream(name,'Ideal product','Product',[410 260 540 310]);
            add_line(name,'F1/1','PFR/1');add_line(name,'PFR/1','Ideal product/1');
            finishModel(name);sim(name);results=evalin('base','nirpResults');
            ideal=results.Streams.IdealProduct.streamSI;
            testCase.verifyEqual(results.Streams.SEGProduct.streamSI.F, ...
                ideal.F,'RelTol',1e-3,'AbsTol',1e-14);
            testCase.verifyEqual(results.Streams.MMProduct.streamSI.F, ...
                ideal.F,'RelTol',1e-3,'AbsTol',1e-14);
        end

        function january2024SeriesAndMixedModels(testCase)
            pkg=examPackage();modes={'Segregation','Maximum mixedness'};
            expectedFirst=[0.13824 0.060735 0.060735 0.31779 0.31779; ...
                0.19385 0.069644 0.069644 0.29107 0.29107];
            expectedSecond=[0.044859 0.038064 0.16512 0.24168 0.24168; ...
                0.045823 0.038935 0.18121 0.24376 0.24376];
            for i=1:2
                name=sprintf('exam24_%d',i);
                [first,second]=simulateSeries(testCase,name,pkg,modes{i},modes{i});
                testCase.verifyEqual(first.F.'/first.Q/1000,expectedFirst(i,:), ...
                    'RelTol',5e-3);
                testCase.verifyEqual(second.F.'/second.Q/1000,expectedSecond(i,:), ...
                    'RelTol',5e-3);
                close_system(name,0);Simulink.data.dictionary.closeAll('-discard');
            end
            [actualFirst,actualSecond]=simulateSeries(testCase,'exam24_mixed',pkg, ...
                'Segregation','Maximum mixedness');
            rs=nirp.pkg.toReactionSys(pkg);feed=nirp.pkg.feedStream(pkg,'F1');
            firstParams=nonIdealParams('tanks',1,1,'segregation');
            secondParams=nonIdealParams('tanks',2,100,'maxmixedness');
            expectedFirstMixed=nirp.units.nonIdealReactor(firstParams,feed,rs);
            expectedSecondMixed=nirp.units.nonIdealReactor( ...
                secondParams,expectedFirstMixed,rs);
            testCase.verifyEqual(actualFirst.F,expectedFirstMixed.F, ...
                'RelTol',1e-10,'AbsTol',1e-14);
            testCase.verifyEqual(actualSecond.F,expectedSecondMixed.F, ...
                'RelTol',1e-10,'AbsTol',1e-14);
        end

        function micromixingInvalidatesCacheAndIconShowsMode(testCase)
            name='nonideal_cache';
            createModel(testCase,name,nirp.pkg.examples.problem41SecondOrder());
            addStream(name,'F1','Feed',[20 100 100 150]);
            addUnit(name,'Reactor','nirp.blocks.NonIdealReactor',[180 85 330 165], ...
                'RTDOrigin','Model','Model','CSTR','SizeBasis','Residence time', ...
                'Tau','60','Micromixing','Segregation');
            addStream(name,'Product','Product',[410 100 520 150]);
            add_line(name,'F1/1','Reactor/1');add_line(name,'Reactor/1','Product/1');
            finishModel(name);sim(name);first=evalin('base','nirpResults.Streams.Product.streamSI');
            set_param([name '/Reactor'],'Micromixing','Maximum mixedness');sim(name);
            second=evalin('base','nirpResults.Streams.Product.streamSI');
            relativeChange=abs(first.F(1)-second.F(1))/max(abs(first.F(1)),realmin);
            testCase.verifyGreaterThan(relativeChange,1e-5);
            seg=nirp.blocks.NonIdealReactor;seg.RTDOrigin='Model';seg.Model='CSTR';
            seg.Micromixing='Segregation';
            mm=nirp.blocks.NonIdealReactor;mm.RTDOrigin='Model';mm.Model='CSTR';
            mm.Micromixing='Maximum mixedness';
            testCase.verifySubstring(string(seg.iconText()),'SEG');
            testCase.verifySubstring(string(mm.iconText()),'MM');
        end

        function missingSpecificationsAndGasAreClear(testCase)
            name='nonideal_empty';createModel(testCase,name,nirp.pkg.examples.firstOrderLiquid());
            addStream(name,'F1','Feed',[20 100 100 150]);
            addUnit(name,'Reactor','nirp.blocks.NonIdealReactor',[180 85 330 165]);
            addStream(name,'Product','Product',[410 100 520 150]);
            add_line(name,'F1/1','Reactor/1');add_line(name,'Reactor/1','Product/1');
            finishModel(name);
            report=simulationFailure(name);
            testCase.verifySubstring(report,'RTDOrigin');
            testCase.verifySubstring(report,'Micromixing');
            close_system(name,0);Simulink.data.dictionary.closeAll('-discard');

            pkg=nirp.pkg.examples.firstOrderLiquid();pkg.feeds.phase="G";pkg.feeds.Q=[];
            name='nonideal_gas';createModel(testCase,name,pkg);
            addStream(name,'F1','Feed',[20 100 100 150]);
            addUnit(name,'Reactor','nirp.blocks.NonIdealReactor',[180 85 330 165], ...
                'RTDOrigin','Model','Model','CSTR','SizeBasis','Residence time', ...
                'Tau','2','Micromixing','Segregation');
            addStream(name,'Product','Product',[410 100 520 150]);
            add_line(name,'F1/1','Reactor/1');add_line(name,'Reactor/1','Product/1');
            finishModel(name);report=simulationFailure(name);
            testCase.verifySubstring(report,'constant-flow liquids only');
        end

        function cyclesThroughNonIdealAreRejectedButOtherCyclesRemain(testCase)
            name='nonideal_cycle';createModel(testCase,name,nirp.pkg.examples.firstOrderLiquid());
            addStream(name,'F1','Feed',[20 80 90 130]);
            addUnit(name,'Mixer','nirp.blocks.Mixer',[140 70 240 140]);
            addUnit(name,'Reactor','nirp.blocks.NonIdealReactor',[290 65 440 145], ...
                'RTDOrigin','Model','Model','CSTR','SizeBasis','Residence time', ...
                'Tau','2','Micromixing','Segregation');
            addUnit(name,'Splitter','nirp.blocks.Splitter',[490 60 600 150], ...
                'Fractions','[0.5 0.5]');
            addUnit(name,'Recycle','nirp.blocks.Recycle',[300 210 430 270]);
            add_line(name,'F1/1','Mixer/1');add_line(name,'Recycle/1','Mixer/2');
            add_line(name,'Mixer/1','Reactor/1');add_line(name,'Reactor/1','Splitter/1');
            add_line(name,'Splitter/2','Recycle/1');
            testCase.verifyError(@() nirp.flowsheet.checkTopology(name), ...
                'nirp:flowsheet:nonIdealReactorCycle');
            close_system(name,0);Simulink.data.dictionary.closeAll('-discard');

            name='cycle_other_branch';createModel(testCase,name,nirp.pkg.examples.firstOrderLiquid());
            addStream(name,'F1','Feed',[20 50 90 100]);
            addUnit(name,'Non ideal','nirp.blocks.NonIdealReactor',[150 35 300 115], ...
                'RTDOrigin','Model','Model','CSTR','SizeBasis','Residence time', ...
                'Tau','2','Micromixing','Segregation');
            addStream(name,'Product','Product',[360 50 470 100]);
            addUnit(name,'Mixer','nirp.blocks.Mixer',[150 200 240 270]);
            addUnit(name,'CSTR','nirp.blocks.CSTR',[290 195 390 275]);
            addUnit(name,'Splitter','nirp.blocks.Splitter',[440 190 540 280]);
            addUnit(name,'Recycle','nirp.blocks.Recycle',[280 330 410 390]);
            add_line(name,'F1/1','Non ideal/1');add_line(name,'Non ideal/1','Product/1');
            add_line(name,'F1/1','Mixer/1');add_line(name,'Recycle/1','Mixer/2');
            add_line(name,'Mixer/1','CSTR/1');add_line(name,'CSTR/1','Splitter/1');
            add_line(name,'Splitter/2','Recycle/1');
            previous=warning('off','nirp:flowsheet:missingStream');
            testCase.addTeardown(@() warning(previous.state,'nirp:flowsheet:missingStream'));
            testCase.verifyWarningFree(@() nirp.flowsheet.checkTopology(name));
        end

        function adjustVolumeConvergesAndResultsUseSnapshot(testCase)
            name='nonideal_adjust';createModel(testCase,name,nirp.pkg.examples.firstOrderLiquid());
            addStream(name,'F1','Feed',[20 100 100 150]);
            addUnit(name,'Reactor','nirp.blocks.NonIdealReactor',[250 85 410 165], ...
                'RTDOrigin','Model','Model','CSTR','SizeBasis','Volume', ...
                'SizeSource','Input port','Micromixing','Maximum mixedness');
            addStream(name,'Product','Product',[480 100 590 150], ...
                'ReferenceFeed','F1','KeyComponent','A');
            addUnit(name,'Adjust','nirp.blocks.Adjust',[180 240 330 305], ...
                'TargetVariable','Conversion','KeyComponent','A','ReferenceFeed','F1', ...
                'TargetValue','0.5','InitialValue','0.05','MinValue','0.001', ...
                'MaxValue','0.5','ParameterUnit','m^3','Damping','0.5', ...
                'Tolerance','1e-8','Strategy','Simultaneous');
            add_line(name,'F1/1','Reactor/1');add_line(name,'Adjust/1','Reactor/2');
            add_line(name,'Reactor/1','Product/1');add_line(name,'Reactor/1','Adjust/1');
            finishModel(name);sim(name);results=evalin('base','nirpResults');
            testCase.verifyEqual(results.Streams.Product.conversion,0.5,'AbsTol',1e-7);
            info=results.Diagnostics.nonideal_adjust_Reactor.lastInfo;
            testCase.verifyEqual(info.V,0.1,'RelTol',1e-6);
            set_param([name '/Reactor'],'Micromixing','Segregation');
            tables=nirp.flowsheet.showResults(name,'NoWindow',true);
            row=tables.Units(tables.Units.Block=="Reactor",:);
            testCase.verifyEqual(row.Type,"NonIdealReactor");
            testCase.verifyEqual(row.Micromixing,"Maximum mixedness");
            testCase.verifyEqual(row.RTD,"CSTR");
            testCase.verifyEqual(row.Tau,info.tau,'RelTol',1e-12);
        end

        function adjustResidenceTimeConverges(testCase)
            name='nonideal_adjust_tau';createModel(testCase,name,nirp.pkg.examples.firstOrderLiquid());
            addStream(name,'F1','Feed',[20 100 100 150]);
            addUnit(name,'Reactor','nirp.blocks.NonIdealReactor',[250 85 410 165], ...
                'RTDOrigin','Model','Model','CSTR','SizeBasis','Residence time', ...
                'SizeSource','Input port','Micromixing','Maximum mixedness');
            addStream(name,'Product','Product',[480 100 590 150], ...
                'ReferenceFeed','F1','KeyComponent','A');
            addUnit(name,'Adjust','nirp.blocks.Adjust',[180 240 330 305], ...
                'TargetVariable','Conversion','KeyComponent','A','ReferenceFeed','F1', ...
                'TargetValue','0.5','InitialValue','50','MinValue','1', ...
                'MaxValue','500','ParameterUnit','s','Damping','0.5', ...
                'Tolerance','1e-8','Strategy','Simultaneous');
            add_line(name,'F1/1','Reactor/1');add_line(name,'Adjust/1','Reactor/2');
            add_line(name,'Reactor/1','Product/1');add_line(name,'Reactor/1','Adjust/1');
            finishModel(name);sim(name);results=evalin('base','nirpResults');
            testCase.verifyEqual(results.Streams.Product.conversion,0.5,'AbsTol',1e-7);
            info=results.Diagnostics.nonideal_adjust_tau_Reactor.lastInfo;
            testCase.verifyEqual(info.tau,100,'RelTol',1e-6);
            target=nirp.flowsheet.adjustTarget([name '/Adjust']);
            testCase.verifyEqual(target.Variable,"Tau");testCase.verifyEqual(target.Category,"Time");
        end
    end
end

function createModel(testCase,name,pkg)
nirp.flowsheet.new(name,pkg,testCase.Folder,'OpenModel',false);
load_system(fullfile(testCase.Folder,[name '.slx']));
% The template already contains a feed Stream F1; tests add their own.
if getSimulinkBlockHandle([name '/F1']) > 0, delete_block([name '/F1']); end
end

function addUnit(model,name,className,position,varargin)
add_block('simulink/User-Defined Functions/MATLAB System',[model '/' name], ...
    'System',className,'Position',position,varargin{:});
end

function addStream(model,name,role,position,varargin)
addUnit(model,name,'nirp.blocks.Stream',position,'Role',role,varargin{:});
end

function finishModel(name)
nirp.flowsheet.configure(name);save_system(name);
end

function [first,second]=simulateSeries(testCase,name,pkg,firstMode,secondMode)
createModel(testCase,name,pkg);addStream(name,'F1','Feed',[20 100 100 150]);
addUnit(name,'R1','nirp.blocks.NonIdealReactor',[160 80 300 160], ...
    'RTDOrigin','Model','Model','Tanks in series','SizeBasis','Residence time', ...
    'Tau','1','N','1','Micromixing',firstMode);
addStream(name,'R1 outlet','Intermediate',[350 100 460 150]);
addUnit(name,'R2','nirp.blocks.NonIdealReactor',[520 80 660 160], ...
    'RTDOrigin','Model','Model','Tanks in series','SizeBasis','Residence time', ...
    'Tau','2','N','100','Micromixing',secondMode);
addStream(name,'Product','Product',[720 100 830 150], ...
    'ReferenceFeed','F1','KeyComponent','A');
add_line(name,'F1/1','R1/1');add_line(name,'R1/1','R1 outlet/1');
add_line(name,'R1 outlet/1','R2/1');add_line(name,'R2/1','Product/1');
finishModel(name);sim(name);results=evalin('base','nirpResults');
first=results.Streams.R1Outlet.streamSI;second=results.Streams.Product.streamSI;
end

function params=nonIdealParams(model,tau,N,mixing)
rtd=struct('origin','model','model',model,'tau',tau,'N',N);
params=struct('rtd',rtd,'micromixing',mixing, ...
    'temperatureMode','inlet','computeHeat',false,'keyIndex',1);
end

function pkg=examPackage()
pkg.meta=struct('formatVersion',1,'name',"Exam January 2024", ...
    'thermodynamics',false);
cp=struct('type',"constant",'value',1,'unit',"J/(mol*K)");
pkg.components=struct('name',{"A","B","C","D","E"}, ...
    'Mw',{[],[],[],[],[]},'cp',{cp,cp,cp,cp,cp},'hf',{[],[],[],[],[]});
pkg.reactions.stoich=[-1 1 0 0 0;0 -1 1 0 0;-2 0 0 1 1;0 1 0 -1 -1];
pkg.reactions.DH=struct('value',zeros(1,4),'unit',"J/mol");
pkg.reactions.Tref=struct('value',298.15,'unit',"K");
pkg.reactions.rateUnits=struct('concentration',"mol/m^3",'time',"s");
expressions={"concentration(1)-2*concentration(2)","concentration(2)", ...
    "0.01*concentration(1)^2","0.001*concentration(4)*concentration(5)"};
common=struct('type',"expression",'k0',[],'Ea',[],'orders',[], ...
    'reverse',[],'expression',"");
pkg.reactions.kinetics=repmat(common,1,4);
for i=1:4,pkg.reactions.kinetics(i).expression=expressions{i};end
pkg.feeds=struct('name',"F1",'phase',"L", ...
    'T',struct('value',298.15,'unit',"K"), ...
    'P',struct('value',101325,'unit',"Pa"),'basis',"concentrations", ...
    'values',[1000 0 0 0 0],'valuesUnit',"mol/m^3", ...
    'Q',struct('value',5e-5,'unit',"m^3/s"));
nirp.pkg.validate(pkg);
end

function report=simulationFailure(name)
try
    sim(name);report='';
catch exception
    report=getReport(exception,'basic','hyperlinks','off');
end
if isempty(report),error('NirpNonIdealReactorBlockTest:expectedFailure', ...
        'Expected simulation to fail.');end
end

function closeModels()
bdclose('all');Simulink.data.dictionary.closeAll('-discard');
evalin('base','clear nirpResults');
end

function removePath(folder)
if contains([path pathsep],[folder pathsep]),rmpath(folder);end
end
