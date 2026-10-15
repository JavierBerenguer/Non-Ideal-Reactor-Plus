function preview = propagate(model)
%PROPAGATE Calculate all currently determined streams without simulation.
%   The material graph is visited to a fixed point. Recycle, Adjust and
%   unavailable signal ports are boundaries. Calculation failures are
%   recorded as waiting reasons and are not thrown into the UI.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 15, 2026. Last update: October 15, 2026
% =========================================================================

    started=tic;model=char(string(model));
    if ~bdIsLoaded(model),load_system(model);end
    graph=nirp.flowsheet.topology(model);
    pkg=nirp.pkg.readDictionary(nirp.flowsheet.modelDictionary(model));
    rs=nirp.pkg.toReactionSys(pkg);old=nirp.flowsheet.preview('get',model);
    preview=struct('Model',string(model),'Streams',struct(),'Blocks',struct(), ...
        'Elapsed',0,'Complete',false,'GeneratedAt',datetime('now'));
    preview=seedFeeds(preview,graph,pkg,rs);
    order=unitOrder(graph);changed=true;
    while changed
        changed=false;
        for i=1:numel(order)
            key=char(order(i));unit=graph.Units.(key);
            if isfield(preview.Blocks,key)&&strcmp(preview.Blocks.(key).status,'calculated'),continue,end
            [ready,inputs,reason]=materialInputs(unit,preview);
            if ~ready,preview=markWaiting(preview,unit,reason);continue,end
            if unit.Type=="Recycle"
                preview=markWaiting(preview,unit,'Recycle requires Run.');continue
            end
            try
                [signals,signalReason]=signalInputs(char(unit.Path),pkg,rs);
                if strlength(signalReason)>0,preview=markWaiting(preview,unit,signalReason);continue,end
                signature=blockSignature(char(unit.Path),inputs,signals,pkg);
                cached=cachedBlock(old,key,signature);
                if isempty(cached)
                    [outputs,info]=nirp.blocks.internal.evaluate(char(unit.Path),inputs, ...
                        'Signals',signals,'Package',pkg,'ReactionSystem',rs);
                    count=previousCount(old,key)+1;
                else
                    outputs=cached.outputs;info=cached.info;count=cached.calculationCount;
                end
                item=struct('status','calculated','reason','', ...
                    'signature',signature,'outputs',{outputs},'info',info, ...
                    'calculationCount',count);
                preview.Blocks.(key)=item;
                [preview,published]=publishOutputs(preview,unit,outputs);
                changed=changed||published;
            catch exception
                preview=markWaiting(preview,unit,cleanReason(exception));
            end
        end
    end
    preview=completeWaitingStreams(preview,graph);
    preview.Elapsed=toc(started);
    fields=fieldnames(preview.Streams);
    preview.Complete=~isempty(fields)&&all(cellfun(@(f)strcmp(preview.Streams.(f).status,'calculated'),fields));
    nirp.flowsheet.preview('set',model,preview);
end

function preview=seedFeeds(preview,graph,pkg,rs)
    names=fieldnames(graph.Streams);
    for i=1:numel(names)
        item=graph.Streams.(names{i});
        if item.Role~="Feed",continue,end
        try
            if hasConnectedInputs(char(item.Path))
                error('nirp:flowsheet:waitingFor','Feed signal inputs are available only during Run.');
            end
            outputs=nirp.blocks.internal.evaluate(char(item.Path),{},'Package',pkg,'ReactionSystem',rs);
            preview.Streams.(names{i})=streamItem(outputs{1},'calculated','',item.Path);
        catch exception
            preview.Streams.(names{i})=streamItem([],'waiting',cleanReason(exception),item.Path);
        end
    end
end

function order=unitOrder(graph)
    keys=fieldnames(graph.Units);score=inf(size(keys));
    for i=1:numel(keys)
        streams=graph.Units.(keys{i}).Inputs;flat=strings(0,1);
        for j=1:numel(streams),flat=[flat;string(streams{j}(:))];end %#ok<AGROW>
        positions=arrayfun(@(n)find(graph.Order==n,1),flat,'UniformOutput',false);
        positions=cell2mat(positions(~cellfun(@isempty,positions)));
        if ~isempty(positions),score(i)=min(positions);end
    end
    [~,index]=sort(score,'ascend');order=string(keys(index));
end

function [ready,inputs,reason]=materialInputs(unit,preview)
    inputs={};reason="";ready=true;
    for port=1:numel(unit.Inputs)
        names=string(unit.Inputs{port});
        if isempty(names),continue,end
        name=names(1);key=matlab.lang.makeValidName(name);
        if ~isfield(preview.Streams,key)||~strcmp(preview.Streams.(key).status,'calculated')
            ready=false;reason="Waiting for: "+name;return
        end
        inputs{end+1}=preview.Streams.(key).streamSI; %#ok<AGROW>
    end
    expected=1;if unit.Type=="Mixer",expected=str2double(get_param(char(unit.Path),'NumInputs'));end
    if numel(inputs)<expected,ready=false;reason=sprintf('Waiting for: %d material input(s).',expected);end
end

function [signals,reason]=signalInputs(block,pkg,rs)
    signals={};reason="";ports=get_param(block,'PortHandles');
    if ~isfield(ports,'Inport')||numel(ports.Inport)<=1,return,end
    for i=2:numel(ports.Inport)
        line=get_param(ports.Inport(i),'Line');
        if line==-1,reason=sprintf('Waiting for: signal input %d.',i);return,end
        source=get_param(line,'SrcBlockHandle');
        if numel(source)~=1||source==-1,reason=sprintf('Waiting for: signal input %d.',i);return,end
        class=string(get_param(source,'System'));
        if class=="nirp.blocks.Stream",continue,end
        if class~="nirp.blocks.Jacket"
            reason="Waiting for: signal from "+string(get_param(source,'Name'))+" (available during Run).";return
        end
        try
            value=nirp.blocks.internal.evaluate(getfullname(source),{},'Package',pkg,'ReactionSystem',rs);
            signals{end+1}=value{1}; %#ok<AGROW>
        catch exception
            reason="Waiting for: "+cleanReason(exception);return
        end
    end
end

function signature=blockSignature(block,inputs,signals,pkg)
    parameters=get_param(block,'DialogParameters');names=sort(fieldnames(parameters));values=struct();
    for i=1:numel(names)
        try
            values.(names{i})=get_param(block,names{i});
        catch
            values.(names{i})=[];
        end
    end
    signature=struct('parameters',values,'inputs',{inputs},'signals',{signals},'package',pkg);
end

function item=cachedBlock(old,key,signature)
    item=[];
    if isstruct(old)&&isfield(old,'Blocks')&&isfield(old.Blocks,key)
        candidate=old.Blocks.(key);
        if isfield(candidate,'status')&&strcmp(candidate.status,'calculated')&& ...
                isfield(candidate,'signature')&&isequaln(candidate.signature,signature)
            item=candidate;
        end
    end
end

function count=previousCount(old,key)
    count=0;if isstruct(old)&&isfield(old,'Blocks')&&isfield(old.Blocks,key)&&isfield(old.Blocks.(key),'calculationCount'),count=old.Blocks.(key).calculationCount;end
end

function [preview,published]=publishOutputs(preview,unit,outputs)
    published=false;
    for port=1:numel(unit.Outputs)
        if port>numel(outputs),continue,end
        names=string(unit.Outputs{port});
        for j=1:numel(names)
            key=matlab.lang.makeValidName(names(j));new=streamItem(outputs{port},'calculated','',unit.Path);
            if ~isfield(preview.Streams,key)||~isequaln(preview.Streams.(key),new),preview.Streams.(key)=new;published=true;end
        end
    end
end

function preview=markWaiting(preview,unit,reason)
    key=matlab.lang.makeValidName(unit.Name);
    preview.Blocks.(key)=struct('status','waiting','reason',char(reason), ...
        'signature',[],'outputs',{{}},'info',struct(),'calculationCount',previousCount(preview,key));
end

function preview=completeWaitingStreams(preview,graph)
    names=fieldnames(graph.Streams);
    for i=1:numel(names)
        if isfield(preview.Streams,names{i}),continue,end
        stream=graph.Streams.(names{i});reason='Waiting for: upstream block.';
        if ~isempty(stream.Producer)
            producerKey=matlab.lang.makeValidName(stream.Producer(1));
            if isfield(preview.Blocks,producerKey),reason=preview.Blocks.(producerKey).reason;end
        end
        preview.Streams.(names{i})=streamItem([],'waiting',reason,stream.Path);
    end
end

function value=streamItem(stream,status,reason,source)
    value=struct('streamSI',stream,'status',status,'reason',char(reason),'source',string(source));
end
function flag=hasConnectedInputs(block),ports=get_param(block,'PortHandles');flag=isfield(ports,'Inport')&&any(arrayfun(@(p)get_param(p,'Line')~=-1,ports.Inport));end
function reason=cleanReason(exception),reason=string(exception.message);reason=erase(reason,newline);if strlength(reason)==0,reason="Calculation failed.";end,end
