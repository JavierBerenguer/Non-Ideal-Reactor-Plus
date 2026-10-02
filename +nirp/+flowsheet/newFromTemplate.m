function editor = newFromTemplate(varargin)
%NEWFROMTEMPLATE Open the reactive-system editor with the liquid template.
%   EDITOR = nirp.flowsheet.newFromTemplate('Visible','off') supports tests.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    editor = nirp.flowsheet.ReactiveSystemDialog(varargin{:}) ;
end
