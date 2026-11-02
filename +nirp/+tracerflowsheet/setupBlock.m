function setupBlock(block)
%SETUPBLOCK Install the structured editor for a tracer block.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================
    block=getfullname(block) ; className=string(get_param(block,'System')) ;
    switch className
        case "nirp.tracerblocks.Flowsheet", dialog='FlowsheetDialog' ;
        case "nirp.tracerblocks.Source", dialog='SourceDialog' ;
        case "nirp.tracerblocks.Vessel", dialog='VesselDialog' ;
        case "nirp.tracerblocks.Splitter", dialog='SplitterDialog' ;
        case "nirp.tracerblocks.Mixer", dialog='MixerDialog' ;
        case "nirp.tracerblocks.Monitor", dialog='MonitorDialog' ;
        otherwise, return
    end
    if className~="nirp.tracerblocks.Flowsheet"
        coordinators=find_system(bdroot(block),'SearchDepth',1,'BlockType','MATLABSystem', ...
            'System','nirp.tracerblocks.Flowsheet') ;
        if numel(coordinators)==1 && hasParameter(coordinators{1},'Dt') && ...
                hasParameter(block,'Dt')
            set_param(block,'Dt',get_param(coordinators{1},'Dt'), ...
                'TFinal',get_param(coordinators{1},'TFinal')) ;
        end
    end
    set_param(block,'OpenFcn',sprintf('nirp.tracerflowsheet.%s.open(gcb);',dialog), ...
        'LoadFcn','nirp.tracerflowsheet.setupBlock(gcb);') ;
end
function value=hasParameter(block,name),parameters=get_param(block,'DialogParameters');value=isstruct(parameters)&&isfield(parameters,name);end
