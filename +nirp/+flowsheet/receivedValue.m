function text = receivedValue(blockPath,field,category,unit,port)
%RECEIVEDVALUE Label for a block parameter that comes from an input port.
%   TEXT = nirp.flowsheet.receivedValue(BLOCK,FIELD,CATEGORY,UNIT,PORT)
%   returns the value received in the last run, converted to UNIT and with
%   the name of the block that sends it, or "From input port" if the model
%   has not been run yet (T-145). Streams read FIELD from their published
%   stream; other blocks read it from their last diagnostic info.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 10, 2026. Last update: October 10, 2026
% =========================================================================

    text = 'From input port' ;
    try
        block = getfullname(blockPath) ; model = bdroot(block) ;
        results = evalin('base','nirpResults') ;
        name = get_param(block,'Name') ;
        if string(get_param(block,'System')) == "nirp.blocks.Stream"
            value = results.Streams.(matlab.lang.makeValidName(name)).streamSI.(field) ;
        else
            key = matlab.lang.makeValidName([model '_' name]) ;
            value = results.Diagnostics.(key).lastInfo.(field) ;
        end
        value = UnitConverterHelper.convertFromSI(category,value,char(unit)) ;
        if ~(isscalar(value) && isfinite(value)), return, end
        source = 'input port' ;
        ports = get_param(block,'PortHandles') ;
        line = get_param(ports.Inport(port),'Line') ;
        if line ~= -1 && get_param(line,'SrcBlockHandle') ~= -1
            source = get_param(get_param(line,'SrcBlockHandle'),'Name') ;
        end
        text = sprintf('%.6g %s (from %s)',value,char(unit),source) ;
    catch
    end
end
