function text=formatTableNumber(value)
%FORMATTABLENUMBER Format one table value with significant digits.
%   The table shows six significant digits. Calculation state remains in
%   SI at full precision and a user edit supplies the unrounded NewData.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================
    if isnumeric(value)&&isscalar(value)&&isfinite(value)
        text=sprintf('%.6g',value);
    else
        text='';
    end
end
