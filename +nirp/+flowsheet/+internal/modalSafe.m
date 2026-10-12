function varargout = modalSafe(fig,fcn)
%MODALSAFE Run a native modal dialog without hiding it behind a UI figure.
%   [OUT1,...] = nirp.flowsheet.internal.modalSafe(FIG,FCN) temporarily
%   changes an always-on-top UI figure to normal, invokes FCN, and restores
%   the original style even when FCN throws. Focus returns to a surviving,
%   visible FIG after the modal dialog closes.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 12, 2026. Last update: October 12, 2026
% =========================================================================

    if isempty(fig) || ~isvalid(fig)
        error('nirp:flowsheet:invalidFigure','FIG must be a valid figure.') ;
    end
    if ~isa(fcn,'function_handle')
        error('nirp:flowsheet:invalidCallback','FCN must be a function handle.') ;
    end

    previousStyle = fig.WindowStyle ;
    fig.WindowStyle = 'normal' ;
    cleanup = onCleanup(@() restoreFigure(fig,previousStyle)) ; %#ok<NASGU>
    [varargout{1:nargout}] = fcn() ;
end

function restoreFigure(fig,style)
    if isempty(fig) || ~isvalid(fig), return, end
    fig.WindowStyle = style ;
    if strcmp(fig.Visible,'on')
        drawnow ;
        try
            figure(fig) ;
        catch
            % Focus is best effort because MATLAB releases differ for UI
            % figures; restoring WindowStyle is the safety requirement.
        end
    end
end
