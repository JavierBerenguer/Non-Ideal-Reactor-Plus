function [outputs,fractions] = splitter(grid,in,specifiedFractions)
%SPLITTER Split a tracer stream into N outlets.
%   SPECIFIEDFRACTIONS contains N-1 fractions; the final fraction is the
%   remainder. Concentration, accumulated RTD, source, and state are copied.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================

    grid = nirp.tracer.validateGrid(grid) ;
    in = nirp.tracer.validateStream(in,grid) ;
    if ~(isnumeric(specifiedFractions) && isreal(specifiedFractions) && ...
            isvector(specifiedFractions) && ~isempty(specifiedFractions) && ...
            all(isfinite(specifiedFractions(:))) && all(specifiedFractions(:) >= 0))
        error('nirp:tracer:InvalidFractions', ...
            'Specified split fractions must be a nonempty nonnegative vector.') ;
    end
    specifiedFractions = reshape(double(specifiedFractions),1,[]) ;
    remainder = 1-sum(specifiedFractions) ;
    tolerance = 100*eps(max(1,sum(specifiedFractions))) ;
    if remainder < -tolerance
        error('nirp:tracer:InvalidFractions','Specified split fractions exceed one.') ;
    end
    fractions = [specifiedFractions max(0,remainder)] ;
    outputs = cell(1,numel(fractions)) ;
    for k = 1:numel(fractions)
        outputs{k} = in ;
        outputs{k}.Q = in.Q*fractions(k) ;
    end
end
