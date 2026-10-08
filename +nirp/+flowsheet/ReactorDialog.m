classdef ReactorDialog < handle
%REACTORDIALOG Structured editor for CSTR and PFR Simulink blocks.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 7, 2026
% =========================================================================
    properties (SetAccess=private)
        BlockPath; ReactorType; Figure; NameField; TypeField
        GeometryModeDropDown; VField; VUnitDropDown; LField; LUnitDropDown
        DField; DUnitDropDown; NTubesField
        HeatModeGroup; UField; UUnitDropDown; AField; AUnitDropDown
        UtilityTinField; UtilityTinUnitDropDown; UtilityToutField
        UtilityToutUnitDropDown
        PressureModeGroup; PressureEquationGroup; ParticleDiameterField
        ParticleDiameterUnitDropDown; DensityField; DensityUnitDropDown
        ViscosityField; ViscosityUnitDropDown; CatalyticCheckBox
        CatalystDensityField; CatalystPorosityField; InitialTField
        InitialTUnitDropDown; VSourceDropDown; ASourceDropDown
        UtilityTinSourceDropDown; HeatPortCheckBox
        VPortLabel; APortLabel; UtilityTinPortLabel
        ConnectionTable; StatusLabel; DataModel
    end
    properties (Access=private)
        HeatRows; PressureRows; CatalystRows; GeneralGrid; CatalystPanel
        HeatExchangeControls
        GeometryOrigins = repmat("specified",1,4)
        UpdatingGeometry = false
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
            if obj.ReactorType=="PFR",obj.geometryModeChanged();end
            for i=1:2:numel(args),obj.setOne(args{i},args{i+1});end;obj.updateVisibility();obj.closeGeometry();obj.captureModel();
        end
        function values=getValues(obj),obj.captureModel();values=obj.DataModel;end
        function connections=getConnections(obj),connections=obj.ConnectionTable.Data;end
        function applied=apply(obj)
            applied=false;try
            if obj.ReactorType=="PFR"&&~obj.closeGeometry(true),return,end
            if obj.VField.Value<=0,error('nirp:flowsheet:invalidParameter','Volume must be positive.');end
            % T-131 (D-057): no bypass and no specified T/Q in flowsheet reactors.
            names={'V','VUnit','VSource','HeatMode','U','UUnit','ASource','A','AUnit','UtilityTinSource','UtilityTin','UtilityTinUnit','UtilityTout','UtilityToutUnit','InitialTGuess','InitialTGuessUnit','ShowHeatPort','CatalystDensity','CatalystPorosity'};
            values={n(obj.VField.Value),obj.VUnitDropDown.Value,obj.VSourceDropDown.Value,obj.HeatModeGroup.SelectedObject.Text,n(obj.UField.Value),obj.UUnitDropDown.Value,obj.ASourceDropDown.Value,n(obj.AField.Value),obj.AUnitDropDown.Value,obj.UtilityTinSourceDropDown.Value,n(obj.UtilityTinField.Value),obj.UtilityTinUnitDropDown.Value,n(optionalValue(obj.UtilityToutField)),obj.UtilityToutUnitDropDown.Value,n(optionalValue(obj.InitialTField)),obj.InitialTUnitDropDown.Value,onoff(obj.HeatPortCheckBox.Value),n(obj.CatalystDensityField.Value),n(obj.CatalystPorosityField.Value)};
            if obj.ReactorType=="PFR"
                names=[names {'GeometryMode','L','LUnit','D','DUnit','NTubes','PressureMode','PressureDropEqn','ParticleDiameter','ParticleDiameterUnit','Density','DensityUnit','Viscosity','ViscosityUnit'}];
                raw=[obj.VField.Value obj.LField.Value obj.DField.Value obj.NTubesField.Value];raw(obj.GeometryOrigins=="calculated")=NaN;values{1}=n(raw(1));values=[values {'Length',n(raw(2)),obj.LUnitDropDown.Value,n(raw(3)),obj.DUnitDropDown.Value,n(raw(4)),obj.PressureModeGroup.SelectedObject.Text,obj.PressureEquationGroup.SelectedObject.Text,n(obj.ParticleDiameterField.Value),obj.ParticleDiameterUnitDropDown.Value,n(obj.DensityField.Value),obj.DensityUnitDropDown.Value,n(obj.ViscosityField.Value),obj.ViscosityUnitDropDown.Value}];
            end
            args=reshape([names;values],1,[]);set_param(obj.BlockPath,args{:});
            newName=strtrim(obj.NameField.Value);if isempty(newName),error('nirp:flowsheet:invalidName','Name cannot be empty.');end
            if ~strcmp(newName,get_param(obj.BlockPath,'Name')),set_param(obj.BlockPath,'Name',newName);obj.BlockPath=getfullname([bdroot(obj.BlockPath) '/' newName]);end
            obj.StatusLabel.Text='Applied.';obj.captureModel();obj.refreshConnections();applied=true;catch exception,obj.StatusLabel.Text=exception.message;end
        end
        function accept(obj),if obj.apply(),delete(obj);end,end
        function cancel(obj),delete(obj);end
    end
    methods (Static)
        function dialog=open(blockPath),dialog=nirp.flowsheet.ReactorDialog(blockPath);end
    end
    methods (Access=private)
        function build(obj,visible)
            if obj.ReactorType=="PFR",position=[80 40 900 650];else,position=[80 80 840 520];end
            obj.Figure=uifigure('Name','Reactor','Tag','NirpReactorDialog','Visible',visible,'Position',position,'WindowStyle','alwaysontop');
            main=uigridlayout(obj.Figure,[4 1],'RowHeight',{42,'1x',26,38},'Padding',[12 10 12 10]);
            head=uigridlayout(main,[1 5],'ColumnWidth',{160,55,'1x',50,220});
            uibutton(head,'Text','Unit conversion helper','ButtonPushedFcn',@(~,~) UnitConverterHelper.launch());uilabel(head,'Text','Name','HorizontalAlignment','right');
            obj.NameField=uieditfield(head,'text');uilabel(head,'Text','Type','HorizontalAlignment','right');obj.TypeField=uieditfield(head,'text','Editable','off');
            tabs=uitabgroup(main); general=uitab(tabs,'Title','Reactor');connections=uitab(tabs,'Title','Connections');advanced=uitab(tabs,'Title','Advanced');
            grid=uigridlayout(general,[15 6],'ColumnWidth',{145,110,105,145,110,105}, ...
                'RowHeight',repmat({26},1,15),'RowSpacing',2,'Padding',[5 5 5 5]);obj.GeneralGrid=grid;
            [obj.VField,obj.VUnitDropDown]=qty(grid,1,1,'Volume','Volume');obj.VPortLabel=portLabel(grid,1,2);
            obj.GeometryModeDropDown=drop(grid,2,1,'Geometry',{'Volume','Length'});obj.GeometryModeDropDown.ValueChangedFcn=@(~,~) obj.geometryModeChanged();[obj.LField,obj.LUnitDropDown]=qty(grid,3,1,'L','Length');[obj.DField,obj.DUnitDropDown]=qty(grid,4,1,'D','Length');obj.NTubesField=numfield(grid,5,1,'Number of tubes');
            geometryTip=uilabel(grid,'Text','One missing PFR geometry value is calculated automatically.','FontAngle','italic','Visible',onoff(obj.ReactorType=="PFR"));geometryTip.Layout.Row=15;geometryTip.Layout.Column=[1 3];
            obj.VField.ValueChangedFcn=@(~,~) obj.geometryEdited(1);obj.LField.ValueChangedFcn=@(~,~) obj.geometryEdited(2);obj.DField.ValueChangedFcn=@(~,~) obj.geometryEdited(3);obj.NTubesField.ValueChangedFcn=@(~,~) obj.geometryEdited(4);
            obj.VUnitDropDown.ValueChangedFcn=@(~,~) obj.closeGeometry();obj.LUnitDropDown.ValueChangedFcn=@(~,~) obj.closeGeometry();obj.DUnitDropDown.ValueChangedFcn=@(~,~) obj.closeGeometry();
            obj.HeatModeGroup=uibuttongroup(grid,'Title','Heat exchange mode','SelectionChangedFcn',@(~,~) obj.updateVisibility());obj.HeatModeGroup.Layout.Row=[1 3];obj.HeatModeGroup.Layout.Column=[4 6];
            modes={'Isothermal','Adiabatic','Heat exchange'};for i=1:numel(modes),uiradiobutton(obj.HeatModeGroup,'Text',modes{i},'Position',[10+mod(i-1,2)*145 40-floor((i-1)/2)*19 135 18]);end
            [obj.UField,obj.UUnitDropDown,uLabel]=qty(grid,4,4,'U','HeatTransferCoefficient');[obj.AField,obj.AUnitDropDown,aLabel]=qty(grid,5,4,'A','Area');obj.APortLabel=portLabel(grid,5,5);
            [obj.UtilityTinField,obj.UtilityTinUnitDropDown,tinLabel]=tempqty(grid,6,4,'Tw,in');obj.UtilityTinPortLabel=portLabel(grid,6,5);[obj.UtilityToutField,obj.UtilityToutUnitDropDown,toutLabel]=texttempqty(grid,7,4,'Tw,out (optional)');
            obj.HeatExchangeControls={uLabel,obj.UField,obj.UUnitDropDown,aLabel,obj.AField,obj.AUnitDropDown,tinLabel,obj.UtilityTinField,obj.UtilityTinUnitDropDown,toutLabel,obj.UtilityToutField,obj.UtilityToutUnitDropDown};
            obj.HeatRows=obj.HeatExchangeControls;
            obj.PressureModeGroup=radioGroup(grid,[8 9],[1 3],'Does pressure change inside the reactor?',{'Constant','Non constant'},@(~,~) obj.updateVisibility());
            obj.PressureEquationGroup=radioGroup(grid,[10 11],[1 3],'How to compute pressure drop?',{'Pipe','Ergun'},@(~,~) obj.updateVisibility());
            [obj.ParticleDiameterField,obj.ParticleDiameterUnitDropDown]=qty(grid,12,1,'Particle diameter','Length');[obj.DensityField,obj.DensityUnitDropDown]=qty(grid,13,1,'Density','Density');[obj.ViscosityField,obj.ViscosityUnitDropDown]=qty(grid,14,1,'Viscosity','Viscosity');
            obj.PressureRows={obj.PressureModeGroup,obj.PressureEquationGroup,obj.ParticleDiameterField,obj.ParticleDiameterUnitDropDown,obj.DensityField,obj.DensityUnitDropDown,obj.ViscosityField,obj.ViscosityUnitDropDown};
            obj.CatalystPanel=uipanel(grid,'Title','Catalyst');obj.CatalystPanel.Layout.Column=[4 6];obj.CatalystPanel.Layout.Row=[10 14];
            catalystGrid=uigridlayout(obj.CatalystPanel,[3 3],'ColumnWidth',{185,'1x',20},'RowHeight',{28,28,28},'Padding',[8 4 8 4]);
            obj.CatalyticCheckBox=uicheckbox(catalystGrid,'Text','Mark if the reactor is catalytic','ValueChangedFcn',@(~,~) obj.updateVisibility());obj.CatalyticCheckBox.Layout.Row=1;obj.CatalyticCheckBox.Layout.Column=[1 3];
            obj.CatalystDensityField=numfield(catalystGrid,2,1,'Catalyst density (kg/m^3)');obj.CatalystPorosityField=numfield(catalystGrid,3,1,'Catalyst porosity');obj.CatalystRows={obj.CatalystDensityField,obj.CatalystPorosityField};
            cgrid=uigridlayout(connections,[2 1],'RowHeight',{30,'1x'});uilabel(cgrid,'Text','Connected material streams (read only)','FontWeight','bold');obj.ConnectionTable=uitable(cgrid,'ColumnName',{'Direction','Port','Stream'},'ColumnEditable',false);
            agrid=uigridlayout(advanced,[5 3],'ColumnWidth',{220,150,120});obj.VSourceDropDown=drop(agrid,1,1,'Volume source',{'Dialog','Input port'});obj.ASourceDropDown=drop(agrid,2,1,'Heat-transfer area source',{'Dialog','Input port'});obj.UtilityTinSourceDropDown=drop(agrid,3,1,'Utility inlet T source',{'Dialog','Input port'});obj.VSourceDropDown.ValueChangedFcn=@(~,~) obj.updatePortSources();obj.ASourceDropDown.ValueChangedFcn=@(~,~) obj.updatePortSources();obj.UtilityTinSourceDropDown.ValueChangedFcn=@(~,~) obj.updatePortSources();[obj.InitialTField,obj.InitialTUnitDropDown]=texttempqty(agrid,4,1,'Initial T estimate');obj.HeatPortCheckBox=uicheckbox(agrid,'Text','Show heat port');obj.HeatPortCheckBox.Layout.Row=5;obj.HeatPortCheckBox.Layout.Column=[1 2];
            obj.StatusLabel=uilabel(main,'Text','Ready.','FontAngle','italic');buttons=uigridlayout(main,[1 4],'ColumnWidth',{'1x',90,90,90});uilabel(buttons,'Text','');uibutton(buttons,'Text','OK','ButtonPushedFcn',@(~,~) obj.accept());uibutton(buttons,'Text','Cancel','ButtonPushedFcn',@(~,~) obj.cancel());uibutton(buttons,'Text','Apply','ButtonPushedFcn',@(~,~) obj.apply());
        end
        function load(obj)
            obj.NameField.Value=get_param(obj.BlockPath,'Name');obj.TypeField.Value=char(obj.ReactorType);
            pairs={'V',obj.VField;'U',obj.UField;'A',obj.AField;'UtilityTin',obj.UtilityTinField;'CatalystDensity',obj.CatalystDensityField;'CatalystPorosity',obj.CatalystPorosityField};for i=1:size(pairs,1),value=str2double(get_param(obj.BlockPath,pairs{i,1}));if ~isnan(value),pairs{i,2}.Value=value;end,end
            obj.UtilityToutField.Value=get_param(obj.BlockPath,'UtilityTout');obj.InitialTField.Value=get_param(obj.BlockPath,'InitialTGuess');
            units={'VUnit',obj.VUnitDropDown;'UUnit',obj.UUnitDropDown;'AUnit',obj.AUnitDropDown;'UtilityTinUnit',obj.UtilityTinUnitDropDown;'UtilityToutUnit',obj.UtilityToutUnitDropDown;'InitialTGuessUnit',obj.InitialTUnitDropDown;'VSource',obj.VSourceDropDown;'ASource',obj.ASourceDropDown;'UtilityTinSource',obj.UtilityTinSourceDropDown};for i=1:size(units,1),units{i,2}.Value=get_param(obj.BlockPath,units{i,1});end
            obj.setHeatMode(get_param(obj.BlockPath,'HeatMode'));obj.HeatPortCheckBox.Value=ison(get_param(obj.BlockPath,'ShowHeatPort'));obj.CatalyticCheckBox.Value=obj.CatalystDensityField.Value~=1||obj.CatalystPorosityField.Value~=0;
            if obj.ReactorType=="PFR",p={'L',obj.LField;'D',obj.DField;'NTubes',obj.NTubesField;'ParticleDiameter',obj.ParticleDiameterField;'Density',obj.DensityField;'Viscosity',obj.ViscosityField};for i=1:size(p,1),value=str2double(get_param(obj.BlockPath,p{i,1}));if ~isnan(value),p{i,2}.Value=value;end,end;u={'GeometryMode',obj.GeometryModeDropDown;'LUnit',obj.LUnitDropDown;'DUnit',obj.DUnitDropDown;'ParticleDiameterUnit',obj.ParticleDiameterUnitDropDown;'DensityUnit',obj.DensityUnitDropDown;'ViscosityUnit',obj.ViscosityUnitDropDown};for i=1:size(u,1),u{i,2}.Value=get_param(obj.BlockPath,u{i,1});end;selectRadio(obj.PressureModeGroup,get_param(obj.BlockPath,'PressureMode'));selectRadio(obj.PressureEquationGroup,get_param(obj.BlockPath,'PressureDropEqn'));raw=[str2double(get_param(obj.BlockPath,'V')) str2double(get_param(obj.BlockPath,'L')) str2double(get_param(obj.BlockPath,'D')) str2double(get_param(obj.BlockPath,'NTubes'))];obj.GeometryOrigins(:)="specified";obj.GeometryOrigins(isnan(raw))="calculated";if all(isfinite(raw)),obj.geometryModeChanged();else,obj.closeGeometry();end;end
            obj.updateVisibility();obj.captureModel();
        end
        function updateVisibility(obj)
            mode=string(obj.HeatModeGroup.SelectedObject.Text);setVisible(obj.HeatRows,false);
            if mode=="Heat exchange",setVisible(obj.HeatExchangeControls,true);end
            isPfr=obj.ReactorType=="PFR";for row=2:5,rowvis(obj.GeneralGrid,row,1:3,isPfr);end;for row=8:14,rowvis(obj.GeneralGrid,row,1:3,isPfr);end
            if isPfr,nonconstant=strcmp(obj.PressureModeGroup.SelectedObject.Text,'Non constant');for row=10:14,rowvis(obj.GeneralGrid,row,1:3,nonconstant);end;ergun=nonconstant&&strcmp(obj.PressureEquationGroup.SelectedObject.Text,'Ergun');rowvis(obj.GeneralGrid,12,1:3,ergun);end
            if isPfr
                obj.GeneralGrid.RowHeight=repmat({26},1,15);obj.CatalystPanel.Layout.Row=[10 14];
            else
                heights=repmat({0},1,15);lastRow=9;if mode=="Heat exchange",lastRow=12;obj.CatalystPanel.Layout.Row=[8 12];else,obj.CatalystPanel.Layout.Row=[5 9];end
                heights(1:lastRow)=repmat({26},1,lastRow);obj.GeneralGrid.RowHeight=heights;
            end
            for i=1:numel(obj.CatalystRows),obj.CatalystRows{i}.Enable=onoff(obj.CatalyticCheckBox.Value);end
            obj.updatePortSources();
        end
        function updatePortSources(obj)
            inputV=strcmp(obj.VSourceDropDown.Value,'Input port');obj.VField.Visible=onoff(~inputV);obj.VField.Editable=onoff(~inputV);obj.VPortLabel.Visible=onoff(inputV);
            heatExchange=strcmp(obj.HeatModeGroup.SelectedObject.Text,'Heat exchange');
            inputA=strcmp(obj.ASourceDropDown.Value,'Input port');obj.AField.Visible=onoff(heatExchange&&~inputA);obj.AField.Editable=onoff(~inputA);obj.APortLabel.Visible=onoff(heatExchange&&inputA);
            inputTin=strcmp(obj.UtilityTinSourceDropDown.Value,'Input port');obj.UtilityTinField.Visible=onoff(heatExchange&&~inputTin);obj.UtilityTinField.Editable=onoff(~inputTin);obj.UtilityTinPortLabel.Visible=onoff(heatExchange&&inputTin);
        end
        function refreshConnections(obj)
            graph=nirp.flowsheet.topology(bdroot(obj.BlockPath));key=matlab.lang.makeValidName(get_param(obj.BlockPath,'Name'));data=cell(0,3);if isfield(graph.Units,key),item=graph.Units.(key);ports=get_param(obj.BlockPath,'PortHandles');for i=1:numel(item.Inputs),label=joinNames(item.Inputs{i});if isempty(item.Inputs{i})&&i<=numel(ports.Inport),label=signalLabel(ports.Inport(i));end;data(end+1,:)={'Input',i,label};end;for i=1:numel(item.Outputs),data(end+1,:)={'Output',i,joinNames(item.Outputs{i})};end;end;obj.ConnectionTable.Data=data;
        end
        function captureModel(obj)
            q=@(v,u) struct('value',v,'unit',string(u),'origin',"specified");obj.DataModel=struct('V',q(obj.VField.Value,obj.VUnitDropDown.Value),'U',q(obj.UField.Value,obj.UUnitDropDown.Value),'A',q(obj.AField.Value,obj.AUnitDropDown.Value),'UtilityTin',q(obj.UtilityTinField.Value,obj.UtilityTinUnitDropDown.Value),'UtilityTout',q(optionalValue(obj.UtilityToutField),obj.UtilityToutUnitDropDown.Value),'CatalystDensity',q(obj.CatalystDensityField.Value,'kg/m^3'),'CatalystPorosity',q(obj.CatalystPorosityField.Value,'1'),'InitialTGuess',q(optionalValue(obj.InitialTField),obj.InitialTUnitDropDown.Value));if obj.ReactorType=="PFR",obj.DataModel.L=q(obj.LField.Value,obj.LUnitDropDown.Value);obj.DataModel.D=q(obj.DField.Value,obj.DUnitDropDown.Value);obj.DataModel.NTubes=q(obj.NTubesField.Value,'1');obj.DataModel.ParticleDiameter=q(obj.ParticleDiameterField.Value,obj.ParticleDiameterUnitDropDown.Value);obj.DataModel.Density=q(obj.DensityField.Value,obj.DensityUnitDropDown.Value);obj.DataModel.Viscosity=q(obj.ViscosityField.Value,obj.ViscosityUnitDropDown.Value);end
            if obj.ReactorType=="PFR",names={'V','L','D','NTubes'};for i=1:4,obj.DataModel.(names{i}).origin=obj.GeometryOrigins(i);end,end
        end
        function valid=closeGeometry(obj,highlight)
            if nargin<2,highlight=false;end;valid=true;if obj.ReactorType~="PFR"||obj.UpdatingGeometry,return,end
            obj.UpdatingGeometry=true;cleanup=onCleanup(@() obj.finishGeometryUpdate());fields={obj.VField,obj.LField,obj.DField,obj.NTubesField};
            for i=1:4,fields{i}.BackgroundColor=[1 1 1];end
            raw=[obj.VField.Value obj.LField.Value obj.DField.Value obj.NTubesField.Value];raw(obj.GeometryOrigins=="calculated")=NaN;
            si=raw;si(1)=UnitConverterHelper.convertToSI('Volume',raw(1),obj.VUnitDropDown.Value);si(2)=UnitConverterHelper.convertToSI('Length',raw(2),obj.LUnitDropDown.Value);si(3)=UnitConverterHelper.convertToSI('Length',raw(3),obj.DUnitDropDown.Value);
            [si,origin,message]=nirp.flowsheet.closeProduct(si,pi/4,[1 -1 -2 -1]);
            if strlength(message)==0&&all(isfinite(si))&&(abs(si(4)-round(si(4)))>1e-9||si(4)<1),message="Number of tubes must be a positive integer.";end
            display=si;display(1)=UnitConverterHelper.convertFromSI('Volume',si(1),obj.VUnitDropDown.Value);display(2)=UnitConverterHelper.convertFromSI('Length',si(2),obj.LUnitDropDown.Value);display(3)=UnitConverterHelper.convertFromSI('Length',si(3),obj.DUnitDropDown.Value);
            for i=1:4,if isfinite(display(i)),fields{i}.Value=display(i);end,end;obj.GeometryOrigins=origin;
            calculated=find(origin=="calculated");for i=calculated,fields{i}.BackgroundColor=[0.92 0.92 0.92];end
            valid=strlength(message)==0&&all(isfinite(si));if strlength(message)>0,obj.StatusLabel.Text=char(message);elseif ~valid&&highlight,obj.StatusLabel.Text='';missing=find(~isfinite(si));for i=missing,fields{i}.BackgroundColor=[1 0.86 0.86];end;end
            obj.captureModel();
        end
        function geometryEdited(obj,index),if obj.UpdatingGeometry,return,end;obj.GeometryOrigins(index)="specified";obj.closeGeometry();end
        function geometryModeChanged(obj),if obj.ReactorType~="PFR"||obj.UpdatingGeometry,return,end;if strcmp(obj.GeometryModeDropDown.Value,'Length'),obj.GeometryOrigins(1)="calculated";obj.GeometryOrigins(2)="specified";else,obj.GeometryOrigins(1)="specified";obj.GeometryOrigins(2)="calculated";end;obj.closeGeometry();end
        function finishGeometryUpdate(obj),obj.UpdatingGeometry=false;end
        function setOne(obj,name,value)
            key=lower(char(string(name)));map=struct('v','VField','l','LField','d','DField','ntubes','NTubesField','u','UField','a','AField','utilitytin','UtilityTinField','utilitytout','UtilityToutField','particlediameter','ParticleDiameterField','density','DensityField','viscosity','ViscosityField','catalystdensity','CatalystDensityField','catalystporosity','CatalystPorosityField','initialtguess','InitialTField','vsource','VSourceDropDown','asource','ASourceDropDown','utilitytinsource','UtilityTinSourceDropDown');if strcmp(key,'heatmode'),obj.setHeatMode(value);elseif isfield(map,key),field=obj.(map.(key));index=[];if obj.ReactorType=="PFR",index=find(strcmp(key,{'v','l','d','ntubes'}),1);end;if ~isempty(index)&&isnumeric(value)&&isscalar(value)&&isnan(value),obj.GeometryOrigins(index)="calculated";elseif isa(field,'matlab.ui.control.EditField'),field.Value=char(string(value));else,field.Value=value;if ~isempty(index),obj.GeometryOrigins(index)="specified";end,end;else,error('nirp:flowsheet:unknownParameter','Unknown reactor parameter "%s".',name);end
        end
    end
end
function [field,units,text]=qty(grid,row,col,label,category),text=uilabel(grid,'Text',label,'HorizontalAlignment','right');text.Layout.Row=row;text.Layout.Column=col;field=uieditfield(grid,'numeric');field.Layout.Row=row;field.Layout.Column=col+1;units=uidropdown(grid,'Items',UnitConverterHelper.getUnits(category));units.Layout.Row=row;units.Layout.Column=col+2;end
function label=portLabel(grid,row,column),label=uilabel(grid,'Text','From input port','FontAngle','italic','HorizontalAlignment','center','Visible','off');label.Layout.Row=row;label.Layout.Column=column;end
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
function value=signalLabel(port)
    % T-131: a parameter port fed by a signal block (e.g. an Adjust) is a
    % signal connection, not a missing stream.
    value='<missing>';line=get_param(port,'Line');if line==-1,return,end
    source=get_param(line,'SrcBlockHandle');if source==-1,return,end
    try,kind=string(get_param(source,'System'));catch,kind=string(get_param(source,'BlockType'));end
    if startsWith(kind,"nirp.blocks."),kind=extractAfter(kind,"nirp.blocks.");end
    value=sprintf('%s (signal): %s',kind,get_param(source,'Name'));
end
