function preview = afterApply(model,statusLabel)
%AFTERAPPLY Refresh preview after a successful dialog Apply or OK action.
%   Calculation errors are stored in the preview and never shown as modal
%   alerts. A slow refresh is reported on the dialog status line.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 15, 2026. Last update: October 15, 2026
% =========================================================================

    if nargin<2,statusLabel=[];end
    hasStatus=~isempty(statusLabel)&&isvalid(statusLabel);
    if hasStatus
        previousStatus=statusLabel.Text;
        statusLabel.Text='Calculating before run...';
        drawnow limitrate
    end
    try
        preview=nirp.flowsheet.propagate(model);
        if hasStatus
            if preview.Elapsed>2
                statusLabel.Text=sprintf('%s - calculated before run in %.2f s',previousStatus,preview.Elapsed);
            else
                statusLabel.Text=previousStatus;
            end
        end
    catch exception
        preview=nirp.flowsheet.preview('get',model);
        if hasStatus
            statusLabel.Text=['Preview unavailable: ' erase(exception.message,newline)];
        end
    end
end
