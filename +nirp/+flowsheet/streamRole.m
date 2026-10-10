function [role,isAuto,autoRole] = streamRole(block)
%STREAMROLE Return the effective role of a Stream block.
%   ROLE is the manually selected role unless Role is Auto. Auto streams
%   are Feed with only a material consumer, Product with only a material
%   producer, Intermediate with both, and Unconnected with neither.
%   Signal-only connections (including Adjust measurement connections) do
%   not take part in the deduction. AUTOROLE returns the connectivity-based
%   role even when a manual role currently overrides it.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 9, 2026. Last update: October 9, 2026
% =========================================================================

    block = getfullname(block) ;
    declared = string(get_param(block,'Role')) ;
    isAuto = declared == "Auto" ;
    connectivity = get_param(block,'PortConnectivity') ;
    hasProducer = hasMaterialNeighbor(connectivity,'in') ;
    hasConsumer = hasMaterialNeighbor(connectivity,'out') ;
    if hasProducer && hasConsumer
        autoRole = "Intermediate" ;
    elseif hasProducer
        autoRole = "Product" ;
    elseif hasConsumer
        autoRole = "Feed" ;
    else
        autoRole = "Unconnected" ;
    end
    if isAuto, role = autoRole ; else, role = declared ; end
end

function value = hasMaterialNeighbor(connectivity,direction)
    value = false ;
    for i = 1:numel(connectivity)
        if strcmp(direction,'in')
            handles = connectivity(i).SrcBlock ;
            ports = connectivity(i).SrcPort ;
        else
            handles = connectivity(i).DstBlock ;
            ports = connectivity(i).DstPort ;
        end
        for j = 1:numel(handles)
            handle = handles(j) ;
            if handle == -1, continue, end
            try
                className = string(get_param(handle,'System')) ;
            catch
                continue
            end
            if startsWith(className,"nirp.blocks.") && ...
                    ~any(className == ["nirp.blocks.Stream", ...
                    "nirp.blocks.Flowsheet","nirp.blocks.Adjust", ...
                    "nirp.blocks.Jacket"]) && ...
                    isMaterialPort(className,direction,ports(min(j,numel(ports))))
                value = true ;
                return
            end
        end
    end
end

function value = isMaterialPort(className,direction,port)
    % Simulink numbers ports from zero in PortConnectivity. Splitter has
    % only material outputs and Mixer has only material inputs; on every
    % other supported unit the material connection is port zero. Separator
    % outputs (Top and Bottom) are both material, like the Splitter (T-141).
    value = port == 0 || ...
        (strcmp(direction,'in') && any(className == ["nirp.blocks.Splitter","nirp.blocks.Separator"])) || ...
        (strcmp(direction,'out') && className == "nirp.blocks.Mixer") ;
end
