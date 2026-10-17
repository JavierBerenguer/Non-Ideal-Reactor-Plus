function styleDofTable(tableHandle,column,states)
%STYLEDOFTABLE Apply the common per-cell DOF colours to a UITable.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================
    removeStyle(tableHandle);states=string(states(:));
    definitions={"specified",[0.15 0.25 0.55],'normal'; ...
        "calculated",[0.92 0.92 0.92],'italic'; ...
        "empty",[1 0.90 0.90],'normal'; ...
        "external",[0.88 0.88 0.88],'normal'; ...
        "conflict",[1 0.72 0.72],'normal'};
    for i=1:size(definitions,1)
        rows=find(states==definitions{i,1});if isempty(rows),continue,end
        style=uistyle('FontAngle',definitions{i,3});
        if definitions{i,1}=="specified",style.FontColor=definitions{i,2};else,style.BackgroundColor=definitions{i,2};end
        addStyle(tableHandle,style,'cell',[rows repmat(column,numel(rows),1)]);
    end
end
