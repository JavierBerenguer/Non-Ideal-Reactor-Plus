function [values,origin,message] = closeSum(values,total,tol)
%CLOSESUM Complete one missing value in a prescribed sum.
%   [VALUES,ORIGIN,MESSAGE] = CLOSESUM(VALUES,TOTAL,TOL) accepts a real
%   numeric vector whose missing entries are NaN. TOTAL and VALUES are
%   dimensionless for Splitter fractions. When exactly one entry is
%   missing, it is calculated from TOTAL minus the known values. TOL is an
%   absolute sum tolerance and defaults to 1e-12.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 3, 2026. Last update: October 3, 2026
% =========================================================================

    if nargin < 3 || isempty(tol)
        tol = 1e-12;
    end
    if ~isnumeric(values) || ~isreal(values) || ~isvector(values) || ...
            isempty(values)
        error('nirp:flowsheet:invalidValues', ...
            'values must be a nonempty real numeric vector.');
    end
    if ~isnumeric(total) || ~isreal(total) || ~isscalar(total) || ...
            ~isfinite(total) || total < 0
        error('nirp:flowsheet:invalidTotal', ...
            'total must be a finite nonnegative real scalar.');
    end
    if ~isnumeric(tol) || ~isreal(tol) || ~isscalar(tol) || ...
            ~isfinite(tol) || tol < 0
        error('nirp:flowsheet:invalidTolerance', ...
            'tol must be a finite nonnegative real scalar.');
    end

    origin = repmat("specified",size(values));
    message = "";
    known = ~isnan(values);
    if any(~isfinite(values(known)))
        message = "Fractions must be finite or missing.";
        return
    end
    if any(values(known) < 0)
        message = "Fractions cannot be negative.";
        return
    end
    if any(values(known) > total)
        message = "Fractions cannot exceed " + formatNumber(total) + ".";
        return
    end

    missingCount = sum(~known);
    knownSum = sum(values(known));
    if knownSum > total + tol
        message = "Known fractions add up to " + formatNumber(knownSum) + ...
            " (> " + formatNumber(total) + ").";
        return
    end
    if missingCount >= 2
        message = string(sprintf( ...
            '%d fractions are missing; specify at least %d more.', ...
            missingCount,missingCount-1));
        return
    end
    if missingCount == 1
        missingValue = total-knownSum;
        if missingValue < 0 && missingValue >= -tol
            missingValue = 0;
        end
        values(~known) = missingValue;
        origin(~known) = "calculated";
        return
    end
    if abs(knownSum-total) > tol
        message = "Fractions add up to " + formatNumber(knownSum) + ...
            "; they must add up to " + formatNumber(total) + ".";
    end
end

function text = formatNumber(value)
    text = string(sprintf('%.15g',value));
end
