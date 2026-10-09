function target = adjustTarget(adjustBlock)
%ADJUSTTARGET Describe the parameter port driven by an Adjust block.
%   TARGET fields are Block, Port, Variable, Category, and Label. Block is
%   the full destination block path and Port is its one-based input index.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 9, 2026. Last update: October 9, 2026
% =========================================================================

    adjustBlock = getfullname(adjustBlock) ;
    if string(get_param(adjustBlock,'System')) ~= "nirp.blocks.Adjust"
        error('nirp:flowsheet:invalidBlock', ...
            'adjustTarget requires an Adjust block.') ;
    end
    target = emptyTarget() ;
    ports = get_param(adjustBlock,'PortHandles') ;
    if isempty(ports.Outport), return, end
    line = get_param(ports.Outport(1),'Line') ;
    if line == -1, return, end
    destinations = get_param(line,'DstPortHandle') ;
    destinations = destinations(destinations ~= -1) ;
    for destination = reshape(destinations,1,[])
        blockHandle = get_param(destination,'Parent') ;
        block = getfullname(blockHandle) ;
        inputPorts = get_param(block,'PortHandles') ;
        port = find(inputPorts.Inport == destination,1) ;
        [variable,category] = parameterAtPort(block,port) ;
        if strlength(variable) == 0, continue, end
        target.Block = string(block) ;
        target.Port = port ;
        target.Variable = variable ;
        target.Category = category ;
        target.Label = string(get_param(block,'Name'))+" / "+variable ;
        return
    end
end

function target = emptyTarget()
    target = struct('Block',"",'Port',NaN,'Variable',"", ...
        'Category',"",'Label',"<not connected>") ;
end

function [variable,category] = parameterAtPort(block,port)
    variable = "" ; category = "" ;
    try
        className = string(get_param(block,'System')) ;
    catch
        return
    end
    switch className
        case {"nirp.blocks.CSTR","nirp.blocks.PFR"}
            if strcmp(get_param(block,'VSource'),'Input port') && port == 2
                variable = "V" ; category = "Volume" ;
            end
        case "nirp.blocks.Jacket"
            index = 0 ;
            [variable,category,index] = activeParameter( ...
                block,port,index,'A','Area') ;
            if strlength(variable) == 0
                [variable,category] = activeParameter( ...
                    block,port,index,'UtilityTin','Temperature') ;
            end
        case "nirp.blocks.Stream"
            if nirp.flowsheet.streamRole(block) ~= "Feed", return, end
            index = 0 ;
            [variable,category,index] = activeParameter( ...
                block,port,index,'T','Temperature') ;
            if strlength(variable) == 0
                [variable,category] = activeParameter( ...
                    block,port,index,'Q','VolumetricFlow') ;
            end
    end
end

function [variable,category,index] = activeParameter( ...
        block,port,index,name,candidateCategory)
    variable = "" ; category = "" ;
    if strcmp(get_param(block,[name 'Source']),'Input port')
        index = index+1 ;
        if port == index
            variable = string(name) ; category = string(candidateCategory) ;
        end
    end
end
