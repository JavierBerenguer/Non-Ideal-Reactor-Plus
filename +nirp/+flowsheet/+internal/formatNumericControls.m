function formatNumericControls(parent)
%FORMATNUMERICCONTROLS Show numeric edit fields with significant digits.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================
    controls=findall(parent);
    for index=1:numel(controls)
        if isprop(controls(index),'ValueDisplayFormat')
            controls(index).ValueDisplayFormat='%.4g';
        end
    end
end
