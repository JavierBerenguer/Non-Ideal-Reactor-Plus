function rs = toReactionSys(pkg)
%TOREACTIONSYS Build a ReactionSys whose calculations use SI units.
%   RS = nirp.pkg.toReactionSys(PKG) converts heat data and wraps all
%   kinetics from the user's concentration/time units to mol/(m^3*s).
%   Example: rs = nirp.pkg.toReactionSys(pkg).
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 1, 2026
% =========================================================================

    nirp.pkg.validate(pkg) ;
    rs = ReactionSys ;
    rs.componentNames = cellstr(string({pkg.components.name})) ;
    molecularWeights = {pkg.components.Mw} ;
    if all(cellfun(@isempty,molecularWeights))
        rs.componentMw = [] ;
    else
        rs.componentMw = cellfun(@emptyToNaN,molecularWeights) ;
    end
    rs.stochiometricMatrix = pkg.reactions.stoich ;
    rs.DHref = convertQuantity(pkg.reactions.DH,'EnergyPerMol') ;
    rs.Tref = convertQuantity(pkg.reactions.Tref,'Temperature') ;

    allConstant = all(arrayfun(@(c) strcmpi(char(string(c.cp.type)), ...
        'constant'),pkg.components)) ;
    if allConstant
        cp = zeros(1,numel(pkg.components)) ;
        for i = 1:numel(cp)
            cp(i) = UnitConverterHelper.convertToSI('MolarHeatCapacity', ...
                pkg.components(i).cp.value,char(string(pkg.components(i).cp.unit))) ;
        end
        rs.componentCp = cp ;
    else
        functions = cell(1,numel(pkg.components)) ;
        for i = 1:numel(functions)
            cp = pkg.components(i).cp ;
            factor = UnitConverterHelper.factorToSI('MolarHeatCapacity', ...
                char(string(cp.unit))) ;
            if strcmpi(char(string(cp.type)),'constant')
                value = cp.value*factor ;
                functions{i} = @(T) value+zeros(size(T)) ;
            else
                coefficients = cp.coeffs(:)'*factor ;
                functions{i} = @(T) polynomialCp(coefficients,T) ;
            end
        end
        rs.componentCp = struct('option','Cp = f(T)','Function',{functions}) ;
    end

    if all(~cellfun(@isempty,{pkg.components.hf}))
        hf = zeros(1,numel(pkg.components)) ;
        for i = 1:numel(hf)
            hf(i) = convertQuantity(pkg.components(i).hf,'EnergyPerMol') ;
        end
        rs.componentHeatOfFormation = hf ;
    end

    concentrationFactor = UnitConverterHelper.factorToSI('Concentration', ...
        char(string(pkg.reactions.rateUnits.concentration))) ;
    timeFactor = UnitConverterHelper.factorToSI('Time', ...
        char(string(pkg.reactions.rateUnits.time))) ;
    kinetics = pkg.reactions.kinetics ;
    definitions = makeDefinitions(kinetics) ;
    rs.userDefinedKinetics = @(concentration,T) evaluateRates( ...
        definitions,concentration,T,concentrationFactor,timeFactor) ;
end

function definitions = makeDefinitions(kinetics)
    definitions = cell(1,numel(kinetics)) ;
    for i = 1:numel(kinetics)
        type = lower(char(string(kinetics(i).type))) ;
        definition = struct('type',type) ;
        if strcmp(type,'powerlaw') || strcmp(type,'reversible')
            definition.forward = rateTerm(kinetics(i)) ;
            if strcmp(type,'reversible')
                definition.reverse = rateTerm(kinetics(i).reverse) ;
            end
        elseif strcmp(type,'expression')
            definition.function = str2func(['@(concentration,T) ' ...
                char(string(kinetics(i).expression))]) ;
        else
            definition.function = str2func(char(string(kinetics(i).expression))) ;
        end
        definitions{i} = definition ;
    end
end

function term = rateTerm(source)
    term = struct('k0',source.k0,'Ea',convertQuantity(source.Ea, ...
        'EnergyPerMol'),'orders',source.orders(:)') ;
end

function rates = evaluateRates(definitions,concentration,T,cFactor,timeFactor)
    userConcentration = concentration(:)'/cFactor ;
    if strcmp(definitions{1}.type,'function')
        rates = definitions{1}.function(userConcentration,T) ;
    else
        rates = zeros(1,numel(definitions)) ;
        for i = 1:numel(definitions)
            definition = definitions{i} ;
            if strcmp(definition.type,'expression')
                rates(i) = definition.function(userConcentration,T) ;
            else
                rates(i) = evaluateTerm(definition.forward,userConcentration,T) ;
                if strcmp(definition.type,'reversible')
                    rates(i) = rates(i)-evaluateTerm( ...
                        definition.reverse,userConcentration,T) ;
                end
            end
        end
    end
    rates = rates(:)'*(cFactor/timeFactor) ;
end

function rate = evaluateTerm(term,concentration,T)
    rate = term.k0*exp(-term.Ea/(8.314*T))* ...
        prod(concentration.^term.orders) ;
end

function value = convertQuantity(q,category)
    unit = char(string(q.unit)) ;
    if strcmp(category,'Temperature') && strcmp(unit,'C')
        unit = [char(176) 'C'] ;
    end
    value = UnitConverterHelper.convertToSI(category,q.value,unit) ;
end

function value = emptyToNaN(value)
    if isempty(value)
        value = NaN ;
    end
end

function value = polynomialCp(coefficients,T)
    value = polyval(fliplr(coefficients),T) ;
end
