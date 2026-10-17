function text = writeSpecs(varargin)
%WRITESPECS Encode specified SI values and optionally store them on a block.
%   TEXT = writeSpecs(SPECS) returns stable JSON. writeSpecs(BLOCK,SPECS)
%   also writes the hidden Specifications parameter.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================

    if nargin==1,target='';specs=varargin{1};elseif nargin==2,target=varargin{1};specs=varargin{2}; ...
    else,error('nirp:dof:invalidCall','writeSpecs expects SPECS or BLOCK, SPECS.');end
    if isempty(specs),specs=struct();end
    % Validate through the same public reader while keeping empty as ''.
    if isempty(fieldnames(specs)),text='';else,text=jsonencode(specs);nirp.dof.readSpecs(text);end
    if ~isempty(target),set_param(char(string(target)),'Specifications',text);end
end
