function nComp = busComponentCount(block)
%BUSCOMPONENTCOUNT Read the persisted reactive-field width of NirpTracer.
%   The reactive fields remain in the bus for compatibility with saved
%   tracer models, even though tracer blocks no longer use their values.
% =========================================================================
% Javier Berenguer Sabater
% Created: November 3, 2026. Last update: November 3, 2026
% =========================================================================
    model = bdroot(block) ;
    if isempty(get_param(model,'DataDictionary'))
        error('nirp:tracerflowsheet:MissingDictionary', ...
            'The tracer model must use a data dictionary containing NirpTracer.') ;
    end
    try
        bus = Simulink.data.evalinGlobal(model,'NirpTracer') ;
    catch exception
        error('nirp:tracerflowsheet:MissingDictionary', ...
            'The tracer model has no readable NirpTracer bus: %s',exception.message) ;
    end
    names = string({bus.Elements.Name}) ;
    index = find(names == "C0",1) ;
    if isempty(index)
        error('nirp:tracerflowsheet:InvalidTracerBus', ...
            'NirpTracer does not contain the compatibility field C0.') ;
    end
    dimensions = double(bus.Elements(index).Dimensions) ;
    nComp = prod(dimensions) ;
    if ~(isscalar(nComp) && isfinite(nComp) && nComp >= 1 && nComp == fix(nComp))
        error('nirp:tracerflowsheet:InvalidTracerBus', ...
            'The NirpTracer C0 field must have a fixed positive size.') ;
    end
end
