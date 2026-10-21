classdef Monitor < matlab.System
    % Monitor publishes the latest tracer result for the headless/UI viewer.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 22, 2026. Last update: October 22, 2026
    % =========================================================================
    properties (Nontunable),Dt=0.1;TFinal=10;LostAreaWarning=0.01;ShowViewer=true;end
    properties (Access=private),LastResult;end
    methods (Access=protected)
        function setupImpl(obj),nirp.tracer.grid(obj.Dt,obj.TFinal);nirp.tracerflowsheet.validateSeparation(bdroot(gcb));end
        function stepImpl(obj,in)
            grid=nirp.tracer.grid(obj.Dt,obj.TFinal);value=in;value.C=reshape(value.C,1,[]);value.E=reshape(value.E,1,[]);
            rawRtdMoments=nirp.tracer.moments(grid,value.E);expectedTau=networkTau(gcb,grid);tauCorrection=expectedTau-rawRtdMoments.tau;
            result=struct('grid',grid,'stream',value,'sourceSignal',sourceSignal(grid,value.sourceId), ...
                'concentrationMoments',nirp.tracerflowsheet.presentationMoments(grid,value.C,tauCorrection),'rtdMoments',[],'warning','');
            if value.status==1,result.rtdMoments=nirp.tracerflowsheet.presentationMoments(grid,value.E,tauCorrection);if result.rtdMoments.area<1-obj.LostAreaWarning,result.warning='More than the configured RTD area is truncated; increase t_final.';end
            else,result.warning='Global RTD is undefined because the network contains multiple sources.';end
            allResults=struct();if evalin('base','exist(''nirpTracerResults'',''var'')'),allResults=evalin('base','nirpTracerResults');end
            key=matlab.lang.makeValidName([bdroot(gcb) '_' get_param(gcb,'Name')]);allResults.(key)=result;assignin('base','nirpTracerResults',allResults);
            obj.LastResult=result;
        end
        function terminateImpl(obj)
            if obj.ShowViewer
                result=obj.LastResult;
                if isstruct(result)&&isfield(result,'stream'),nirp.tracerflowsheet.showResults(result);end
            end
        end
        function n=getNumOutputsImpl(~),n=0;end
        function name=getInputNamesImpl(~),name='Tracer';end
        function icon=getIconImpl(~),icon=sprintf('Tracer Monitor\nC(t), E(t)');end
    end
    methods (Static,Access=protected)
        function mode=getSimulateUsingImpl(),mode='Interpreted execution';end
        function flag=showSimulateUsingImpl(),flag=false;end
    end
end

function C=sourceSignal(grid,sourceId)
C=nan(size(grid.t));
if sourceId==0,return,end
blocks=find_system(bdroot(gcb),'SearchDepth',1,'BlockType','MATLABSystem','System','nirp.tracerblocks.Source');
matches=false(size(blocks));
for k=1:numel(blocks),matches(k)=uint32(str2double(get_param(blocks{k},'SourceId')))==uint32(sourceId);end
blocks=blocks(matches);
if numel(blocks)~=1,return,end
b=blocks{1};mode=get_param(b,'SignalMode');Q=str2double(get_param(b,'Q'));id=uint32(str2double(get_param(b,'SourceId')));
if strcmpi(mode,'Data')
    s=nirp.tracer.sourceData(grid,Q,str2num(get_param(b,'DataTime')),str2num(get_param(b,'DataConcentration')),id); %#ok<ST2NM>
else
    edges=str2num(get_param(b,'FunctionEdges'));expressions=eval(get_param(b,'FunctionExpressions')); %#ok<ST2NM,EVLDIR>
    expressions=cellstr(string(expressions));functions=cell(size(expressions));
    for k=1:numel(expressions),functions{k}=str2func(['@(t)' expressions{k}]);end
    s=nirp.tracer.sourceFunction(grid,Q,edges,functions,id);
end
C=s.C;
end

function tau=networkTau(monitor,grid)
[tau,~]=blockTau(upstream(monitor,1),grid,1);
end
function [tau,Q]=blockTau(block,grid,outputPort)
className=string(get_param(block,'System'));
switch className
    case "nirp.tracerblocks.Source"
        tau=0;Q=str2double(get_param(block,'Q'));
    case "nirp.tracerblocks.Vessel"
        [tau,Q]=blockTau(upstream(block,1),grid,1);E=vesselRtd(block,grid,Q);
        tau=tau+nirp.conv.moments(nirp.conv.signal(grid.t,E)).mean;
    case "nirp.tracerblocks.Splitter"
        [tau,Q]=blockTau(upstream(block,1),grid,1);fractions=str2num(get_param(block,'Fractions')); %#ok<ST2NM>
        fractions=[fractions 1-sum(fractions)];Q=Q*fractions(outputPort);
    case "nirp.tracerblocks.Mixer"
        ports=get_param(block,'PortHandles');taus=zeros(size(ports.Inport));flows=taus;
        for k=1:numel(ports.Inport),source=get_param(get_param(ports.Inport(k),'Line'),'SrcPortHandle');[taus(k),flows(k)]=blockTau(get_param(source,'Parent'),grid,get_param(source,'PortNumber'));end
        Q=sum(flows);tau=sum(flows.*taus)/Q;
    otherwise
        error('nirp:tracerblocks:UnsupportedTopology','Unsupported block upstream of Tracer Monitor: %s.',className);
end
end
function block=upstream(block,inputPort)
ports=get_param(block,'PortHandles');line=get_param(ports.Inport(inputPort),'Line');
if line<0,error('nirp:tracerblocks:UnconnectedMonitor','Tracer Monitor has an unconnected upstream path.'),end
source=get_param(line,'SrcPortHandle');if source<0,error('nirp:tracerblocks:UnconnectedMonitor','Tracer Monitor has an unconnected upstream path.'),end
block=get_param(source,'Parent');
end
function E=vesselRtd(block,grid,Q)
origin=get_param(block,'Origin');
switch lower(origin)
    case 'model'
        if strcmpi(get_param(block,'ResidenceBasis'),'Volume'),parameters=struct('V',str2double(get_param(block,'Volume')));else,parameters=struct('tau',str2double(get_param(block,'Tau')));end
        model=get_param(block,'Model');if any(strcmpi(model,{'Tanks','Tanks in series','Tanks-in-series'})),parameters.N=str2double(get_param(block,'N'));end
        if strcmpi(model,'Dispersion'),parameters.Pe=str2double(get_param(block,'Pe'));parameters.boundary=get_param(block,'Boundary');end
        E=nirp.tracer.rtdModel(grid,model,parameters,Q);
    case 'data'
        E=nirp.tracer.rtdData(grid,str2num(get_param(block,'DataTime')),str2num(get_param(block,'DataE'))); %#ok<ST2NM>
    case 'session'
        E=nirp.tracer.rtdSession(grid,get_param(block,'SessionFile'));
end
end
