function [stream,source] = knownInlet(blockPath)
%KNOWNINLET Return a dialog-time inlet from a direct feed or the last run.
%   STREAM is an SI nirp.stream structure. SOURCE is empty when no inlet is
%   available, so inlet-dependent results remain external rather than user
%   specifications.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================

    blockPath=getfullname(blockPath);model=bdroot(blockPath);stream=[];source="";
    graph=nirp.flowsheet.topology(model);key=matlab.lang.makeValidName(get_param(blockPath,'Name'));
    if ~isfield(graph.Units,key)||isempty(graph.Units.(key).Inputs),return,end
    incoming=string(graph.Units.(key).Inputs{1});
    if isempty(incoming),return,end
    name=incoming(1);streamKey=matlab.lang.makeValidName(name);
    if isfield(graph.Streams,streamKey)&&graph.Streams.(streamKey).Role=="Feed"
        try
            pkg=nirp.pkg.readDictionary(nirp.flowsheet.modelDictionary(model));
            stream=nirp.pkg.feedStream(pkg,name);source="inlet from feed "+name;return
        catch
        end
    end
    if evalin('base','exist(''nirpResults'',''var'')')
        results=evalin('base','nirpResults');
        if isstruct(results)&&isfield(results,'Streams')&&isfield(results.Streams,streamKey)&& ...
                isfield(results.Streams.(streamKey),'streamSI')
            stream=results.Streams.(streamKey).streamSI;source="inlet from last run";
        end
    end
end
