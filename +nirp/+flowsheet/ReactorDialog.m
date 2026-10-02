classdef ReactorDialog < handle
%REACTORDIALOG Structured editor for CSTR and PFR Simulink blocks.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================
    properties (SetAccess=private)
        BlockPath; ReactorType; Figure; NameField; TypeField
        GeometryModeDropDown; VField; VUnitDropDown; LField; LUnitDropDown
        DField; DUnitDropDown; NTubesField; BypassField
        HeatModeGroup; UField; UUnitDropDown; AField; AUnitDropDown
        UtilityTinField; UtilityTinUnitDropDown; UtilityToutField
        UtilityToutUnitDropDown; SpecifiedTField; SpecifiedTUnitDropDown
        SpecifiedQField; SpecifiedQUnitDropDown
        PressureModeGroup; PressureEquationGroup; ParticleDiameterField
        ParticleDiameterUnitDropDown; DensityField; DensityUnitDropDown
        ViscosityField; ViscosityUnitDropDown; CatalyticCheckBox
        CatalystDensityField; CatalystPorosityField; InitialTField
        InitialTUnitDropDown; VSourceDropDown; HeatPortCheckBox
        ConnectionTable; StatusLabel; DataModel
    end
    properties (Access=private)
        HeatRows; PressureRows; CatalystRows; GeneralGrid; CatalystPanel
        HeatExchangeControls; SpecifiedTControls; SpecifiedQControls
        BypassLabel
    end
    methods
        function obj=ReactorDialog(blockPath,varargin)
            p=inputParser;addParameter(p,'Visible','on');parse(p,varargin{:});
            obj.BlockPath=getfullname(blockPath); cls=string(get_param(obj.BlockPath,'System'));
            if cls=="nirp.blocks.CSTR",obj.ReactorType="CSTR";
            elseif cls=="nirp.blocks.PFR",obj.ReactorType="PFR";
            else,error('nirp:flowsheet:invalidBlock','ReactorDialog requires a CSTR or PFR block.');end
            obj.build(char(string(p.Results.Visible)));obj.load();obj.refreshConnections();
        end
        function delete(obj),if ~isempty(obj.Figure)&&isvalid(obj.Figure),delete(obj.Figure);end,end
        function setHeatMode(obj,mode)
            mode=char(string(mode)); buttons=obj.HeatModeGroup.Children;
            index=find(strcmp({buttons.Text},mode),1);if isempty(index),error('nirp:flowsheet:invalidMode','Unknown heat mode.');end
            obj.HeatModeGroup.SelectedObject=buttons(index);obj.updateVisibility();obj.captureModel();
        end
        function setValues(obj,varargin)
            if numel(varargin)==1&&isstruct(varargin{1}),s=varargin{1};n=fieldnames(s);args=cell(1,2*numel(n));for i=1:numel(n),args(2*i-1:2*i)={n{i},s.(n{i})};end
            else,args=varargin;end
            for i=1:2:numel(args),obj.setOne(args{i},args{i+1});end;obj.updateVisibility();obj.captureModel();
        end
        function values=getValues(obj),obj.captureModel();values=obj.DataModel;end
        function connections=getConnections(obj),connections=obj.ConnectionTable.Data;end
        function apply(obj)
            if obj.VField.Value<=0||obj.BypassField.Value<0,error('nirp:flowsheet:invalidParameter','Volume must be positive and bypass nonnegative.');end
            names={'V','VUnit','VSource','BypassRatio','HeatMode','SpecifiedT','SpecifiedTUnit','SpecifiedQ','SpecifiedQUnit','U','UUnit','A','AUnit','UtilityTin','UtilityTinUnit','UtilityTout','UtilityToutUnit','InitialTGuess','InitialTGuessUnit','ShowHeatPort','CatalystDensity','CatalystPorosity'};
            values={n(obj.VField.Value),obj.VUnitDropDown.Value,obj.VSourceDropDown.Value,n(obj.BypassField.Value),obj.HeatModeGroup.SelectedObject.Text,n(obj.SpecifiedTField.Value),obj.SpecifiedTUnitDropDown.Value,n(obj.SpecifiedQField.Value),obj.SpecifiedQUnitDropDown.Value,n(obj.UField.Value),obj.UUnitDropDown.Value,n(obj.AField.Value),obj.AUnitDropDown.Value,n(obj.UtilityTinField.Value),obj.UtilityTinUnitDropDown.Value,n(optionalValue(obj.UtilityToutField)),obj.UtilityToutUnitDropDown.Value,n(optionalValue(obj.InitialTField)),obj.InitialTUnitDropDown.Value,onoff(obj.HeatPortCheckBox.Value),n(obj.CatalystDensityField.Value),n(obj.CatalystPorosityField.Value)};
            if obj.ReactorType=="PFR"
                names=[names {'GeometryMode','L','LUnit','D','DUnit','NTubes','PressureMode','PressureDropEqn','ParticleDiameter','ParticleDiameterUnit','Density','DensityUnit','Viscosity','ViscosityUnit'}];
                values=[values {obj.GeometryModeDropDown.Value,n(obj.LField.Value),obj.LUnitDropDown.Value,n(obj.DField.Value),obj.DUnitDropDown.Value,n(obj.NTubesField.Value),obj.PressureModeGroup.SelectedObject.Text,obj.PressureEquationGroup.SelectedObject.Text,n(obj.ParticleDiameterField.Value),obj.ParticleDiameterUnitDropDown.Value,n(obj.DensityField.Value),obj.DensityUnitDropDown.Value,n(obj.ViscosityField.Value),obj.ViscosityUnitDropDown.Value}];
            end
            args=reshape([names;values],1,[]);set_param(obj.BlockPath,args{:});
            newName=strtrim(obj.NameField.Value);if isempty(newName),error('nirp:flowsheet:invalidName','Name cannot be empty.');end
            if ~strcmp(newName,get_param(obj.BlockPath,'Name')),set_param(obj.BlockPath,'Name',newName);obj.BlockPath=getfullname([bdroot(obj.BlockPath) '/' newName]);end
            obj.StatusLabel.Text='Applied.';obj.captureModel();obj.refreshConnections();
        end
        function accept(obj),obj.apply();delete(obj);end
        function cancel(obj),delete(obj);end
    end
    methods (Static)
        function dialog=open(blockPath),dialog=nirp.flowsheet.ReactorDialog(blockPath);end
    end
    methods (Access=private)
        function build(obj,visible)
            if obj.ReactorType=="PFR",position=[80 40 900 650];else,position=[80 80 840 520];end
            obj.Figure=uifigure('Name','Reactor','Tag','NirpReactorDialog','Visible',visible,'Position',position);
            main=uigridlayout(obj.Figure,[4 1],'RowHeight',{42,'1x',26,38},'Padding',[12 10 12 10]);
            head=uigridlayout(main,[1 5],'ColumnWidth',{160,55,'1x',50,220});
            uibutton(head,'Text','Unit conversion helper','ButtonPushedFcn',@(~,~) UnitConverterHelper.launch());uilabel(head,'Text','Name','HorizontalAlignment','right');
            obj.NameField=uieditfield(head,'text');uilabel(head,'Text','Type','HorizontalAlignment','right');obj.TypeField=uieditfield(head,'text','Editable','off');
            tabs=uitabgroup(main); general=uitab(tabs,'Title','Reactor');connections=uitab(tabs,'Title','Connections');advanced=uitab(tabs,'Title','Advanced');
            grid=uigridlayout(general,[15 6],'ColumnWidth',{145,110,105,145,110,105}, ...
                'RowHeight',repmat({26},1,15),'RowSpacing',2,'Padding',[5 5 5 5]);obj.GeneralGrid=grid;
            [obj.VField,obj.VUnitDropDown]=qty(grid,1,1,'Volume','Volume');
            obj.GeometryModeDropDown=drop(grid,2,1,'Geometry',{'Volume','Length'});[obj.LField,obj.LUnitDropDown]=qty(grid,3,1,'L','Length');[obj.DField,obj.DUnitDropDown]=qty(grid,4,1,'D','Length');obj.NTubesField=numfield(grid,5,1,'Number of tubes');
            [obj.BypassField,obj.BypassLabel]=numfield(grid,6,1,'Bypass ratio');
            obj.HeatModeGroup=uibuttongroup(grid,'Title','Heat exchange mode','SelectionChangedFcn',@(~,~) obj.updateVisibility());obj.HeatModeGroup.Layout.Row=[1 3];obj.HeatModeGroup.Layout.Column=[4 6];
            modes={'Isothermal','Adiabatic','Heat exchange','Specified T','Specified Q'};for i=1:5,uiradiobutton(obj.HeatModeGroup,'Text',modes{i},'Position',[10+mod(i-1,2)*145 40-floor((i-1)/2)*19 135 18]);end
            [obj.UField,obj.UUnitDropDown,uLabel]=qty(grid,4,4,'U','HeatTransferCoefficient');[obj.AField,obj.AUnitDropDown,aLabel]=qty(grid,5,4,'A','Area');
            [obj.UtilityTinField,obj.UtilityTinUnitDropDown,tinLabel]=tempqty(grid,6,4,'Tw,in');[obj.UtilityToutField,obj.UtilityToutUnitDropDown,toutLabel]=texttempqty(grid,7,4,'Tw,out (optional)');
            [obj.SpecifiedTField,obj.SpecifiedTUnitDropDown,specifiedTLabel]=tempqty(grid,8,4,'Specified T');[obj.SpecifiedQField,obj.SpecifiedQUnitDropDown,specifiedQLabel]=qty(grid,9,4,'Specified Q','Power');
            obj.HeatExchangeControls={uLabel,obj.UField,obj.UUnitDropDown,aLabel,obj.AField,obj.AUnitDropDown,tinLabel,obj.UtilityTinField,obj.UtilityTinUnitDropDown,toutLabel,obj.UtilityToutField,obj.UtilityToutUnitDropDown};
            obj.SpecifiedTControls={specifiedTLabel,obj.SpecifiedTField,obj.SpecifiedTUnitDropDown};obj.SpecifiedQControls={specifiedQLabel,obj.SpecifiedQField,obj.SpecifiedQUnitDropDown};
            obj.HeatRows=[obj.HeatExchangeControls obj.SpecifiedTControls obj.SpecifiedQControls];
            obj.PressureModeGroup=radioGroup(grid,[8 9],[1 3],'Does pressure change inside the reactor?',{'Constant','Non constant'},@(~,~) obj.updateVisibility());
            obj.PressureEquationGroup=radioGroup(grid,[10 11],[1 3],'How to compute pressure drop?',{'Pipe','Ergun'},@(~,~) obj.updateVisibility());
            [obj.ParticleDiameterField,obj.ParticleDiameterUnitDropDown]=qty(grid,12,1,'Particle diameter','Length');[obj.DensityField,obj.DensityUnitDropDown]=qty(grid,13,1,'Density','Density');[obj.ViscosityField,obj.ViscosityUnitDropDown]=qty(grid,14,1,'Viscosity','Viscosity');
            obj.PressureRows={obj.PressureModeGroup,obj.PressureEquationGroup,obj.ParticleDiameterField,obj.ParticleDiameterUnitDropDown,obj.DensityField,obj.DensityUnitDropDown,obj.ViscosityField,obj.ViscosityUnitDropDown};
            obj.CatalystPanel=uipanel(grid,'Title','Catalyst');obj.CatalystPanel.Layout.Column=[4 6];obj.CatalystPanel.Layout.Row=[10 14];
            catalystGrid=uigridlayout(obj.CatalystPanel,[3 3],'ColumnWidth',{185,'1x',20},'RowHeight',{28,28,28},'Padding',[8 4 8 4]);
            obj.CatalyticCheckBox=uicheckbox(catalystGrid,'Text','Mark if the reactor is catalytic','ValueChangedFcn',@(~,~) obj.updateVisibility());obj.CatalyticCheckBox.Layout.Row=1;obj.CatalyticCheckBox.Layout.Column=[1 3];
            obj.CatalystDensityField=numfield(catalystGrid,2,1,'Catalyst density (kg/m^3)');obj.CatalystPorosityField=numfield(catalystGrid,3,1,'Catalyst porosity');obj.CatalystRows={obj.CatalystDensityField,obj.CatalystPorosityField};
            cgrid=uigridlayout(connections,[2 1],'RowHeight',{30,'1x'});uilabel(cgrid,'Text','Connected material streams (read only)','FontWeight','bold');obj.ConnectionTable=uitable(cgrid,'ColumnName',{'Direction','Port','Stream'},'ColumnEditable',false);
            agrid=uigridlayout(advanced,[4 3],'ColumnWidth',{220,150,120});obj.VSourceDropDown=drop(agrid,1,1,'Volume source',{'Dialog','Input port'});[obj.InitialTField,obj.InitialTUnitDropDown]=texttempqty(agrid,2,1,'Initial T estimate');obj.HeatPortCheckBox=uicheckbox(agrid,'Text','Show heat port');obj.HeatPortCheckBox.Layout.Row=3;obj.HeatPortCheckBox.Layout.Column=[1 2];
            obj.StatusLabel=uilabel(main,'Text','Ready.','FontAngle','italic');buttons=uigridlayout(main,[1 4],'ColumnWidth',{'1x',90,90,90});uilabel(buttons,'Text','');uibutton(buttons,'Text','OK','ButtonPushedFcn',@(~,~) obj.accept());uibutton(buttons,'Text','Apply','ButtonPushedFcn',@(~,~) obj.apply());uibutton(buttons,'Text','Cancel','ButtonPushedFcn',@(~,~) obj.cancel());
        end
        function load(obj)
            obj.NameField.Value=get_param(obj.BlockPath,'Name');obj.TypeField.Value=char(obj.ReactorType);
            pairs={'V',obj.VField;'BypassRatio',obj.BypassField;'SpecifiedT',obj.SpecifiedTField;'SpecifiedQ',obj.SpecifiedQField;'U',obj.UField;'A',obj.AField;'UtilityTin',obj.UtilityTinField;'CatalystDensity',obj.CatalystDensityField;'CatalystPorosity',obj.CatalystPorosityField};for i=1:size(pairs,1),pairs{i,2}.Value=str2double(get_param(obj.BlockPath,pairs{i,1}));end
            obj.UtilityToutField.Value=get_param(obj.BlockPath,'UtilityTout');obj.InitialTField.Value=get_param(obj.BlockPath,'InitialTGuess');
            units={'VUnit',obj.VUnitDropDown;'SpecifiedTUnit',obj.SpecifiedTUnitDropDown;'SpecifiedQUnit',obj.SpecifiedQUnitDropDown;'UUnit',obj.UUnitDropDown;'AUnit',obj.AUnitDropDown;'UtilityTinUnit',obj.UtilityTinUnitDropDown;'UtilityToutUnit',obj.UtilityToutUnitDropDown;'InitialTGuessUnit',obj.InitialTUnitDropDown;'VSource',obj.VSourceDropDown};for i=1:size(units,1),units{i,2}.Value=get_param(obj.BlockPath,units{i,1});end
            obj.setHeatMode(get_param(obj.BlockPath,'HeatMode'));obj.HeatPortCheckBox.Value=ison(get_param(obj.BlockPath,'ShowHeatPort'));obj.CatalyticCheckBox.Value=obj.CatalystDensityField.Value~=1||obj.CatalystPorosityField.Value~=0;
            if obj.ReactorType=="PFR",p={'L',obj.LField;'D',obj.DField;'NTubes',obj.NTubesField;'ParticleDiameter',obj.ParticleDiameterField;'Density',obj.DensityField;'Viscosity',obj.ViscosityField};for i=1:size(p,1),p{i,2}.Value=str2double(get_param(obj.BlockPath,p{i,1}));end;u={'GeometryMode',obj.GeometryModeDropDown;'LUnit',obj.LUnitDropDown;'DUnit',obj.DUnitDropDown;'ParticleDiameterUnit',obj.ParticleDiameterUnitDropDown;'DensityUnit',obj.DensityUnitDropDown;'ViscosityUnit',obj.ViscosityUnitDropDown};for i=1:size(u,1),u{i,2}.Value=get_param(obj.BlockPath,u{i,1});end;selectRadio(obj.PressureModeGroup,get_param(obj.BlockPath,'PressureMode'));selectRadio(obj.PressureEquationGroup,get_param(obj.BlockPath,'PressureDropEqn'));end
            obj.updateVisibility();obj.captureModel();
        end
        function updateVisibility(obj)
            mode=string(obj.HeatModeGroup.SelectedObject.Text);setVisible(obj.HeatRows,false);
            if mode=="Heat exchange",setVisible(obj.HeatExchangeControls,true);elseif mode=="Specified T",moveControls(obj.SpecifiedTControls,4);setVisible(obj.SpecifiedTControls,true);elseif mode=="Specified Q",moveControls(obj.SpecifiedQControls,4);setVisible(obj.SpecifiedQControls,true);end
            isPfr=obj.ReactorType=="PFR";for row=2:5,rowvis(obj.GeneralGrid,row,1:3,isPfr);end;for row=8:14,rowvis(obj.GeneralGrid,row,1:3,isPfr);end
            if isPfr,nonconstant=strcmp(obj.PressureModeGroup.SelectedObject.Text,'Non constant');for row=10:14,rowvis(obj.GeneralGrid,row,1:3,nonconstant);end;ergun=nonconstant&&strcmp(obj.PressureEquationGroup.SelectedObject.Text,'Ergun');rowvis(obj.GeneralGrid,12,1:3,ergun);end
            obj.BypassLabel.Visible='on';obj.BypassField.Visible='on';
            if isPfr
                obj.GeneralGrid.RowHeight=repmat({26},1,15);obj.CatalystPanel.Layout.Row=[10 14];
            else
                obj.BypassLabel.Layout.Row=2;obj.BypassField.Layout.Row=2;
                heights=repmat({0},1,15);lastRow=9;if mode=="Heat exchange",lastRow=12;obj.CatalystPanel.Layout.Row=[8 12];else,obj.CatalystPanel.Layout.Row=[5 9];end
                heights(1:lastRow)=repmat({26},1,lastRow);obj.GeneralGrid.RowHeight=heights;
            end
            for i=1:numel(obj.CatalystRows),obj.CatalystRows{i}.Enable=onoff(obj.CatalyticCheckBox.Value);end
        end
        function refreshConnections(obj)
            graph=nirp.flowsheet.topology(bdroot(obj.BlockPath));key=matlab.lang.makeValidName(get_param(obj.BlockPath,'Name'));data=cell(0,3);if isfield(graph.Units,key),item=graph.Units.(key);for i=1:numel(item.Inputs),data(end+1,:)={'Input',i,joinNames(item.Inputs{i})};end;for i=1:numel(item.Outputs),data(end+1,:)={'Output',i,joinNames(item.Outputs{i})};end;end;obj.ConnectionTable.Data=data;
        end
        function captureModel(obj)
            q=@(v,u) struct('value',v,'unit',string(u),'origin',"specified");obj.DataModel=struct('V',q(obj.VField.Value,obj.VUnitDropDown.Value),'BypassRatio',q(obj.BypassField.Value,'1'),'U',q(obj.UField.Value,obj.UUnitDropDown.Value),'A',q(obj.AField.Value,obj.AUnitDropDown.Value),'UtilityTin',q(obj.UtilityTinField.Value,obj.UtilityTinUnitDropDown.Value),'UtilityTout',q(optionalValue(obj.UtilityToutField),obj.UtilityToutUnitDropDown.Value),'SpecifiedT',q(obj.SpecifiedTField.Value,obj.SpecifiedTUnitDropDown.Value),'SpecifiedQ',q(obj.SpecifiedQField.Value,obj.SpecifiedQUnitDropDown.Value),'CatalystDensity',q(obj.CatalystDensityField.Value,'kg/m^3'),'CatalystPorosity',q(obj.CatalystPorosityField.Value,'1'),'InitialTGuess',q(optionalValue(obj.InitialTField),obj.InitialTUnitDropDown.Value));if obj.ReactorType=="PFR",obj.DataModel.L=q(obj.LField.Value,obj.LUnitDropDown.Value);obj.DataModel.D=q(obj.DField.Value,obj.DUnitDropDown.Value);obj.DataModel.NTubes=q(obj.NTubesField.Value,'1');obj.DataModel.ParticleDiameter=q(obj.ParticleDiameterField.Value,obj.ParticleDiameterUnitDropDown.Value);obj.DataModel.Density=q(obj.DensityField.Value,obj.DensityUnitDropDown.Value);obj.DataModel.Viscosity=q(obj.ViscosityField.Value,obj.ViscosityUnitDropDown.Value);end
        end
        function setOne(obj,name,value)
            key=lower(char(string(name)));map=struct('v','VField','l','LField','d','DField','ntubes','NTubesField','bypassratio','BypassField','u','UField','a','AField','utilitytin','UtilityTinField','utilitytout','UtilityToutField','specifiedt','SpecifiedTField','specifiedq','SpecifiedQField','particlediameter','ParticleDiameterField','density','DensityField','viscosity','ViscosityField','catalystdensity','CatalystDensityField','catalystporosity','CatalystPorosityField','initialtguess','InitialTField');if strcmp(key,'heatmode'),obj.setHeatMode(value);elseif isfield(map,key),field=obj.(map.(key));if isa(field,'matlab.ui.control.EditField'),field.Value=char(string(value));else,field.Value=value;end;else,error('nirp:flowsheet:unknownParameter','Unknown reactor parameter "%s".',name);end
        end
    end
end
function [field,units,text]=qty(grid,row,col,label,category),text=uilabel(grid,'Text',label,'HorizontalAlignment','right');text.Layout.Row=row;text.Layout.Column=col;field=uieditfield(grid,'numeric');field.Layout.Row=row;field.Layout.Column=col+1;units=uidropdown(grid,'Items',UnitConverterHelper.getUnits(category));units.Layout.Row=row;units.Layout.Column=col+2;end
function [field,units,text]=tempqty(grid,row,col,label),[field,units,text]=qty(grid,row,col,label,'Temperature');end
function [field,units,text]=texttempqty(grid,row,col,label),text=uilabel(grid,'Text',label,'HorizontalAlignment','right');text.Layout.Row=row;text.Layout.Column=col;field=uieditfield(grid,'text');field.Layout.Row=row;field.Layout.Column=col+1;units=uidropdown(grid,'Items',UnitConverterHelper.getUnits('Temperature'));units.Layout.Row=row;units.Layout.Column=col+2;end
function [field,text]=numfield(grid,row,col,label),text=uilabel(grid,'Text',label,'HorizontalAlignment','right');text.Layout.Row=row;text.Layout.Column=col;field=uieditfield(grid,'numeric');field.Layout.Row=row;field.Layout.Column=col+1;end
function field=drop(grid,row,col,label,items),text=uilabel(grid,'Text',label,'HorizontalAlignment','right');text.Layout.Row=row;text.Layout.Column=col;field=uidropdown(grid,'Items',items);field.Layout.Row=row;field.Layout.Column=[col+1 col+2];end
function group=radioGroup(grid,rows,cols,title,items,callback),group=uibuttongroup(grid,'Title',title,'SelectionChangedFcn',callback);group.Layout.Row=rows;group.Layout.Column=cols;for i=1:numel(items),uiradiobutton(group,'Text',items{i},'Position',[10+(i-1)*140 8 130 22]);end;end
function selectRadio(group,value),b=group.Children;i=find(strcmp({b.Text},value),1);if ~isempty(i),group.SelectedObject=b(i);end,end
function show(items),for i=1:numel(items),items{i}.Visible='on';end,end
function rowvis(grid,row,columns,flag),children=grid.Children;for i=1:numel(children),if any(children(i).Layout.Row==row)&&any(ismember(children(i).Layout.Column,columns)),children(i).Visible=onoff(flag);end,end,end
function setVisible(items,flag),for i=1:numel(items),items{i}.Visible=onoff(flag);end,end
function moveControls(items,row),for i=1:numel(items),items{i}.Layout.Row=row;end,end
function value=onoff(flag),if flag,value='on';else,value='off';end,end
function flag=ison(value),flag=strcmp(value,'on')||strcmp(value,'1');end
function value=n(x),value=num2str(x,17);end
function value=optionalValue(field),value=str2double(field.Value);if ~(isfinite(value)||isnan(value)),error('nirp:flowsheet:invalidParameter','Optional temperature must be numeric or NaN.');end,end
function value=joinNames(names),if isempty(names),value='<missing>';else,value=char(strjoin(string(names),', '));end,end
