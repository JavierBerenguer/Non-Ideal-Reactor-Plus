function s = feedStream(pkg,name)
%FEEDSTREAM Build a named package feed as a NIRP stream in SI units.
%   S = nirp.pkg.feedStream(PKG,NAME) supports molar flows,
%   concentrations, and total-flow-plus-fractions bases.
%   Example: s = nirp.pkg.feedStream(pkg,"F1").
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 1, 2026
% =========================================================================

    nirp.pkg.validate(pkg) ;
    names = string({pkg.feeds.name}) ;
    if ~(ischar(name) || isstring(name) && isscalar(name))
        error('nirp:pkg:invalid','Feed name must be scalar text.') ;
    end
    index = find(names == string(name),1) ;
    if isempty(index)
        error('nirp:pkg:invalid','Unknown feed "%s". Valid names: %s.', ...
            char(string(name)),strjoin(cellstr(names),', ')) ;
    end
    feed = pkg.feeds(index) ;
    T = convertQuantity(feed.T,'Temperature') ;
    P = convertQuantity(feed.P,'Pressure') ;
    if isempty(feed.Q)
        Q = [] ;
    else
        Q = convertQuantity(feed.Q,'VolumetricFlow') ;
    end
    basis = lower(char(string(feed.basis))) ;
    if strcmp(basis,'molarflows')
        F = UnitConverterHelper.convertToSI('MolarFlow',feed.values, ...
            char(string(feed.valuesUnit))) ;
    elseif strcmp(basis,'concentrations')
        concentration = UnitConverterHelper.convertToSI('Concentration', ...
            feed.values,char(string(feed.valuesUnit))) ;
        F = concentration*Q ;
    else
        total = UnitConverterHelper.convertToSI('MolarFlow',feed.values(1), ...
            char(string(feed.valuesUnit))) ;
        F = total*feed.values(2:end) ;
    end
    phase = double(strcmpi(char(string(feed.phase)),'G')) ;
    s = nirp.stream.create(F(:),T,P,phase,Q) ;
end

function value = convertQuantity(q,category)
    unit = char(string(q.unit)) ;
    if strcmp(category,'Temperature') && strcmp(unit,'C')
        unit = [char(176) 'C'] ;
    end
    value = UnitConverterHelper.convertToSI(category,q.value,unit) ;
end
