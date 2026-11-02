function validateSeparation(model)
%VALIDATESEPARATION Reject direct ideal/tracer flowsheet connections.
%   The error names both connected blocks so a drawn invalid line is easy
%   to find. It is called by tracer dialogs and every tracer block setup.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================
    root=bdroot(model) ;
    blocks=find_system(root,'LookUnderMasks','all','FollowLinks','on', ...
        'Type','Block','BlockType','MATLABSystem') ;
    for k=1:numel(blocks)
        systemName=string(get_param(blocks{k},'System')) ;
        if ~startsWith(systemName,"nirp.tracerblocks."), continue, end
        ports=get_param(blocks{k},'PortHandles') ;
        handles=[ports.Inport(:);ports.Outport(:)] ;
        for j=1:numel(handles)
            line=get_param(handles(j),'Line') ;
            if line<0, continue, end
            source=get_param(line,'SrcBlockHandle') ;
            destinations=get_param(line,'DstBlockHandle') ;
            endpoints=[source(:);destinations(:)] ;
            endpoints=unique(endpoints(endpoints>0)) ;
            for n=1:numel(endpoints)
                other=getfullname(endpoints(n)) ;
                if strcmp(other,blocks{k}) || ~strcmp(get_param(other,'BlockType'),'MATLABSystem'), continue, end
                otherSystem=string(get_param(other,'System')) ;
                if startsWith(otherSystem,"nirp.blocks.")
                    error('nirp:tracerflowsheet:MixedFlowsheets', ...
                        ['Tracer block "%s" is connected to ideal flowsheet block "%s". ' ...
                        'NirpTracer and NirpStream networks must remain separate.'], ...
                        get_param(blocks{k},'Name'),get_param(other,'Name')) ;
                end
            end
        end
    end
end
