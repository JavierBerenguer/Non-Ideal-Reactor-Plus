function text=formatTableNumber(value)
%FORMATTABLENUMBER Format one table value with significant digits.
%   Fifteen significant digits avoid the fixed-decimal display without
%   changing values when an editable table is read back by a dialog.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================
    if isnumeric(value)&&isscalar(value)&&isfinite(value)
        text=sprintf('%.15g',value);
    else
        text='';
    end
end
