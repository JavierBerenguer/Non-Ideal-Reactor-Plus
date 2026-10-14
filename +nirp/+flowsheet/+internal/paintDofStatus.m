function paintDofStatus(label,status,message)
%PAINTDOFSTATUS Apply the common missing/complete/conflict status style.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================
    label.Text=char(string(message));
    switch char(string(status))
        case 'complete',label.BackgroundColor=[0.82 0.94 0.82];
        case 'conflict',label.BackgroundColor=[1 0.75 0.75];
        otherwise,label.BackgroundColor=[1 0.94 0.72];
    end
end
