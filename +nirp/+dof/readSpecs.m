function specs = readSpecs(source)
%READSPECS Read specified SI values from JSON or a Simulink block.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================

    text=source ;
    if ischar(source)||isstring(source)
        candidate=char(string(source)) ;
        try
            if ~startsWith(strtrim(candidate),'{') && ~startsWith(strtrim(candidate),'[') && ...
                    ~isempty(candidate) && isfield(get_param(candidate,'ObjectParameters'),'Specifications')
                text=get_param(candidate,'Specifications') ;
            end
        catch
        end
    end
    text=strtrim(char(string(text))) ;
    if isempty(text),specs=struct();return,end
    try
        specs=jsondecode(text) ;
    catch exception
        error('nirp:dof:invalidSpecifications','Specifications must contain valid JSON: %s',exception.message) ;
    end
    if ~isstruct(specs)||~isscalar(specs)
        error('nirp:dof:invalidSpecifications','Specifications JSON must be an object.') ;
    end
    names=fieldnames(specs) ;
    for i=1:numel(names)
        item=specs.(names{i}) ;
        if ~isstruct(item)||~isscalar(item)||~isfield(item,'si')|| ...
                ~(isnumeric(item.si)&&isscalar(item.si)&&isfinite(item.si))
            error('nirp:dof:invalidSpecifications','Specification "%s" must have one finite numeric SI value.',names{i}) ;
        end
        if ~isfield(item,'unit'),item.unit='';end
        specs.(names{i})=struct('si',double(item.si),'unit',char(string(item.unit))) ;
    end
end
