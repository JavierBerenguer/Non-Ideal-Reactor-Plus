function editor = newFromTemplate(varargin)
%NEWFROMTEMPLATE Open the package editor with the liquid template loaded.
%   EDITOR = nirp.flowsheet.newFromTemplate('Visible','off') supports tests.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    editor = nirp.flowsheet.PackageEditor(varargin{:}) ;
end
