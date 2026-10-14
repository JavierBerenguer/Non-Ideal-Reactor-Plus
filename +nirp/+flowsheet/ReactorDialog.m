classdef ReactorDialog < handle
%REACTORDIALOG Structured editor for CSTR and PFR Simulink blocks.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 14, 2026
% =========================================================================
    properties (SetAccess=private)
        BlockPath; ReactorType; Figure; NameField; TypeField
        GeometryModeDropDown; VField; VUnitDropDown; LField; LUnitDropDown
        DField; DUnitDropDown; NTubesField
        TauField; TauUnitDropDown; SpaceVelocityField; SpaceVelocityUnitDropDown
        SuperficialVelocityField; SuperficialVelocityUnitDropDown
        HeatModeGroup; JacketStatusLabel
        PressureModeGroup; PressureEquationGroup; ParticleDiameterField
        ParticleDiameterUnitDropDown; DensityField; DensityUnitDropDown
        ViscosityField; ViscosityUnitDropDown; CatalyticCheckBox
        CatalystDensityField; CatalystPorosityField; InitialTField
        CatalystMassField; CatalystMassUnitDropDown
        InitialTUnitDropDown; VSourceDropDown; HeatPortCheckBox
        JacketPortCheckBox; VPortLabel; ReactionsTable
        ConnectionTable; StatusLabel; DataModel
    end
    properties (Access=private)
        PressureRows; CatalystRows; GeneralGrid; CatalystPanel
        GeometryOrigins = repmat("specified",1,4)
        UpdatingGeometry = false
        DofOrigins
    end
    methods
        function obj=ReactorDialog(blockPath,varargin)
            p=inputParser;addParameter(p,'Visible','on');parse(p,varargin{:});
            obj.BlockPath=getfullname(blockPath); cls=string(get_param(obj.BlockPath,'System'));
            if cls=="nirp.blocks.CSTR",obj.ReactorType="CSTR";
            elseif cls=="nirp.blocks.PFR",obj.ReactorType="PFR";
            else,error('nirp:flowsheet:invalidBlock','ReactorDialog requires a CSTR or PFR block.');end
            try,mask=Simulink.Mask.get(obj.BlockPath);parameter=mask.getParameter('Specifications');if ~isempty(parameter),parameter.Visible='off';end,catch,end
            obj.build(char(string(p.Results.Visible)));nirp.flowsheet.internal.formatNumericControls(obj.Figure);obj.load();obj.refreshConnections();obj.showMissingStatus();
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
            if obj.ReactorType=="PFR"&&strcmp(obj.GeometryModeDropDown.Value,'Length'),obj.DofOrigins.V="empty";elseif obj.ReactorType=="PFR"&&strcmp(obj.GeometryModeDropDown.Value,'Volume'),obj.DofOrigins.L="empty";end
            for i=1:2:numel(args),obj.setOne(args{i},args{i+1});end;obj.updateVisibility();obj.closeGeometry();obj.captureModel();obj.showMissingStatus();
            obj.closeDof();
        end
        function values=getValues(obj),obj.closeDof();values=obj.DataModel;end
        function connections=getConnections(obj),connections=obj.ConnectionTable.Data;end
        function applied=apply(obj)
            applied=false;try
            if strcmp(obj.HeatModeGroup.SelectedObject.Text,'Select...'),error('nirp:flowsheet:missingSpecification','Thermal mode must be selected.');end
            if obj.ReactorType=="PFR"&&strcmp(obj.PressureModeGroup.SelectedObject.Text,'Select...'),error('nirp:flowsheet:missingSpecification','Pressure mode must be selected.');end
            if obj.ReactorType=="PFR"&&strcmp(obj.PressureModeGroup.SelectedObject.Text,'Non constant')&&strcmp(obj.PressureEquationGroup.SelectedObject.Text,'Select...'),error('nirp:flowsheet:missingSpecification','Pressure-drop equation must be selected.');end
            result=obj.closeDof();if ~strcmp(result.status,'complete'),return,end
            % T-131 (D-057): no bypass and no specified T/Q in flowsheet reactors.
            names={'V','VUnit','VSource','HeatMode','InitialTGuess','InitialTGuessUnit','ShowJacketPort','ShowHeatPort','CatalystDensity','CatalystPorosity','Catalytic','Tau','TauUnit','SpaceVelocity','SpaceVelocityUnit','CatalystMass','CatalystMassUnit'};
            values={n(obj.VField.Value),obj.VUnitDropDown.Value,obj.VSourceDropDown.Value,obj.HeatModeGroup.SelectedObject.Text,n(optionalValue(obj.InitialTField)),obj.InitialTUnitDropDown.Value,'off',onoff(obj.HeatPortCheckBox.Value),n(obj.CatalystDensityField.Value),n(obj.CatalystPorosityField.Value),onoff(obj.CatalyticCheckBox.Value),n(obj.TauField.Value),obj.TauUnitDropDown.Value,n(obj.SpaceVelocityField.Value),obj.SpaceVelocityUnitDropDown.Value,n(obj.CatalystMassField.Value),obj.CatalystMassUnitDropDown.Value};
            if obj.ReactorType=="PFR"
                names=[names {'GeometryMode','L','LUnit','D','DUnit','NTubes','PressureMode','PressureDropEqn','ParticleDiameter','ParticleDiameterUnit','Density','DensityUnit','Viscosity','ViscosityUnit','SuperficialVelocity','SuperficialVelocityUnit'}];
                values=[values {'Length',n(obj.LField.Value),obj.LUnitDropDown.Value,n(obj.DField.Value),obj.DUnitDropDown.Value,n(obj.NTubesField.Value),obj.PressureModeGroup.SelectedObject.Text,obj.PressureEquationGroup.SelectedObject.Text,n(obj.ParticleDiameterField.Value),obj.ParticleDiameterUnitDropDown.Value,n(obj.DensityField.Value),obj.DensityUnitDropDown.Value,n(obj.ViscosityField.Value),obj.ViscosityUnitDropDown.Value,n(obj.SuperficialVelocityField.Value),obj.SuperficialVelocityUnitDropDown.Value}];
            end
            names{end+1}='Reactions';values{end+1}=obj.selectedReactions();
            args=reshape([names;values],1,[]);set_param(obj.BlockPath,args{:});nirp.dof.writeSpecs(obj.BlockPath,obj.makeSpecs(result));
            newName=strtrim(obj.NameField.Value);if isempty(newName),error('nirp:flowsheet:invalidName','Name cannot be empty.');end
            if ~strcmp(newName,get_param(obj.BlockPath,'Name')),set_param(obj.BlockPath,'Name',newName);obj.BlockPath=getfullname([bdroot(obj.BlockPath) '/' newName]);end
            obj.captureModel();obj.refreshConnections();obj.closeDof();applied=true;catch exception,obj.StatusLabel.Text=exception.message;end
        end
        function accept(obj),if obj.apply(),delete(obj);else,nirp.flowsheet.internal.showDialogError(obj.Figure,obj.StatusLabel.Text,char(obj.ReactorType));end,end
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
            tabs=uitabgroup(main); general=uitab(tabs,'Title','Reactor');reactionsTab=uitab(tabs,'Title','Reactions');connections=uitab(tabs,'Title','Connections');advanced=uitab(tabs,'Title','Advanced');
            rgrid=uigridlayout(reactionsTab,[2 1],'RowHeight',{30,'1x'});uilabel(rgrid,'Text','Reactions that take place in this reactor (all by default)','FontWeight','bold');
            obj.ReactionsTable=uitable(rgrid,'ColumnName',{'Use','Reaction'},'ColumnEditable',[true false],'ColumnWidth',{50,'auto'},'RowName',{});
            grid=uigridlayout(general,[15 6],'ColumnWidth',{145,110,105,145,110,105}, ...
                'RowHeight',repmat({26},1,15),'RowSpacing',2,'Padding',[5 5 5 5]);obj.GeneralGrid=grid;
            [obj.VField,obj.VUnitDropDown]=qty(grid,1,1,'Volume','Volume');obj.VPortLabel=portLabel(grid,1,2);
            obj.GeometryModeDropDown=drop(grid,2,1,'',{'Select...','Volume','Length'});obj.GeometryModeDropDown.Visible='off';obj.GeometryModeDropDown.ValueChangedFcn=@(~,~) obj.geometryModeChanged();[obj.LField,obj.LUnitDropDown]=qty(grid,3,1,'L','Length');[obj.DField,obj.DUnitDropDown]=qty(grid,4,1,'D','Length');obj.NTubesField=numfield(grid,5,1,'Number of tubes');
            [obj.TauField,obj.TauUnitDropDown]=qty(grid,6,1,'Residence time','Time');[obj.SpaceVelocityField,obj.SpaceVelocityUnitDropDown]=qty(grid,7,1,'Space velocity','TimeInverse');
            geometryTip=uilabel(grid,'Text','One missing PFR geometry value is calculated automatically.','FontAngle','italic','Visible',onoff(obj.ReactorType=="PFR"));geometryTip.Layout.Row=15;geometryTip.Layout.Column=[1 3];
            obj.VField.ValueChangedFcn=@(~,~) obj.geometryEdited(1);obj.LField.ValueChangedFcn=@(~,~) obj.geometryEdited(2);obj.DField.ValueChangedFcn=@(~,~) obj.geometryEdited(3);obj.NTubesField.ValueChangedFcn=@(~,~) obj.geometryEdited(4);
            obj.VUnitDropDown.ValueChangedFcn=@(~,~) obj.closeGeometry();obj.LUnitDropDown.ValueChangedFcn=@(~,~) obj.closeGeometry();obj.DUnitDropDown.ValueChangedFcn=@(~,~) obj.closeGeometry();
            obj.HeatModeGroup=uibuttongroup(grid,'Title','Thermal mode','SelectionChangedFcn',@(~,~) obj.updateVisibility());obj.HeatModeGroup.Layout.Row=[1 3];obj.HeatModeGroup.Layout.Column=[4 6];
            modes={'Select...','Isothermal','Adiabatic','Heat exchange'};for i=1:numel(modes),uiradiobutton(obj.HeatModeGroup,'Text',modes{i},'Position',[10+max(i-2,0)*115 18 110 22],'Visible',onoff(i>1));end % 'Select...' stays hidden: nothing looks chosen until the user picks a mode (Claude, T-154 review)
            obj.JacketStatusLabel=uilabel(grid,'Text','Heat exchange: no Jacket connected','FontAngle','italic');obj.JacketStatusLabel.Layout.Row=4;obj.JacketStatusLabel.Layout.Column=[4 6];
            [obj.SuperficialVelocityField,obj.SuperficialVelocityUnitDropDown]=simpleqty(grid,5,4,'Superficial velocity',{'m/s','cm/s'});
            obj.PressureModeGroup=radioGroup(grid,[8 9],[1 3],'Does pressure change inside the reactor?',{'Select...','Constant','Non constant'},@(~,~) obj.configurationChanged());
            obj.PressureEquationGroup=radioGroup(grid,[10 11],[1 3],'How to compute pressure drop?',{'Select...','Pipe','Ergun'},@(~,~) obj.configurationChanged());
            [obj.ParticleDiameterField,obj.ParticleDiameterUnitDropDown]=qty(grid,12,1,'Particle diameter','Length');[obj.DensityField,obj.DensityUnitDropDown]=qty(grid,13,1,'Density','Density');[obj.ViscosityField,obj.ViscosityUnitDropDown]=qty(grid,14,1,'Viscosity','Viscosity');
            obj.PressureRows={obj.PressureModeGroup,obj.PressureEquationGroup,obj.ParticleDiameterField,obj.ParticleDiameterUnitDropDown,obj.DensityField,obj.DensityUnitDropDown,obj.ViscosityField,obj.ViscosityUnitDropDown};
            obj.CatalystPanel=uipanel(grid,'Title','Catalyst');obj.CatalystPanel.Layout.Column=[4 6];obj.CatalystPanel.Layout.Row=[10 14];
            catalystGrid=uigridlayout(obj.CatalystPanel,[4 3],'ColumnWidth',{185,'1x',80},'RowHeight',{28,28,28,28},'Padding',[8 4 8 4]);
            obj.CatalyticCheckBox=uicheckbox(catalystGrid,'Text','Mark if the reactor is catalytic','ValueChangedFcn',@(~,~) obj.configurationChanged());obj.CatalyticCheckBox.Layout.Row=1;obj.CatalyticCheckBox.Layout.Column=[1 3];
            obj.CatalystDensityField=numfield(catalystGrid,2,1,'Catalyst density (kg/m^3)');obj.CatalystPorosityField=numfield(catalystGrid,3,1,'Catalyst porosity');[obj.CatalystMassField,obj.CatalystMassUnitDropDown]=simpleqty(catalystGrid,4,1,'Catalyst mass',{'kg','g'});obj.CatalystRows={obj.CatalystDensityField,obj.CatalystPorosityField,obj.CatalystMassField,obj.CatalystMassUnitDropDown};
            cgrid=uigridlayout(connections,[2 1],'RowHeight',{30,'1x'});uilabel(cgrid,'Text','Connected streams and signals (read only)','FontWeight','bold');obj.ConnectionTable=uitable(cgrid,'ColumnName',{'Direction','Port','Connection'},'ColumnEditable',false);
            agrid=uigridlayout(advanced,[4 4],'ColumnWidth',{150,110,80,'1x'});obj.VSourceDropDown=drop(agrid,1,1,'Volume source',{'Dialog','Input port'});obj.VSourceDropDown.ValueChangedFcn=@(~,~) obj.configurationChanged();[obj.InitialTField,obj.InitialTUnitDropDown]=texttempqty(agrid,2,1,'Initial T estimate');obj.JacketPortCheckBox=uicheckbox(agrid,'Text','Show Jacket input port');obj.JacketPortCheckBox.Layout.Row=3;obj.JacketPortCheckBox.Layout.Column=[1 2];obj.HeatPortCheckBox=uicheckbox(agrid,'Text','Show heat port');obj.HeatPortCheckBox.Layout.Row=4;obj.HeatPortCheckBox.Layout.Column=[1 2];
            obj.StatusLabel=uilabel(main,'Text','Ready.','FontAngle','italic');buttons=uigridlayout(main,[1 4],'ColumnWidth',{'1x',90,90,90});uilabel(buttons,'Text','');uibutton(buttons,'Text','OK','ButtonPushedFcn',@(~,~) obj.accept());uibutton(buttons,'Text','Cancel','ButtonPushedFcn',@(~,~) obj.cancel());uibutton(buttons,'Text','Apply','ButtonPushedFcn',@(~,~) obj.apply());
            controls={obj.VField,'V';obj.LField,'L';obj.DField,'D';obj.NTubesField,'N_tubes';obj.TauField,'tau';obj.SpaceVelocityField,'SV';obj.SuperficialVelocityField,'u';obj.CatalystMassField,'W';obj.CatalystDensityField,'rho_cat';obj.CatalystPorosityField,'epsilon';obj.ParticleDiameterField,'particleDiameter';obj.DensityField,'density';obj.ViscosityField,'viscosity'};for i=1:size(controls,1),controls{i,1}.ValueChangedFcn=@(~,event)obj.dofEdited(controls{i,2},event);end
        end
        function load(obj)
            obj.DofOrigins=struct('V',"empty",'L',"empty",'D',"empty",'N_tubes',"empty",'tau',"empty",'SV',"empty",'u',"empty",'W',"empty",'rho_cat',"empty",'epsilon',"empty",'particleDiameter',"empty",'density',"empty",'viscosity',"empty");
            obj.NameField.Value=get_param(obj.BlockPath,'Name');obj.TypeField.Value=char(obj.ReactorType);
            pairs={'V',obj.VField;'CatalystDensity',obj.CatalystDensityField;'CatalystPorosity',obj.CatalystPorosityField};for i=1:size(pairs,1),value=str2double(get_param(obj.BlockPath,pairs{i,1}));if ~isnan(value),pairs{i,2}.Value=value;end,end
            obj.InitialTField.Value=get_param(obj.BlockPath,'InitialTGuess');obj.loadReactions();
            units={'VUnit',obj.VUnitDropDown;'InitialTGuessUnit',obj.InitialTUnitDropDown;'VSource',obj.VSourceDropDown};for i=1:size(units,1),units{i,2}.Value=get_param(obj.BlockPath,units{i,1});end
            legacy=get_param(obj.BlockPath,'HeatMode');if ison(get_param(obj.BlockPath,'ShowJacketPort')),legacy='Heat exchange';end
            obj.setHeatMode(legacy);obj.JacketPortCheckBox.Value=ison(get_param(obj.BlockPath,'ShowJacketPort'));obj.HeatPortCheckBox.Value=ison(get_param(obj.BlockPath,'ShowHeatPort'));obj.CatalyticCheckBox.Value=(~isempty(obj.CatalystDensityField.Value)&&obj.CatalystDensityField.Value~=1)||(~isempty(obj.CatalystPorosityField.Value)&&obj.CatalystPorosityField.Value~=0);
            if obj.ReactorType=="PFR",p={'L',obj.LField;'D',obj.DField;'NTubes',obj.NTubesField;'ParticleDiameter',obj.ParticleDiameterField;'Density',obj.DensityField;'Viscosity',obj.ViscosityField};for i=1:size(p,1),value=str2double(get_param(obj.BlockPath,p{i,1}));if ~isnan(value),p{i,2}.Value=value;end,end;u={'GeometryMode',obj.GeometryModeDropDown;'LUnit',obj.LUnitDropDown;'DUnit',obj.DUnitDropDown;'ParticleDiameterUnit',obj.ParticleDiameterUnitDropDown;'DensityUnit',obj.DensityUnitDropDown;'ViscosityUnit',obj.ViscosityUnitDropDown};for i=1:size(u,1),u{i,2}.Value=get_param(obj.BlockPath,u{i,1});end;selectRadio(obj.PressureModeGroup,get_param(obj.BlockPath,'PressureMode'));selectRadio(obj.PressureEquationGroup,get_param(obj.BlockPath,'PressureDropEqn'));raw=[str2double(get_param(obj.BlockPath,'V')) str2double(get_param(obj.BlockPath,'L')) str2double(get_param(obj.BlockPath,'D')) str2double(get_param(obj.BlockPath,'NTubes'))];obj.GeometryOrigins(:)="specified";obj.GeometryOrigins(isnan(raw))="calculated";if all(isfinite(raw)),obj.geometryModeChanged();else,obj.closeGeometry();end;end
            specText=get_param(obj.BlockPath,'Specifications');if isempty(strtrim(specText)),obj.loadLegacyOrigins();else,obj.loadSpecifications(nirp.dof.readSpecs(specText));end
            obj.updateVisibility();obj.closeDof();obj.captureModel();
        end
        function updateVisibility(obj)
            if ~isempty(obj.JacketStatusLabel)&&~isempty(obj.JacketPortCheckBox),obj.JacketStatusLabel.Visible=onoff(strcmp(obj.HeatModeGroup.SelectedObject.Text,'Heat exchange'));obj.JacketPortCheckBox.Visible='off';end
            isPfr=obj.ReactorType=="PFR";for row=3:5,rowvis(obj.GeneralGrid,row,1:3,isPfr);end;for row=8:14,rowvis(obj.GeneralGrid,row,1:3,isPfr);end;rowvis(obj.GeneralGrid,5,4:6,isPfr);
            if isPfr,nonconstant=strcmp(obj.PressureModeGroup.SelectedObject.Text,'Non constant');for row=10:14,rowvis(obj.GeneralGrid,row,1:3,nonconstant);end;ergun=nonconstant&&strcmp(obj.PressureEquationGroup.SelectedObject.Text,'Ergun');rowvis(obj.GeneralGrid,12,1:3,ergun);end
            if isPfr
                obj.GeneralGrid.RowHeight=repmat({26},1,15);obj.CatalystPanel.Layout.Row=[10 14];
            else
                heights=repmat({0},1,15);lastRow=9;obj.CatalystPanel.Layout.Row=[5 9];
                heights(1:lastRow)=repmat({26},1,lastRow);obj.GeneralGrid.RowHeight=heights;
            end
            for i=1:numel(obj.CatalystRows),obj.CatalystRows{i}.Enable=onoff(obj.CatalyticCheckBox.Value);end
            obj.updatePortSources();
        end
        function updatePortSources(obj)
            inputV=strcmp(obj.VSourceDropDown.Value,'Input port');obj.VField.Visible=onoff(~inputV);obj.VField.Editable=onoff(~inputV);obj.VPortLabel.Visible=onoff(inputV);if inputV,obj.VPortLabel.Text=nirp.flowsheet.receivedValue(obj.BlockPath,'V','Volume',obj.VUnitDropDown.Value,2);end
        end
        function refreshConnections(obj)
            graph=nirp.flowsheet.topology(bdroot(obj.BlockPath));key=matlab.lang.makeValidName(get_param(obj.BlockPath,'Name'));data=cell(0,3);jacket='';if isfield(graph.Units,key),item=graph.Units.(key);ports=get_param(obj.BlockPath,'PortHandles');for i=1:numel(item.Inputs),label=joinNames(item.Inputs{i});if isempty(item.Inputs{i})&&i<=numel(ports.Inport),label=signalLabel(ports.Inport(i));end;if contains(label,'Jacket (signal):'),jacket=extractAfter(label,'Jacket (signal): ');end;data(end+1,:)={'Input',i,label};end;for i=1:numel(item.Outputs),data(end+1,:)={'Output',i,joinNames(item.Outputs{i})};end;end;obj.ConnectionTable.Data=data;obj.HeatModeGroup.Visible='on';if isempty(jacket),obj.JacketStatusLabel.Text='Heat exchange: connect a Jacket block to the Jacket port';else,name=char(jacket);if ~startsWith(jacket,"Jacket"),name=['Jacket ' name];end;obj.JacketStatusLabel.Text=['Heat exchange: ' name];end;obj.JacketStatusLabel.Visible=onoff(strcmp(obj.HeatModeGroup.SelectedObject.Text,'Heat exchange'));
        end
        function loadReactions(obj)
            % T-147: one row per package reaction; empty Reactions means all.
            try,pkg=nirp.pkg.readDictionary(nirp.flowsheet.modelDictionary(bdroot(obj.BlockPath)));catch,obj.ReactionsTable.Data=cell(0,2);return,end
            names=string({pkg.components.name});stoich=pkg.reactions.stoich;nR=size(stoich,1);
            try,used=nirp.pkg.reactionIndices(pkg,get_param(obj.BlockPath,'Reactions'));catch,used=1:nR;end
            data=cell(nR,2);for i=1:nR,data{i,1}=any(used==i);data{i,2}=reactionLabel(i,stoich(i,:),names);end
            obj.ReactionsTable.Data=data;
        end
        function setReactionSelection(obj,value)
            data=obj.ReactionsTable.Data;used=nirp.pkg.reactionIndices(struct('reactions',struct('stoich',zeros(size(data,1),1))),value);
            for i=1:size(data,1),data{i,1}=any(used==i);end;obj.ReactionsTable.Data=data;
        end
        function text=selectedReactions(obj)
            data=obj.ReactionsTable.Data;if isempty(data),text='';return,end
            used=find(cell2mat(data(:,1)))';
            if isempty(used),error('nirp:flowsheet:noReactions','Select at least one reaction.');end
            if numel(used)==size(data,1),text='';else,text=['[' char(strjoin(string(used),' ')) ']'];end
        end
        function captureModel(obj)
            q=@(v,u,o) struct('value',v,'unit',string(u),'origin',string(o));obj.DataModel=struct('V',q(obj.VField.Value,obj.VUnitDropDown.Value,obj.DofOrigins.V),'Tau',q(obj.TauField.Value,obj.TauUnitDropDown.Value,obj.DofOrigins.tau),'SpaceVelocity',q(obj.SpaceVelocityField.Value,obj.SpaceVelocityUnitDropDown.Value,obj.DofOrigins.SV),'CatalystDensity',q(obj.CatalystDensityField.Value,'kg/m^3',obj.DofOrigins.rho_cat),'CatalystPorosity',q(obj.CatalystPorosityField.Value,'1',obj.DofOrigins.epsilon),'CatalystMass',q(obj.CatalystMassField.Value,obj.CatalystMassUnitDropDown.Value,obj.DofOrigins.W),'InitialTGuess',q(optionalValue(obj.InitialTField),obj.InitialTUnitDropDown.Value,"specified"));if obj.ReactorType=="PFR",obj.DataModel.L=q(obj.LField.Value,obj.LUnitDropDown.Value,obj.DofOrigins.L);obj.DataModel.D=q(obj.DField.Value,obj.DUnitDropDown.Value,obj.DofOrigins.D);obj.DataModel.NTubes=q(obj.NTubesField.Value,'1',obj.DofOrigins.N_tubes);obj.DataModel.SuperficialVelocity=q(obj.SuperficialVelocityField.Value,obj.SuperficialVelocityUnitDropDown.Value,obj.DofOrigins.u);obj.DataModel.ParticleDiameter=q(obj.ParticleDiameterField.Value,obj.ParticleDiameterUnitDropDown.Value,obj.DofOrigins.particleDiameter);obj.DataModel.Density=q(obj.DensityField.Value,obj.DensityUnitDropDown.Value,obj.DofOrigins.density);obj.DataModel.Viscosity=q(obj.ViscosityField.Value,obj.ViscosityUnitDropDown.Value,obj.DofOrigins.viscosity);end
        end
        function valid=closeGeometry(obj,highlight)
            if nargin<2,highlight=false;end;valid=true;if obj.ReactorType~="PFR"||obj.UpdatingGeometry,return,end
            obj.UpdatingGeometry=true;cleanup=onCleanup(@() obj.finishGeometryUpdate());fields={obj.VField,obj.LField,obj.DField,obj.NTubesField};
            for i=1:4,fields{i}.BackgroundColor=[1 1 1];end
            raw=cellfun(@fieldNumber,{obj.VField,obj.LField,obj.DField,obj.NTubesField});raw(obj.GeometryOrigins=="calculated")=NaN;
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
        function geometryModeChanged(obj),if obj.ReactorType~="PFR"||obj.UpdatingGeometry||strcmp(obj.GeometryModeDropDown.Value,'Select...'),return,end;if strcmp(obj.GeometryModeDropDown.Value,'Length'),obj.GeometryOrigins(1)="calculated";obj.GeometryOrigins(2)="specified";else,obj.GeometryOrigins(1)="specified";obj.GeometryOrigins(2)="calculated";end;obj.closeGeometry();end
        function finishGeometryUpdate(obj),obj.UpdatingGeometry=false;end
        function showMissingStatus(obj)
            missing=strings(0,1);
            if strcmp(obj.VSourceDropDown.Value,'Dialog')&&isempty(obj.VField.Value)&&isempty(strtrim(get_param(obj.BlockPath,'Specifications'))),missing(end+1)="V";end
            if strcmp(obj.HeatModeGroup.SelectedObject.Text,'Select...'),missing(end+1)="thermal mode";end
            if obj.ReactorType=="PFR"
                if strcmp(obj.PressureModeGroup.SelectedObject.Text,'Select...'),missing(end+1)="pressure mode";end
            end
            if isempty(missing),obj.closeDof();return,end
            count=numel(missing);suffix='s';if count==1,suffix='';end
            [~,~,runLabel]=nirp.flowsheet.blockStatus(obj.BlockPath);
            nirp.flowsheet.internal.paintDofStatus(obj.StatusLabel,'missing', ...
                sprintf('%d specification%s missing: %s - %s.',count,suffix,strjoin(missing,', '),runLabel));
        end
        function setOne(obj,name,value)
            key=lower(char(string(name)));
            map=struct('v','VField','l','LField','d','DField','ntubes','NTubesField', ...
                'particlediameter','ParticleDiameterField','density','DensityField', ...
                'viscosity','ViscosityField','catalystdensity','CatalystDensityField', ...
                'catalystporosity','CatalystPorosityField','catalystmass','CatalystMassField','w','CatalystMassField','tau','TauField','spacevelocity','SpaceVelocityField','sv','SpaceVelocityField','superficialvelocity','SuperficialVelocityField','u','SuperficialVelocityField','initialtguess','InitialTField', ...
                'vsource','VSourceDropDown','showjacketport','JacketPortCheckBox');
            if strcmp(key,'heatmode'),obj.setHeatMode(value);return,end
            if strcmp(key,'reactions'),obj.setReactionSelection(value);return,end
            if strcmp(key,'showjacketport'),if ison(value),obj.setHeatMode('Heat exchange');end;return,end
            if ~isfield(map,key),error('nirp:flowsheet:unknownParameter','Unknown reactor parameter "%s".',name);end
            field=obj.(map.(key));index=[];
            dofMap=struct('v','V','l','L','d','D','ntubes','N_tubes','tau','tau','spacevelocity','SV','sv','SV','superficialvelocity','u','u','u','catalystmass','W','w','W','catalystdensity','rho_cat','catalystporosity','epsilon','particlediameter','particleDiameter','density','density','viscosity','viscosity');dofName='';if isfield(dofMap,key),dofName=dofMap.(key);end
            if obj.ReactorType=="PFR",index=find(strcmp(key,{'v','l','d','ntubes'}),1);end
            if isnumeric(value)&&isscalar(value)&&isnan(value)&&isprop(field,'AllowEmpty')
                field.Value=[];if ~isempty(index),obj.GeometryOrigins(index)="calculated";end;if ~isempty(dofName),obj.DofOrigins.(dofName)="empty";end;return
            end
            if isprop(field,'AllowEmpty'),field.Value=value;
            elseif isa(field,'matlab.ui.control.EditField'),field.Value=char(string(value));
            elseif isa(field,'matlab.ui.control.CheckBox'),field.Value=ison(value);
            else,field.Value=value;
            end
            if ~isempty(index),obj.GeometryOrigins(index)="specified";end;if ~isempty(dofName),if isnumeric(value)&&isscalar(value)&&isnan(value),obj.DofOrigins.(dofName)="empty";else,obj.DofOrigins.(dofName)="specified";end,end
        end
        function dofEdited(obj,name,event),if obj.UpdatingGeometry,return,end;value=event.NewData;if isempty(value)||(isnumeric(value)&&isscalar(value)&&isnan(value)),obj.DofOrigins.(name)="empty";else,obj.DofOrigins.(name)="specified";end;obj.closeDof();end
        function configurationChanged(obj),obj.updateVisibility();if ~isempty(obj.DofOrigins),obj.closeDof();end,end
        function loadLegacyOrigins(obj)
            if strcmp(obj.VSourceDropDown.Value,'Input port'),obj.DofOrigins.V="external";else,obj.DofOrigins.V="specified";end
            if obj.ReactorType=="PFR",names={'V','L','D','N_tubes'};for i=1:4,obj.DofOrigins.(names{i})=obj.GeometryOrigins(i);end;end
            if obj.CatalyticCheckBox.Value,obj.DofOrigins.rho_cat="specified";obj.DofOrigins.epsilon="specified";end
            if obj.ReactorType=="PFR"&&strcmp(obj.PressureModeGroup.SelectedObject.Text,'Non constant'),obj.DofOrigins.viscosity="specified";obj.DofOrigins.density="specified";if strcmp(obj.PressureEquationGroup.SelectedObject.Text,'Ergun'),obj.DofOrigins.particleDiameter="specified";end,end
        end
        function loadSpecifications(obj,specs),names=fieldnames(specs);for i=1:numel(names),name=names{i};if isfield(obj.DofOrigins,name),obj.setDofFromSI(name,specs.(name).si,specs.(name).unit);obj.DofOrigins.(name)="specified";end,end;obj.CatalyticCheckBox.Value=any(isfield(specs,{'W','rho_cat','epsilon'}));end
        function result=closeDof(obj)
            catalytic=obj.CatalyticCheckBox.Value;context=struct('catalytic',catalytic);if obj.ReactorType=="PFR",context.pressureMode=obj.PressureModeGroup.SelectedObject.Text;context.pressureDropEqn=obj.PressureEquationGroup.SelectedObject.Text;model=nirp.dof.catalog.pfr(context);else,model=nirp.dof.catalog.cstr(context);end
            [inlet,source]=nirp.dof.knownInlet(obj.BlockPath);values=struct();origins=struct('Q0','external');if isempty(inlet),values.Q0=NaN;else,values.Q0=inlet.Q;end
            names={model.variables.name};for i=1:numel(names),name=names{i};if strcmp(name,'Q0'),continue,end;if strcmp(name,'V')&&strcmp(obj.VSourceDropDown.Value,'Input port'),values.V=NaN;origins.V='external';continue,end;if isfield(obj.DofOrigins,name)&&obj.DofOrigins.(name)=="specified",values.(name)=obj.dofToSI(name);origins.(name)='specified';end,end
            result=nirp.dof.solve(model,values,origins);
            if obj.ReactorType=="CSTR"&&strcmp(obj.VSourceDropDown.Value,'Input port')
                forbidden={'tau','SV','W'};selected=forbidden(cellfun(@(name)isfield(obj.DofOrigins,name)&&obj.DofOrigins.(name)=="specified",forbidden));
                if ~isempty(selected),labels=strings(size(selected));for i=1:numel(selected),labels(i)=string(model.variables(strcmp({model.variables.name},selected{i})).label);end;result.status='conflict';result.missingCount=0;result.missing=strings(0,1);result.conflicts=string(selected);result.messages="Reactor volume from an input port conflicts with specifications for "+strjoin(labels,', ')+".";for i=1:numel(selected),result.states.(selected{i})='conflict';end;end
            end
            for i=1:numel(names),name=names{i};if strcmp(name,'Q0'),continue,end;if isfield(obj.DofOrigins,name),obj.DofOrigins.(name)=string(result.origins.(name));obj.setDofCalculated(name,result.values.(name),result.origins.(name));field=obj.dofField(name);if ~isempty(field),state=result.states.(name);tip=strjoin(result.messages,' ');if isempty(inlet)&&obj.ReactorType=="CSTR"&&any(strcmp(name,{'tau','SV'}))&&obj.DofOrigins.(name)~="specified",state='external';tip='needs a run or a defined feed';end;styleDof(field,state,tip);end,end,end
            obj.captureModel();obj.DataModel.Result=result;if strcmp(result.status,'complete'),message="Fully specified";if strlength(source)>0,message=message+" - "+source;end;elseif strcmp(result.status,'conflict'),message="Conflict: "+strjoin(result.messages,' ');else,message=result.messages(end);end;[~,~,runLabel]=nirp.flowsheet.blockStatus(obj.BlockPath);message=message+" - "+runLabel;if isempty(inlet)&&obj.ReactorType=="CSTR",message=message+"; inlet-dependent values need a run or a defined feed";end;nirp.flowsheet.internal.paintDofStatus(obj.StatusLabel,result.status,message);
        end
        function specs=makeSpecs(obj,result),specs=struct();names=fieldnames(result.values);for i=1:numel(names),name=names{i};if isfield(obj.DofOrigins,name)&&obj.DofOrigins.(name)=="specified",unit=obj.dofUnit(name);specs.(name)=struct('si',result.values.(name),'unit',unit);end,end,end
        function value=dofToSI(obj,name),field=obj.dofField(name);value=field.Value;unit=obj.dofUnit(name);switch name,case 'V',value=UnitConverterHelper.convertToSI('Volume',value,unit);case 'L',value=UnitConverterHelper.convertToSI('Length',value,unit);case 'D',value=UnitConverterHelper.convertToSI('Length',value,unit);case 'tau',value=UnitConverterHelper.convertToSI('Time',value,unit);case 'SV',value=UnitConverterHelper.convertToSI('TimeInverse',value,unit);case 'u',if strcmp(unit,'cm/s'),value=value/100;end;case 'W',if strcmp(unit,'g'),value=value/1000;end;case 'particleDiameter',value=UnitConverterHelper.convertToSI('Length',value,unit);case 'density',value=UnitConverterHelper.convertToSI('Density',value,unit);case 'viscosity',value=UnitConverterHelper.convertToSI('Viscosity',value,unit);end,end
        function setDofCalculated(obj,name,value,origin),if strcmp(origin,'specified')||strcmp(origin,'external')||~isfinite(value),return,end;obj.setDofFromSI(name,value,obj.dofUnit(name));end
        function setDofFromSI(obj,name,value,unit),field=obj.dofField(name);if isempty(field),return,end;dropdown=obj.dofUnitField(name);if ~isempty(dropdown)&&~isempty(unit)&&any(string(dropdown.Items)==string(unit)),dropdown.Value=unit;end;unit=obj.dofUnit(name);switch name,case 'V',value=UnitConverterHelper.convertFromSI('Volume',value,unit);case {'L','D'},value=UnitConverterHelper.convertFromSI('Length',value,unit);case 'tau',value=UnitConverterHelper.convertFromSI('Time',value,unit);case 'SV',value=UnitConverterHelper.convertFromSI('TimeInverse',value,unit);case 'u',if strcmp(unit,'cm/s'),value=value*100;end;case 'W',if strcmp(unit,'g'),value=value*1000;end;case 'particleDiameter',value=UnitConverterHelper.convertFromSI('Length',value,unit);case 'density',value=UnitConverterHelper.convertFromSI('Density',value,unit);case 'viscosity',value=UnitConverterHelper.convertFromSI('Viscosity',value,unit);end;field.Value=value;end
        function value=dofField(obj,name),map=struct('V','VField','L','LField','D','DField','N_tubes','NTubesField','tau','TauField','SV','SpaceVelocityField','u','SuperficialVelocityField','W','CatalystMassField','rho_cat','CatalystDensityField','epsilon','CatalystPorosityField','particleDiameter','ParticleDiameterField','density','DensityField','viscosity','ViscosityField');if isfield(map,name),value=obj.(map.(name));else,value=[];end,end
        function value=dofUnitField(obj,name),map=struct('V','VUnitDropDown','L','LUnitDropDown','D','DUnitDropDown','tau','TauUnitDropDown','SV','SpaceVelocityUnitDropDown','u','SuperficialVelocityUnitDropDown','W','CatalystMassUnitDropDown','particleDiameter','ParticleDiameterUnitDropDown','density','DensityUnitDropDown','viscosity','ViscosityUnitDropDown');if isfield(map,name),value=obj.(map.(name));else,value=[];end,end
        function value=dofUnit(obj,name),dropdown=obj.dofUnitField(name);if isempty(dropdown),if any(strcmp(name,{'N_tubes','epsilon'})),value='1';elseif strcmp(name,'rho_cat'),value='kg/m^3';else,value='';end;else,value=dropdown.Value;end,end
    end
end
function [field,units,text]=qty(grid,row,col,label,category),text=uilabel(grid,'Text',label,'HorizontalAlignment','right');text.Layout.Row=row;text.Layout.Column=col;field=uieditfield(grid,'numeric','AllowEmpty','on','Value',[]);field.Layout.Row=row;field.Layout.Column=col+1;units=uidropdown(grid,'Items',UnitConverterHelper.getUnits(category));units.Layout.Row=row;units.Layout.Column=col+2;end
function [field,units,text]=simpleqty(grid,row,col,label,items),text=uilabel(grid,'Text',label,'HorizontalAlignment','right');text.Layout.Row=row;text.Layout.Column=col;field=uieditfield(grid,'numeric','AllowEmpty','on','Value',[]);field.Layout.Row=row;field.Layout.Column=col+1;units=uidropdown(grid,'Items',items);units.Layout.Row=row;units.Layout.Column=col+2;end
function label=portLabel(grid,row,column),label=uilabel(grid,'Text','From input port','FontAngle','italic','HorizontalAlignment','center','Visible','off');label.Layout.Row=row;label.Layout.Column=column;end
function [field,units,text]=tempqty(grid,row,col,label),[field,units,text]=qty(grid,row,col,label,'Temperature');end
function [field,units,text]=texttempqty(grid,row,col,label),text=uilabel(grid,'Text',label,'HorizontalAlignment','right');text.Layout.Row=row;text.Layout.Column=col;field=uieditfield(grid,'text');field.Layout.Row=row;field.Layout.Column=col+1;units=uidropdown(grid,'Items',UnitConverterHelper.getUnits('Temperature'));units.Layout.Row=row;units.Layout.Column=col+2;end
function [field,text]=numfield(grid,row,col,label),text=uilabel(grid,'Text',label,'HorizontalAlignment','right');text.Layout.Row=row;text.Layout.Column=col;field=uieditfield(grid,'numeric','AllowEmpty','on','Value',[]);field.Layout.Row=row;field.Layout.Column=col+1;end
function field=drop(grid,row,col,label,items),text=uilabel(grid,'Text',label,'HorizontalAlignment','right');text.Layout.Row=row;text.Layout.Column=col;field=uidropdown(grid,'Items',items);field.Layout.Row=row;field.Layout.Column=[col+1 col+2];end
function group=radioGroup(grid,rows,cols,title,items,callback),group=uibuttongroup(grid,'Title',title,'SelectionChangedFcn',callback);group.Layout.Row=rows;group.Layout.Column=cols;for i=1:numel(items),hidden=strcmp(items{i},'Select...');uiradiobutton(group,'Text',items{i},'Position',[10+max(i-1-any(strcmp(items,'Select...')),0)*140 8 130 22],'Visible',onoff(~hidden));end;end
function selectRadio(group,value),b=group.Children;i=find(strcmp({b.Text},value),1);if ~isempty(i),group.SelectedObject=b(i);end,end
function show(items),for i=1:numel(items),items{i}.Visible='on';end,end
function rowvis(grid,row,columns,flag),children=grid.Children;for i=1:numel(children),if any(children(i).Layout.Row==row)&&any(ismember(children(i).Layout.Column,columns)),children(i).Visible=onoff(flag);end,end,end
function setVisible(items,flag),for i=1:numel(items),items{i}.Visible=onoff(flag);end,end
function moveControls(items,row),for i=1:numel(items),items{i}.Layout.Row=row;end,end
function value=onoff(flag),if flag,value='on';else,value='off';end,end
function flag=ison(value),if islogical(value)||isnumeric(value),flag=logical(value);else,flag=strcmp(value,'on')||strcmp(value,'1');end,end
function value=n(x),if isempty(x),value='NaN';else,value=num2str(x,17);end,end
function value=fieldNumber(field),value=field.Value;if isempty(value),value=NaN;end,end
function value=optionalValue(field),value=str2double(field.Value);if ~(isfinite(value)||isnan(value)),error('nirp:flowsheet:invalidParameter','Optional temperature must be numeric or NaN.');end,end
function styleDof(field,state,message),field.BackgroundColor=[1 1 1];field.FontColor=[0 0 0];field.FontAngle='normal';field.Tooltip=char(message);switch char(state),case 'specified',field.FontColor=[0.15 0.25 0.55];case 'calculated',field.BackgroundColor=[0.92 0.92 0.92];field.FontAngle='italic';case 'empty',field.BackgroundColor=[1 0.90 0.90];case 'external',field.BackgroundColor=[0.88 0.88 0.88];case 'conflict',field.BackgroundColor=[1 0.72 0.72];end,end
function text=reactionLabel(index,coefficients,names)
    sides={'',''};for side=1:2,if side==1,c=-min(coefficients,0);else,c=max(coefficients,0);end
        terms=strings(0,1);for k=find(c>0),if abs(c(k)-1)<1e-12,terms(end+1)=names(k);else,terms(end+1)=sprintf('%g %s',c(k),names(k));end,end %#ok<AGROW>
        sides{side}=char(strjoin(terms,' + '));end
    text=sprintf('R%d: %s %s %s',index,sides{1},char(8594),sides{2});
end
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
