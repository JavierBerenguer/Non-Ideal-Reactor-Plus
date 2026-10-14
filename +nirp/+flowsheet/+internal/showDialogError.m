function showDialogError(figureHandle,message,title)
%SHOWDIALOGERROR Display a non-closing validation alert for an OK action.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================
    if isvalid(figureHandle)&&strcmp(figureHandle.Visible,'on')
        uialert(figureHandle,char(string(message)),char(string(title)),'Icon','error');
    end
end
