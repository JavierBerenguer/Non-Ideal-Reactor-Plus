function validate(pkg)
%VALIDATE Validate a version-1 NIRP package without changing its units.
%   nirp.pkg.validate(PKG) raises nirp:pkg:invalid and identifies the
%   malformed field. Example: nirp.pkg.validate(pkg).
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 1, 2026
% =========================================================================

    requiredTop = {'meta','components','reactions','feeds'} ;
    if ~isstruct(pkg) || ~isscalar(pkg)
        fail('pkg','a scalar struct') ;
    end
    assertSimpleData(pkg,'pkg') ;
    for i = 1:numel(requiredTop)
        if ~isfield(pkg,requiredTop{i})
            fail(['pkg.' requiredTop{i}],'a required field') ;
        end
    end
    if ~isstruct(pkg.meta) || ~isscalar(pkg.meta) || ...
            ~isfield(pkg.meta,'formatVersion') || ...
            ~isequal(pkg.meta.formatVersion,1)
        fail('meta.formatVersion','the numeric value 1') ;
    end
    requireTextField(pkg.meta,'name','meta.name') ;

    components = pkg.components ;
    if ~isstruct(components) || isempty(components)
        fail('components','a nonempty struct array') ;
    end
    componentFields = {'name','Mw','cp','hf'} ;
    requireFields(components,componentFields,'components') ;
    nComp = numel(components) ;
    names = strings(1,nComp) ;
    for i = 1:nComp
        path = sprintf('components(%d)',i) ;
        names(i) = requireTextField(components(i),'name',[path '.name']) ;
        mw = components(i).Mw ;
        if ~(isempty(mw) || finiteScalar(mw) && mw > 0)
            fail([path '.Mw'],'[] or a positive scalar in g/mol') ;
        end
        cp = components(i).cp ;
        if ~isstruct(cp) || ~isscalar(cp) || ~isfield(cp,'type') || ~isfield(cp,'unit')
            fail([path '.cp'],'a scalar struct with type and unit') ;
        end
        cpType = lower(requireTextField(cp,'type',[path '.cp.type'])) ;
        requireUnit('MolarHeatCapacity',cp.unit,[path '.cp.unit']) ;
        if cpType == "constant"
            if ~isfield(cp,'value') || ~finiteScalar(cp.value)
                fail([path '.cp.value'],'a finite scalar') ;
            end
        elseif cpType == "polynomial"
            if ~isfield(cp,'coeffs') || ~finiteVector(cp.coeffs)
                fail([path '.cp.coeffs'],'a nonempty finite vector a0...an') ;
            end
        else
            fail([path '.cp.type'],'"constant" or "polynomial"') ;
        end
        if ~isempty(components(i).hf)
            validateQuantity(components(i).hf,'EnergyPerMol',[path '.hf']) ;
        end
    end
    if numel(unique(names)) ~= nComp
        fail('components.name','unique nonempty names') ;
    end

    reactions = pkg.reactions ;
    if ~isstruct(reactions) || ~isscalar(reactions)
        fail('reactions','a scalar struct') ;
    end
    reactionFields = {'stoich','DH','Tref','rateUnits','kinetics'} ;
    requireFields(reactions,reactionFields,'reactions') ;
    stoich = reactions.stoich ;
    if ~isnumeric(stoich) || ~isreal(stoich) || isempty(stoich) || ...
            any(~isfinite(stoich(:))) || size(stoich,2) ~= nComp
        fail('reactions.stoich',sprintf('a finite nR-by-%d matrix',nComp)) ;
    end
    nReactions = size(stoich,1) ;
    validateQuantity(reactions.DH,'EnergyPerMol','reactions.DH',nReactions) ;
    validateQuantity(reactions.Tref,'Temperature','reactions.Tref',1) ;
    rateUnits = reactions.rateUnits ;
    if ~isstruct(rateUnits) || ~isscalar(rateUnits) || ...
            ~isfield(rateUnits,'concentration') || ~isfield(rateUnits,'time')
        fail('reactions.rateUnits','concentration and time fields') ;
    end
    requireUnit('Concentration',rateUnits.concentration, ...
        'reactions.rateUnits.concentration') ;
    requireUnit('Time',rateUnits.time,'reactions.rateUnits.time') ;
    kinetics = reactions.kinetics ;
    if ~isstruct(kinetics) || isempty(kinetics) || ~isfield(kinetics,'type')
        fail('reactions.kinetics','a nonempty struct array with type') ;
    end
    types = strings(1,numel(kinetics)) ;
    for i = 1:numel(kinetics)
        types(i) = lower(requireTextField(kinetics(i),'type', ...
            sprintf('reactions.kinetics(%d).type',i))) ;
    end
    if any(types == "function")
        if numel(kinetics) ~= 1 || types(1) ~= "function"
            fail('reactions.kinetics','one function entry used by itself') ;
        end
        requireTextField(kinetics,'expression','reactions.kinetics(1).expression') ;
    elseif numel(kinetics) ~= nReactions
        fail('reactions.kinetics',sprintf('%d entries, one per reaction',nReactions)) ;
    end
    for i = 1:numel(kinetics)
        path = sprintf('reactions.kinetics(%d)',i) ;
        type = types(i) ;
        if type == "powerlaw" || type == "reversible"
            validateRateTerm(kinetics(i),path,nComp) ;
            if type == "reversible"
                if ~isfield(kinetics(i),'reverse') || ~isstruct(kinetics(i).reverse) || ...
                        ~isscalar(kinetics(i).reverse)
                    fail([path '.reverse'],'a scalar rate-term struct') ;
                end
                validateRateTerm(kinetics(i).reverse,[path '.reverse'],nComp) ;
            end
        elseif type == "expression" || type == "function"
            requireTextField(kinetics(i),'expression',[path '.expression']) ;
        else
            fail([path '.type'],'powerlaw, reversible, expression, or function') ;
        end
    end

    feeds = pkg.feeds ;
    if ~isstruct(feeds) || isempty(feeds)
        fail('feeds','a nonempty struct array') ;
    end
    feedFields = {'name','phase','T','P','basis','values','valuesUnit','Q'} ;
    requireFields(feeds,feedFields,'feeds') ;
    feedNameValues = strings(1,numel(feeds)) ;
    for i = 1:numel(feeds)
        feed = feeds(i) ;
        path = sprintf('feeds(%d)',i) ;
        feedNameValues(i) = requireTextField(feed,'name',[path '.name']) ;
        phase = upper(requireTextField(feed,'phase',[path '.phase'])) ;
        if phase ~= "L" && phase ~= "G"
            fail([path '.phase'],'"L" or "G"') ;
        end
        validateQuantity(feed.T,'Temperature',[path '.T'],1) ;
        validateQuantity(feed.P,'Pressure',[path '.P'],1) ;
        basis = lower(requireTextField(feed,'basis',[path '.basis'])) ;
        if ~finiteVector(feed.values)
            fail([path '.values'],'a nonempty finite numeric vector') ;
        end
        if basis == "molarflows"
            if numel(feed.values) ~= nComp
                fail([path '.values'],sprintf('%d component molar flows',nComp)) ;
            end
            requireUnit('MolarFlow',feed.valuesUnit,[path '.valuesUnit']) ;
        elseif basis == "concentrations"
            if numel(feed.values) ~= nComp
                fail([path '.values'],sprintf('%d component concentrations',nComp)) ;
            end
            requireUnit('Concentration',feed.valuesUnit,[path '.valuesUnit']) ;
        elseif basis == "totalandfractions"
            if numel(feed.values) ~= nComp+1 || any(feed.values(2:end) < 0) || ...
                    abs(sum(feed.values(2:end))-1) > 1e-12
                fail([path '.values'],sprintf('[total, %d fractions] summing to one',nComp)) ;
            end
            requireUnit('MolarFlow',feed.valuesUnit,[path '.valuesUnit']) ;
        else
            fail([path '.basis'],'molarFlows, concentrations, or totalAndFractions') ;
        end
        needsQ = phase == "L" || basis == "concentrations" ;
        if needsQ && isempty(feed.Q)
            fail([path '.Q'],'a volumetric flow for this phase and basis') ;
        end
        if ~isempty(feed.Q)
            validateQuantity(feed.Q,'VolumetricFlow',[path '.Q'],1) ;
        end
    end
    if numel(unique(feedNameValues)) ~= numel(feeds)
        fail('feeds.name','unique nonempty names') ;
    end
    if isfield(pkg,'streamSpecs')
        validateStreamSpecs(pkg.streamSpecs) ;
    end
end

function validateStreamSpecs(specs)
    if ~isstruct(specs) || ~isscalar(specs)
        fail('streamSpecs','a scalar struct indexed by stream name') ;
    end
    streams = fieldnames(specs) ;
    categoryMap = struct('F','MolarFlow','MolarFlow','MolarFlow', ...
        'C','Concentration','Concentration','Concentration', ...
        'T','Temperature','P','Pressure','Q','VolumetricFlow', ...
        'Density','Density','Viscosity','Viscosity') ;
    for i = 1:numel(streams)
        stream = specs.(streams{i}) ;
        path = ['streamSpecs.' streams{i}] ;
        if ~isstruct(stream) || ~isscalar(stream)
            fail(path,'a scalar struct of magnitude specifications') ;
        end
        magnitudes = fieldnames(stream) ;
        for j = 1:numel(magnitudes)
            magnitude = stream.(magnitudes{j}) ;
            magnitudePath = [path '.' magnitudes{j}] ;
            if ~isstruct(magnitude) || ~isscalar(magnitude) || ...
                    ~all(isfield(magnitude,{'value','unit','origin'}))
                fail(magnitudePath,'a scalar struct with value, unit, and origin') ;
            end
            if ~isnumeric(magnitude.value) || ~isreal(magnitude.value) || ...
                    isempty(magnitude.value) || any(~isfinite(magnitude.value(:)))
                fail([magnitudePath '.value'],'finite numeric data') ;
            end
            origin = lower(requireTextField(magnitude,'origin', ...
                [magnitudePath '.origin'])) ;
            if origin ~= "specified" && origin ~= "calculated"
                fail([magnitudePath '.origin'],'"specified" or "calculated"') ;
            end
            if isfield(categoryMap,magnitudes{j})
                requireUnit(categoryMap.(magnitudes{j}),magnitude.unit, ...
                    [magnitudePath '.unit']) ;
            else
                requireTextField(magnitude,'unit',[magnitudePath '.unit']) ;
            end
        end
    end
end

function validateRateTerm(term,path,nComp)
    fields = {'k0','Ea','orders'} ;
    requireFields(term,fields,path) ;
    if ~finiteScalar(term.k0) || term.k0 < 0
        fail([path '.k0'],'a finite nonnegative scalar') ;
    end
    validateQuantity(term.Ea,'EnergyPerMol',[path '.Ea'],1) ;
    if ~finiteVector(term.orders) || numel(term.orders) ~= nComp || any(term.orders < 0)
        fail([path '.orders'],sprintf('%d finite nonnegative orders',nComp)) ;
    end
end

function validateQuantity(q,category,path,expectedLength)
    if ~isstruct(q) || ~isscalar(q) || ~isfield(q,'value') || ~isfield(q,'unit')
        fail(path,'a scalar struct with value and unit') ;
    end
    if ~isnumeric(q.value) || ~isreal(q.value) || isempty(q.value) || ...
            any(~isfinite(q.value(:)))
        fail([path '.value'],'finite numeric data') ;
    end
    if nargin >= 4 && numel(q.value) ~= expectedLength
        fail([path '.value'],sprintf('%d value(s)',expectedLength)) ;
    end
    requireUnit(category,q.unit,[path '.unit']) ;
end

function requireUnit(category,unit,path)
    if ~(ischar(unit) || isstring(unit) && isscalar(unit))
        fail(path,['a valid ' category ' unit']) ;
    end
    unit = char(string(unit)) ;
    if strcmp(category,'Temperature') && strcmp(unit,'C')
        unit = [char(176) 'C'] ;
    end
    try
        units = UnitConverterHelper.getUnits(category) ;
    catch
        fail(path,['a valid ' category ' unit']) ;
    end
    if ~any(strcmp(unit,units))
        fail(path,sprintf('a valid %s unit (%s)',category,strjoin(units,', '))) ;
    end
end

function value = requireTextField(s,field,path)
    if ~isfield(s,field) || ~(ischar(s.(field)) || ...
            isstring(s.(field)) && isscalar(s.(field))) || ...
            strlength(strtrim(string(s.(field)))) == 0
        fail(path,'nonempty scalar text') ;
    end
    value = strtrim(string(s.(field))) ;
end

function requireFields(s,fields,path)
    for i = 1:numel(fields)
        if ~isfield(s,fields{i})
            fail([path '.' fields{i}],'a required field') ;
        end
    end
end

function assertSimpleData(value,path)
    if isstruct(value)
        fields = fieldnames(value) ;
        for element = 1:numel(value)
            for i = 1:numel(fields)
                assertSimpleData(value(element).(fields{i}), ...
                    sprintf('%s(%d).%s',path,element,fields{i})) ;
            end
        end
    elseif iscell(value)
        for i = 1:numel(value)
            assertSimpleData(value{i},sprintf('%s{%d}',path,i)) ;
        end
    elseif ~(isnumeric(value) || islogical(value) || ischar(value) || isstring(value))
        fail(path,'simple text or numeric data (not objects or function handles)') ;
    end
end

function tf = finiteScalar(value)
    tf = isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value) ;
end

function tf = finiteVector(value)
    tf = isnumeric(value) && isreal(value) && isvector(value) && ...
        ~isempty(value) && all(isfinite(value(:))) ;
end

function fail(path,expected)
    error('nirp:pkg:invalid','Field %s must be %s.',path,expected) ;
end
