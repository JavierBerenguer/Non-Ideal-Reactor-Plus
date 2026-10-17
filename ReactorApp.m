classdef ReactorApp < matlab.apps.AppBase
    % Original application by Isabela Fons.
    % Modified by Javier Berenguer Sabater, October 17, 2026: Help access.

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        HelpButton                      matlab.ui.control.Button
        ChoosethekindofproblemtobesolvedListBox  matlab.ui.control.ListBox
        ChoosethekindofproblemtobesolvedListBoxLabel  matlab.ui.control.Label
        OptimLocusPannel                matlab.ui.container.Panel
        ReactorLocus                    matlab.ui.control.EditField
        ReactorEditFieldLabel_8         matlab.ui.control.Label
        MinVolumeLocus                  matlab.ui.control.NumericEditField
        MinimumreactorvolumeEditFieldLabel  matlab.ui.control.Label
        MinTimeLocus                    matlab.ui.control.NumericEditField
        MinimumreactiontimeEditFieldLabel  matlab.ui.control.Label
        CheckLocusReactor               matlab.ui.control.CheckBox
        CheckLocusReaction              matlab.ui.control.CheckBox
        ReactiveSystemLocus             matlab.ui.control.EditField
        ReactiveSystemLabel_4           matlab.ui.control.Label
        KeyIndexLocus                   matlab.ui.control.NumericEditField
        KeycomponentindexLabel          matlab.ui.control.Label
        FeedStreamLocus                 matlab.ui.control.EditField
        FeedStreamEditFieldLabel_10     matlab.ui.control.Label
        ProductStreamLocus              matlab.ui.control.EditField
        ProductStreamLabel_4            matlab.ui.control.Label
        RunLocus                        matlab.ui.control.Button
        Image6                          matlab.ui.control.Image
        Image2_5                        matlab.ui.control.Image
        OptimPannel                     matlab.ui.container.Panel
        TypeOfObjectiveFcn              matlab.ui.container.ButtonGroup
        MinimizecostButton              matlab.ui.control.RadioButton
        MinimizeresidencetimeButton     matlab.ui.control.RadioButton
        SolutionLabelEditField          matlab.ui.control.NumericEditField
        SolutionLabelEditFieldLabel     matlab.ui.control.Label
        OptimumsizeEditField            matlab.ui.control.NumericEditField
        OptimumsizeEditFieldLabel       matlab.ui.control.Label
        FeedStreamMin                   matlab.ui.control.EditField
        FeedStreamEditFieldLabel_9      matlab.ui.control.Label
        ProductStreamMin                matlab.ui.control.EditField
        ProductStreamLabel_3            matlab.ui.control.Label
        ReactorMin                      matlab.ui.control.EditField
        ReactorEditFieldLabel_7         matlab.ui.control.Label
        Image_2                         matlab.ui.control.Image
        RunMin                          matlab.ui.control.Button
        ReactiveSystemMin               matlab.ui.control.EditField
        ReactiveSystemLabel_3           matlab.ui.control.Label
        Image2_4                        matlab.ui.control.Image
        RecyclePannel                   matlab.ui.container.Panel
        CostCheckBoxRec                 matlab.ui.control.CheckBox
        CostEditFieldRec                matlab.ui.control.NumericEditField
        TACyearLabel_2                  matlab.ui.control.Label
        RecycleRatio                    matlab.ui.control.NumericEditField
        RecycleRatioEditFieldLabel      matlab.ui.control.Label
        RunRecycle                      matlab.ui.control.Button
        FeedStreamRecycle               matlab.ui.control.EditField
        FeedStreamEditFieldLabel_8      matlab.ui.control.Label
        ReactorRecycle                  matlab.ui.control.EditField
        ReactorEditFieldLabel_6         matlab.ui.control.Label
        Image4                          matlab.ui.control.Image
        ReactiveSystemRecycle           matlab.ui.control.EditField
        ReactiveSystemEditFieldLabel_6  matlab.ui.control.Label
        Image2_3                        matlab.ui.control.Image
        AssociationPannel               matlab.ui.container.Panel
        CostEditFieldAssoc              matlab.ui.control.NumericEditField
        TACyearLabel_3                  matlab.ui.control.Label
        CostCheckBoxAssoc               matlab.ui.control.CheckBox
        ReactiveSystemAssociation       matlab.ui.control.EditField
        ReactiveSystemEditFieldLabel_7  matlab.ui.control.Label
        ButtonAssociation               matlab.ui.container.ButtonGroup
        ParallelButton                  matlab.ui.control.RadioButton
        SeriesButton                    matlab.ui.control.RadioButton
        SplitAssociation                matlab.ui.control.EditField
        SplitoptionalLabel              matlab.ui.control.Label
        FeedStreamAssociation           matlab.ui.control.EditField
        FeedStreamEditFieldLabel_7      matlab.ui.control.Label
        SequenceAssociation             matlab.ui.control.EditField
        SequenceofreactorsLabel         matlab.ui.control.Label
        RunAssociation                  matlab.ui.control.Button
        Image2_2                        matlab.ui.control.Image
        Image3                          matlab.ui.control.Image
        SingleReactorPanel              matlab.ui.container.Panel
        CostEditField                   matlab.ui.control.NumericEditField
        TACyearLabel                    matlab.ui.control.Label
        CostCheckBox                    matlab.ui.control.CheckBox
        RunIndividual                   matlab.ui.control.Button
        ReactiveSystemIndividual        matlab.ui.control.EditField
        ReactiveSystemEditFieldLabel_4  matlab.ui.control.Label
        Image2                          matlab.ui.control.Image
        FeedStreamIndividual            matlab.ui.control.EditField
        FeedStreamEditFieldLabel_6      matlab.ui.control.Label
        ReactorIndividual               matlab.ui.control.EditField
        ReactorEditFieldLabel_5         matlab.ui.control.Label
        Image                           matlab.ui.control.Image
        ProvideinitialdataPanel         matlab.ui.container.Panel
        CreateReactor                   matlab.ui.control.Button
        CreateStream                    matlab.ui.control.Button
        CreateReactiveSystem            matlab.ui.control.Button
        MainWindowLabel                 matlab.ui.control.Label
    end

    
    properties (Access = public)
        solutionStream = Stream ;
        solutionStreamDispayWindow ;
        feedStream
        reactorObject
        reactionSysObject
    end
    
    methods (Access = private)
        
        function displaySolutionWindow(app)
            command2 = 'save solutionVariablesFile.mat ProductData';
            evalin('base',command2)
            load('solutionVariablesFile.mat','ProductData') ;
            app.solutionStreamDispayWindow = defineStreamApp(ProductData) ;
        end
        
        
        function manageVisibilityPannels(app,state)
            app.SingleReactorPanel.Visible = state{1} ;
            app.AssociationPannel.Visible = state{2} ;
            app.RecyclePannel.Visible = state{3} ;
            app.OptimPannel.Visible = state{4} ;
            app.OptimLocusPannel.Visible = state{5} ;
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, varargin)
            % evalin("base",'clear all')
        end

        % Button pushed function: RunIndividual
        function RunIndividualPushed(app, event)
            R  = app.ReactorIndividual.Value ;
            F  = app.FeedStreamIndividual.Value ;
            RS = app.ReactiveSystemIndividual.Value ;
            
            % Ejecutar la función compute_output.
            % PROBLEMA: solución se queda en el Workspace, no en la app
            command = string(['[ProductData,',R,']= compute_output(',R,',',F,',',RS,');']) ;
            evalin('base',command)
            
            % SOLUCIÓN: Guardar la variable que contiene la solución para poder cargarla en la app
            app.displaySolutionWindow
            
            % Cost evaluation
            if app.CostCheckBox.Value
                costCommand = string(['TAC = computeCost(',R,',',F,',ProductData);']) ;
                evalin('base',costCommand) ;
                
                saveCommand = 'save costFile.mat TAC';
                evalin('base',saveCommand)
                load('costFile.mat','TAC') ;
                app.CostEditField.Value = TAC ;
                delete("costFile.mat")
                
                app.CostEditField.Visible = 'on' ;
                app.TACyearLabel.Visible = 'on' ;
            end
            
        end

        % Button pushed function: RunAssociation
        function RunAssociationButtonPushed(app, event)
            evalin('base','auxReactorObj = Reactor ;')
            sequence  = app.SequenceAssociation.Value ;
            F  = app.FeedStreamAssociation.Value ;
            RS = app.ReactiveSystemAssociation.Value ;
            switch app.ButtonAssociation.SelectedObject.Text
                case 'Series'
                    command = string(['[ProductData,sequence] = compute_series(auxReactorObj,',F,',',RS,',{',sequence,'});']) ;
                case 'Parallel'
                    if isempty(app.SplitAssociation.Value)
                        command = string(['[ProductData,sequence]  = compute_parallel(auxReactorObj,',F,',',RS,',{',sequence,'});']) ;
                    else
                        command = string(['[ProductData,sequence]  = compute_parallel(auxReactorObj,',F,',',RS,',{',sequence,'},',app.SplitAssociation.Value,');']) ;
                    end
            end
            evalin('base',command)
            app.displaySolutionWindow
            
            % Cost evaluation
            if app.CostCheckBoxAssoc.Value
                sequence = split(sequence,',') ;
                indvCost = zeros(size(sequence)) ;

                for i = 1:length(sequence)
                    costCommand = sprintf('TAC = computeCost(sequence{%.0f},%s,ProductData);',i,F) ;
                    evalin('base',costCommand) ;
                    
                    saveCommand = 'save costFile.mat TAC';
                    evalin('base',saveCommand)
                    load('costFile.mat','TAC') ;
                    indvCost(i) = TAC ;
                    delete("costFile.mat")
                end
                
                app.CostEditFieldAssoc.Value = sum(indvCost);
                app.CostEditFieldAssoc.Visible = 'on' ;
                app.TACyearLabel_3.Visible = 'on' ;
            end
        end

        % Selection changed function: ButtonAssociation
        function ButtonAssociationSelectionChanged(app, event)
            selectedButton = app.ButtonAssociation.SelectedObject;
            switch selectedButton.Text
                case 'Series'
                    app.SplitoptionalLabel.Visible = 'off' ;
                    app.SplitAssociation.Visible = 'off' ;
                case 'Parallel'
                    app.SplitoptionalLabel.Visible = 'on' ;
                    app.SplitAssociation.Visible = 'on' ;
            end
        end

        % Button pushed function: RunRecycle
        function RunRecycleButtonPushed(app, event)
            R  = app.ReactorRecycle.Value ;
            F  = app.FeedStreamRecycle.Value ;
            RS = app.ReactiveSystemRecycle.Value ;
            recycleRatio = num2str(app.RecycleRatio.Value) ;
            
            command = string(['[ProductData,',R,'] = compute_recycling(',R,',',F,',',RS,',',recycleRatio,');']) ;
            evalin('base',command)
            app.displaySolutionWindow
            
            % Cost evaluation
            if app.CostCheckBoxRec.Value
                costCommand = string(['TAC = computeCost(',R,',',F,',ProductData);']) ;
                evalin('base',costCommand) ;
                
                saveCommand = 'save costFile.mat TAC';
                evalin('base',saveCommand)
                load('costFile.mat','TAC') ;
                app.CostEditFieldRec.Value = TAC ;
                delete("costFile.mat")
                
                app.CostEditFieldRec.Visible = 'on' ;
                app.TACyearLabel_2.Visible = 'on' ;
            end
            
        end

        % Button pushed function: RunMin
        function RunMinButtonPushed(app, event)
            R  = app.ReactorMin.Value ;
            F  = app.FeedStreamMin.Value ;
            P  = app.ProductStreamMin.Value ;
            RS = app.ReactiveSystemMin.Value ;
            
            switch app.TypeOfObjectiveFcn.SelectedObject.Text
                case 'Minimize residence time'
                    command = string(['[optimSize,optimObjFcn] = minimize_residenceTime(',R,',',F,',',RS,',',P,');']) ;
                    app.SolutionLabelEditFieldLabel.Text = 'Minimum residence time' ;
                case 'Minimize cost'
                    command = string(['[optimSize,optimObjFcn] = minimize_cost(',R,',',F,',',RS,',',P,');']) ;
                    app.SolutionLabelEditFieldLabel.Text = 'Minimum cost' ;
            end
            evalin('base',command)
            
            command2 = 'save solutionVariablesFile.mat optimSize optimObjFcn' ;
            evalin('base',command2)
            load('solutionVariablesFile.mat','optimSize','optimObjFcn') ;
            
            app.OptimumsizeEditField.Visible = 'on' ;
            app.OptimumsizeEditFieldLabel.Visible = 'on' ;
            app.OptimumsizeEditField.Value = optimSize ;
            
            app.SolutionLabelEditField.Visible = 'on' ;
            app.SolutionLabelEditFieldLabel.Visible = 'on' ;
            app.SolutionLabelEditField.Value = optimObjFcn ;
            
            delete("solutionVariablesFile.mat")
            
        end

        % Value changed function: CheckLocusReaction, CheckLocusReactor
        function CheckLocusReactionValueChanged(app, event)
            valueReaction = app.CheckLocusReaction.Value;
            valueReactor  = app.CheckLocusReactor.Value ;
            if valueReactor + valueReaction == 1
                app.RunLocus.BackgroundColor = [1.00,1.00,0.00] ; %yellow
                app.RunLocus.Visible = 'on' ;
            elseif valueReactor && valueReaction
                app.RunLocus.BackgroundColor = [0.00,1.00,0.00] ; %green
                app.RunLocus.Visible = 'on' ;
            else
                app.RunLocus.Visible = 'off' ;
            end
        end

        % Button pushed function: RunLocus
        function RunLocusButtonPushed(app, event)
            R  = app.ReactorLocus.Value ;
            F  = app.FeedStreamLocus.Value ;
            P  = app.ProductStreamLocus.Value ;
            RS = app.ReactiveSystemLocus.Value ;
            keyIndex = num2str(app.KeyIndexLocus.Value) ;
            command = string(['[minimumTime,minimumVolume] = find_optimalTemperaturePath(',F,',',P,',',R,',',RS,',',keyIndex,');']) ;
            evalin('base',command)
            
            command2 = 'save solutionVariablesFile.mat minimumTime minimumVolume' ;
            evalin('base',command2)
            load('solutionVariablesFile.mat','minimumTime','minimumVolume') ;
            app.MinTimeLocus.Value = minimumTime ;
            app.MinVolumeLocus.Value = minimumVolume ;
            delete("solutionVariablesFile.mat")
            
            % Cost evaluation
            if app.CostCheckBoxLocus.Value
                costCommand = string(['CBM = estimateCost(',R,',',F,'.P);']) ;
                evalin('base',costCommand) ;
                
                saveCommand = 'save costFile.mat CBM';
                evalin('base',saveCommand)
                load('costFile.mat','CBM') ;
                app.CostEditFieldLocus.Value = CBM ;
                delete("costFile.mat")
            end
        end

        % Button pushed function: CreateReactiveSystem
        function CreateReactiveSystemButtonPushed(app, event)
            defineReactionSysApp
        end

        % Button pushed function: CreateStream
        function CreateStreamButtonPushed(app, event)
            defineStreamApp
        end

        % Button pushed function: CreateReactor
        function CreateReactorButtonPushed(app, event)
            defineReactorApp
        end

        % Value changed function: ChoosethekindofproblemtobesolvedListBox
        function ChoosethekindofproblemtobesolvedListBoxValueChanged(app, event)
            value = app.ChoosethekindofproblemtobesolvedListBox.Value;
            switch value
                case 'Simulate single reactors'
                    state = {'on','off','off','off','off'} ;
                case 'Simulate an association of reactors'
                    state = {'off','on','off','off','off'} ;
                case 'Simulate a reactor with recycling'
                    state = {'off','off','on','off','off'} ;
                case 'Optimize reactor'
                    state = {'off','off','off','on','off'} ;
                case 'Minimize residence time (exothermic reversible reactions)'
                    state = {'off','off','off','off','on'} ;
                case ''
                    state = {'off','off','off','off','off'} ;
            end
            app.manageVisibilityPannels(state) ;
        end

        % Button pushed function: HelpButton
        function HelpButtonPushed(app, event)
            openNirpGuide('IdealGuide.html');
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [400 50 625 612];
            app.UIFigure.Name = 'UI Figure';

            % Create MainWindowLabel
            app.MainWindowLabel = uilabel(app.UIFigure);
            app.MainWindowLabel.HorizontalAlignment = 'center';
            app.MainWindowLabel.FontName = 'Arial';
            app.MainWindowLabel.FontSize = 16;
            app.MainWindowLabel.FontWeight = 'bold';
            app.MainWindowLabel.Position = [188 586 242 25];
            app.MainWindowLabel.Text = 'Main Window';

            % Create ProvideinitialdataPanel
            app.ProvideinitialdataPanel = uipanel(app.UIFigure);
            app.ProvideinitialdataPanel.BorderType = 'none';
            app.ProvideinitialdataPanel.TitlePosition = 'centertop';
            app.ProvideinitialdataPanel.Title = 'Provide initial data';
            app.ProvideinitialdataPanel.Position = [40 533 556 46];

            % Create CreateReactiveSystem
            app.CreateReactiveSystem = uibutton(app.ProvideinitialdataPanel, 'push');
            app.CreateReactiveSystem.ButtonPushedFcn = createCallbackFcn(app, @CreateReactiveSystemButtonPushed, true);
            app.CreateReactiveSystem.Position = [37 3 106 22];
            app.CreateReactiveSystem.Text = 'Reactive System';

            % Create CreateStream
            app.CreateStream = uibutton(app.ProvideinitialdataPanel, 'push');
            app.CreateStream.ButtonPushedFcn = createCallbackFcn(app, @CreateStreamButtonPushed, true);
            app.CreateStream.Position = [231 3 100 22];
            app.CreateStream.Text = 'Stream';

            % Create CreateReactor
            app.CreateReactor = uibutton(app.ProvideinitialdataPanel, 'push');
            app.CreateReactor.ButtonPushedFcn = createCallbackFcn(app, @CreateReactorButtonPushed, true);
            app.CreateReactor.Position = [418 3 100 22];
            app.CreateReactor.Text = 'Reactor';

            % Create SingleReactorPanel
            app.SingleReactorPanel = uipanel(app.UIFigure);
            app.SingleReactorPanel.Visible = 'off';
            app.SingleReactorPanel.BackgroundColor = [0.9412 0.9412 0.9412];
            app.SingleReactorPanel.Position = [78 27 487 337];

            % Create Image
            app.Image = uiimage(app.SingleReactorPanel);
            app.Image.Position = [29 27 450 223];
            app.Image.ImageSource = 'ImageSingleReactor.png';

            % Create ReactorEditFieldLabel_5
            app.ReactorEditFieldLabel_5 = uilabel(app.SingleReactorPanel);
            app.ReactorEditFieldLabel_5.Position = [163 203 96 22];
            app.ReactorEditFieldLabel_5.Text = 'Reactor';

            % Create ReactorIndividual
            app.ReactorIndividual = uieditfield(app.SingleReactorPanel, 'text');
            app.ReactorIndividual.Position = [223 203 100 22];

            % Create FeedStreamEditFieldLabel_6
            app.FeedStreamEditFieldLabel_6 = uilabel(app.SingleReactorPanel);
            app.FeedStreamEditFieldLabel_6.HorizontalAlignment = 'center';
            app.FeedStreamEditFieldLabel_6.Position = [39 111 95 22];
            app.FeedStreamEditFieldLabel_6.Text = 'Feed Stream';

            % Create FeedStreamIndividual
            app.FeedStreamIndividual = uieditfield(app.SingleReactorPanel, 'text');
            app.FeedStreamIndividual.Position = [36 90 100 22];

            % Create Image2
            app.Image2 = uiimage(app.SingleReactorPanel);
            app.Image2.Position = [1 224 160 115];
            app.Image2.ImageSource = 'ImageMolecule.png';

            % Create ReactiveSystemEditFieldLabel_4
            app.ReactiveSystemEditFieldLabel_4 = uilabel(app.SingleReactorPanel);
            app.ReactiveSystemEditFieldLabel_4.Position = [116 290 96 22];
            app.ReactiveSystemEditFieldLabel_4.Text = 'Reactive System';

            % Create ReactiveSystemIndividual
            app.ReactiveSystemIndividual = uieditfield(app.SingleReactorPanel, 'text');
            app.ReactiveSystemIndividual.Position = [114 269 100 22];

            % Create RunIndividual
            app.RunIndividual = uibutton(app.SingleReactorPanel, 'push');
            app.RunIndividual.ButtonPushedFcn = createCallbackFcn(app, @RunIndividualPushed, true);
            app.RunIndividual.FontSize = 16;
            app.RunIndividual.FontWeight = 'bold';
            app.RunIndividual.FontColor = [0 0 1];
            app.RunIndividual.Position = [211 22 65 27];
            app.RunIndividual.Text = 'Run';

            % Create CostCheckBox
            app.CostCheckBox = uicheckbox(app.SingleReactorPanel);
            app.CostCheckBox.Text = 'Evaluate equipment costs';
            app.CostCheckBox.Position = [290 288 159 22];

            % Create TACyearLabel
            app.TACyearLabel = uilabel(app.SingleReactorPanel);
            app.TACyearLabel.HorizontalAlignment = 'right';
            app.TACyearLabel.Visible = 'off';
            app.TACyearLabel.Position = [271 262 73 22];
            app.TACyearLabel.Text = 'TAC ($/year)';

            % Create CostEditField
            app.CostEditField = uieditfield(app.SingleReactorPanel, 'numeric');
            app.CostEditField.Visible = 'off';
            app.CostEditField.Position = [354 262 100 22];

            % Create AssociationPannel
            app.AssociationPannel = uipanel(app.UIFigure);
            app.AssociationPannel.Visible = 'off';
            app.AssociationPannel.Position = [73 27 490 337];

            % Create Image3
            app.Image3 = uiimage(app.AssociationPannel);
            app.Image3.Position = [60 29 417 241];
            app.Image3.ImageSource = 'ImageAsocReactors.png';

            % Create Image2_2
            app.Image2_2 = uiimage(app.AssociationPannel);
            app.Image2_2.Position = [3 224 160 115];
            app.Image2_2.ImageSource = 'ImageMolecule.png';

            % Create RunAssociation
            app.RunAssociation = uibutton(app.AssociationPannel, 'push');
            app.RunAssociation.ButtonPushedFcn = createCallbackFcn(app, @RunAssociationButtonPushed, true);
            app.RunAssociation.FontSize = 16;
            app.RunAssociation.FontWeight = 'bold';
            app.RunAssociation.FontColor = [0 0 1];
            app.RunAssociation.Position = [222 5 47 26];
            app.RunAssociation.Text = 'Run';

            % Create SequenceofreactorsLabel
            app.SequenceofreactorsLabel = uilabel(app.AssociationPannel);
            app.SequenceofreactorsLabel.Position = [237 256 120 22];
            app.SequenceofreactorsLabel.Text = 'Sequence of reactors';

            % Create SequenceAssociation
            app.SequenceAssociation = uieditfield(app.AssociationPannel, 'text');
            app.SequenceAssociation.Tooltip = {'Express the reactors to be associated with their respective names and separated with commas.'; 'Example : Reactor1,Reactor2,...,ReactorN'};
            app.SequenceAssociation.Position = [356 256 109 22];

            % Create FeedStreamEditFieldLabel_7
            app.FeedStreamEditFieldLabel_7 = uilabel(app.AssociationPannel);
            app.FeedStreamEditFieldLabel_7.HorizontalAlignment = 'center';
            app.FeedStreamEditFieldLabel_7.Position = [14 114 93 22];
            app.FeedStreamEditFieldLabel_7.Text = 'Feed Stream';

            % Create FeedStreamAssociation
            app.FeedStreamAssociation = uieditfield(app.AssociationPannel, 'text');
            app.FeedStreamAssociation.Position = [14 93 94 22];

            % Create SplitoptionalLabel
            app.SplitoptionalLabel = uilabel(app.AssociationPannel);
            app.SplitoptionalLabel.Position = [237 233 82 22];
            app.SplitoptionalLabel.Text = 'Split (optional)';

            % Create SplitAssociation
            app.SplitAssociation = uieditfield(app.AssociationPannel, 'text');
            app.SplitAssociation.Tooltip = {'Specify the % of the feed stream that enters each reactor as a vector.'; 'WARNING: the number of elements must coincide with the number of reactors.'; 'EXAMPLE:'; 'Sequence of reactors    Reactor1,Reactor2,Reactor3'; 'Split                               [ 0.5 , 0.25 , 0.25 ]'; '(*) If split is not specified, it is assumed that feed stream splits equally to each reactor.'};
            app.SplitAssociation.Position = [356 233 109 22];

            % Create ButtonAssociation
            app.ButtonAssociation = uibuttongroup(app.AssociationPannel);
            app.ButtonAssociation.SelectionChangedFcn = createCallbackFcn(app, @ButtonAssociationSelectionChanged, true);
            app.ButtonAssociation.BorderColor = [1 1 1];
            app.ButtonAssociation.BorderType = 'none';
            app.ButtonAssociation.Position = [291 288 135 30];

            % Create SeriesButton
            app.SeriesButton = uiradiobutton(app.ButtonAssociation);
            app.SeriesButton.Text = 'Series';
            app.SeriesButton.Position = [4 5 58 22];

            % Create ParallelButton
            app.ParallelButton = uiradiobutton(app.ButtonAssociation);
            app.ParallelButton.Text = 'Parallel';
            app.ParallelButton.Position = [71 5 65 22];
            app.ParallelButton.Value = true;

            % Create ReactiveSystemEditFieldLabel_7
            app.ReactiveSystemEditFieldLabel_7 = uilabel(app.AssociationPannel);
            app.ReactiveSystemEditFieldLabel_7.Position = [117 288 96 22];
            app.ReactiveSystemEditFieldLabel_7.Text = 'Reactive System';

            % Create ReactiveSystemAssociation
            app.ReactiveSystemAssociation = uieditfield(app.AssociationPannel, 'text');
            app.ReactiveSystemAssociation.Position = [117 267 96 22];

            % Create CostCheckBoxAssoc
            app.CostCheckBoxAssoc = uicheckbox(app.AssociationPannel);
            app.CostCheckBoxAssoc.Text = 'Evaluate equipment cost';
            app.CostCheckBoxAssoc.Position = [85 41 153 22];

            % Create TACyearLabel_3
            app.TACyearLabel_3 = uilabel(app.AssociationPannel);
            app.TACyearLabel_3.HorizontalAlignment = 'right';
            app.TACyearLabel_3.Visible = 'off';
            app.TACyearLabel_3.Position = [268 41 73 22];
            app.TACyearLabel_3.Text = 'TAC ($/year)';

            % Create CostEditFieldAssoc
            app.CostEditFieldAssoc = uieditfield(app.AssociationPannel, 'numeric');
            app.CostEditFieldAssoc.Visible = 'off';
            app.CostEditFieldAssoc.Position = [350 41 100 22];

            % Create RecyclePannel
            app.RecyclePannel = uipanel(app.UIFigure);
            app.RecyclePannel.Visible = 'off';
            app.RecyclePannel.Position = [74 27 490 334];

            % Create Image2_3
            app.Image2_3 = uiimage(app.RecyclePannel);
            app.Image2_3.Position = [3 221 160 115];
            app.Image2_3.ImageSource = 'ImageMolecule.png';

            % Create ReactiveSystemEditFieldLabel_6
            app.ReactiveSystemEditFieldLabel_6 = uilabel(app.RecyclePannel);
            app.ReactiveSystemEditFieldLabel_6.Position = [117 292 96 22];
            app.ReactiveSystemEditFieldLabel_6.Text = 'Reactive System';

            % Create ReactiveSystemRecycle
            app.ReactiveSystemRecycle = uieditfield(app.RecyclePannel, 'text');
            app.ReactiveSystemRecycle.Position = [112 268 100 22];

            % Create Image4
            app.Image4 = uiimage(app.RecyclePannel);
            app.Image4.Position = [53 27 388 223];
            app.Image4.ImageSource = 'ImageRecycleReactor.png';

            % Create ReactorEditFieldLabel_6
            app.ReactorEditFieldLabel_6 = uilabel(app.RecyclePannel);
            app.ReactorEditFieldLabel_6.Position = [185 61 96 22];
            app.ReactorEditFieldLabel_6.Text = 'Reactor';

            % Create ReactorRecycle
            app.ReactorRecycle = uieditfield(app.RecyclePannel, 'text');
            app.ReactorRecycle.Position = [237 61 100 22];

            % Create FeedStreamEditFieldLabel_8
            app.FeedStreamEditFieldLabel_8 = uilabel(app.RecyclePannel);
            app.FeedStreamEditFieldLabel_8.Position = [43 91 96 22];
            app.FeedStreamEditFieldLabel_8.Text = 'Feed Stream';

            % Create FeedStreamRecycle
            app.FeedStreamRecycle = uieditfield(app.RecyclePannel, 'text');
            app.FeedStreamRecycle.Position = [26 70 100 22];

            % Create RunRecycle
            app.RunRecycle = uibutton(app.RecyclePannel, 'push');
            app.RunRecycle.ButtonPushedFcn = createCallbackFcn(app, @RunRecycleButtonPushed, true);
            app.RunRecycle.FontSize = 16;
            app.RunRecycle.FontWeight = 'bold';
            app.RunRecycle.FontColor = [0 0 1];
            app.RunRecycle.Position = [219 12 47 26];
            app.RunRecycle.Text = 'Run';

            % Create RecycleRatioEditFieldLabel
            app.RecycleRatioEditFieldLabel = uilabel(app.RecyclePannel);
            app.RecycleRatioEditFieldLabel.Position = [166 189 104 22];
            app.RecycleRatioEditFieldLabel.Text = 'Recycle Ratio';

            % Create RecycleRatio
            app.RecycleRatio = uieditfield(app.RecyclePannel, 'numeric');
            app.RecycleRatio.Limits = [0 Inf];
            app.RecycleRatio.Tooltip = {'Recycle Ratio = (moles recycle stream)/(moles leaving the system)'; ''; 'NOTICE that moles outlet reactor = moles recycle stream + moles leaving system'};
            app.RecycleRatio.Position = [277 189 100 22];

            % Create TACyearLabel_2
            app.TACyearLabel_2 = uilabel(app.RecyclePannel);
            app.TACyearLabel_2.HorizontalAlignment = 'right';
            app.TACyearLabel_2.Visible = 'off';
            app.TACyearLabel_2.Position = [266 254 73 22];
            app.TACyearLabel_2.Text = 'TAC ($/year)';

            % Create CostEditFieldRec
            app.CostEditFieldRec = uieditfield(app.RecyclePannel, 'numeric');
            app.CostEditFieldRec.Visible = 'off';
            app.CostEditFieldRec.Position = [343 254 100 22];

            % Create CostCheckBoxRec
            app.CostCheckBoxRec = uicheckbox(app.RecyclePannel);
            app.CostCheckBoxRec.Text = 'Evaluate equipment cost';
            app.CostCheckBoxRec.Position = [286 280 153 22];

            % Create OptimPannel
            app.OptimPannel = uipanel(app.UIFigure);
            app.OptimPannel.Visible = 'off';
            app.OptimPannel.BackgroundColor = [0.9412 0.9412 0.9412];
            app.OptimPannel.Position = [73 22 487 337];

            % Create Image2_4
            app.Image2_4 = uiimage(app.OptimPannel);
            app.Image2_4.Position = [3 224 160 115];
            app.Image2_4.ImageSource = 'ImageMolecule.png';

            % Create ReactiveSystemLabel_3
            app.ReactiveSystemLabel_3 = uilabel(app.OptimPannel);
            app.ReactiveSystemLabel_3.Position = [134 284 96 22];
            app.ReactiveSystemLabel_3.Text = 'Reactive System';

            % Create ReactiveSystemMin
            app.ReactiveSystemMin = uieditfield(app.OptimPannel, 'text');
            app.ReactiveSystemMin.Position = [132 263 100 22];

            % Create RunMin
            app.RunMin = uibutton(app.OptimPannel, 'push');
            app.RunMin.ButtonPushedFcn = createCallbackFcn(app, @RunMinButtonPushed, true);
            app.RunMin.FontSize = 16;
            app.RunMin.FontWeight = 'bold';
            app.RunMin.FontColor = [0 0 1];
            app.RunMin.Position = [220 7 47 26];
            app.RunMin.Text = 'Run';

            % Create Image_2
            app.Image_2 = uiimage(app.OptimPannel);
            app.Image_2.Position = [28 62 450 138];
            app.Image_2.ImageSource = 'ImageSingleReactor.png';

            % Create ReactorEditFieldLabel_7
            app.ReactorEditFieldLabel_7 = uilabel(app.OptimPannel);
            app.ReactorEditFieldLabel_7.Position = [168 43 96 22];
            app.ReactorEditFieldLabel_7.Text = 'Reactor';

            % Create ReactorMin
            app.ReactorMin = uieditfield(app.OptimPannel, 'text');
            app.ReactorMin.Position = [225 43 100 22];

            % Create ProductStreamLabel_3
            app.ProductStreamLabel_3 = uilabel(app.OptimPannel);
            app.ProductStreamLabel_3.Position = [367 101 89 22];
            app.ProductStreamLabel_3.Text = 'Product Stream';

            % Create ProductStreamMin
            app.ProductStreamMin = uieditfield(app.OptimPannel, 'text');
            app.ProductStreamMin.Position = [361 80 100 22];

            % Create FeedStreamEditFieldLabel_9
            app.FeedStreamEditFieldLabel_9 = uilabel(app.OptimPannel);
            app.FeedStreamEditFieldLabel_9.Position = [31 100 96 22];
            app.FeedStreamEditFieldLabel_9.Text = 'Feed Stream';

            % Create FeedStreamMin
            app.FeedStreamMin = uieditfield(app.OptimPannel, 'text');
            app.FeedStreamMin.Position = [14 80 100 22];

            % Create OptimumsizeEditFieldLabel
            app.OptimumsizeEditFieldLabel = uilabel(app.OptimPannel);
            app.OptimumsizeEditFieldLabel.HorizontalAlignment = 'right';
            app.OptimumsizeEditFieldLabel.FontWeight = 'bold';
            app.OptimumsizeEditFieldLabel.Visible = 'off';
            app.OptimumsizeEditFieldLabel.Position = [355 304 84 22];
            app.OptimumsizeEditFieldLabel.Text = 'Optimum size';

            % Create OptimumsizeEditField
            app.OptimumsizeEditField = uieditfield(app.OptimPannel, 'numeric');
            app.OptimumsizeEditField.FontWeight = 'bold';
            app.OptimumsizeEditField.Visible = 'off';
            app.OptimumsizeEditField.Position = [352 283 100 22];

            % Create SolutionLabelEditFieldLabel
            app.SolutionLabelEditFieldLabel = uilabel(app.OptimPannel);
            app.SolutionLabelEditFieldLabel.HorizontalAlignment = 'right';
            app.SolutionLabelEditFieldLabel.FontWeight = 'bold';
            app.SolutionLabelEditFieldLabel.Visible = 'off';
            app.SolutionLabelEditFieldLabel.Position = [357 256 88 22];
            app.SolutionLabelEditFieldLabel.Text = 'Solution Label';

            % Create SolutionLabelEditField
            app.SolutionLabelEditField = uieditfield(app.OptimPannel, 'numeric');
            app.SolutionLabelEditField.FontWeight = 'bold';
            app.SolutionLabelEditField.Visible = 'off';
            app.SolutionLabelEditField.Position = [351 237 100 22];

            % Create TypeOfObjectiveFcn
            app.TypeOfObjectiveFcn = uibuttongroup(app.OptimPannel);
            app.TypeOfObjectiveFcn.BorderColor = [1 1 1];
            app.TypeOfObjectiveFcn.BorderType = 'none';
            app.TypeOfObjectiveFcn.BackgroundColor = [0.5686 0.7529 0.9804];
            app.TypeOfObjectiveFcn.Position = [100 195 297 30];

            % Create MinimizeresidencetimeButton
            app.MinimizeresidencetimeButton = uiradiobutton(app.TypeOfObjectiveFcn);
            app.MinimizeresidencetimeButton.Text = 'Minimize residence time';
            app.MinimizeresidencetimeButton.Position = [11 4 151 22];
            app.MinimizeresidencetimeButton.Value = true;

            % Create MinimizecostButton
            app.MinimizecostButton = uiradiobutton(app.TypeOfObjectiveFcn);
            app.MinimizecostButton.Text = 'Minimize cost';
            app.MinimizecostButton.Position = [181 4 95 22];

            % Create OptimLocusPannel
            app.OptimLocusPannel = uipanel(app.UIFigure);
            app.OptimLocusPannel.Visible = 'off';
            app.OptimLocusPannel.Position = [73 27 487 337];

            % Create Image2_5
            app.Image2_5 = uiimage(app.OptimLocusPannel);
            app.Image2_5.Position = [3 224 160 115];
            app.Image2_5.ImageSource = 'ImageMolecule.png';

            % Create Image6
            app.Image6 = uiimage(app.OptimLocusPannel);
            app.Image6.Position = [58 105 380 142];
            app.Image6.ImageSource = 'ImageSingleReactor.png';

            % Create RunLocus
            app.RunLocus = uibutton(app.OptimLocusPannel, 'push');
            app.RunLocus.ButtonPushedFcn = createCallbackFcn(app, @RunLocusButtonPushed, true);
            app.RunLocus.BackgroundColor = [0.9412 0.9412 0.9412];
            app.RunLocus.FontSize = 16;
            app.RunLocus.FontWeight = 'bold';
            app.RunLocus.FontColor = [0 0 1];
            app.RunLocus.Visible = 'off';
            app.RunLocus.Position = [218 13 47 26];
            app.RunLocus.Text = 'Run';

            % Create ProductStreamLabel_4
            app.ProductStreamLabel_4 = uilabel(app.OptimLocusPannel);
            app.ProductStreamLabel_4.Position = [354 147 89 22];
            app.ProductStreamLabel_4.Text = 'Product Stream';

            % Create ProductStreamLocus
            app.ProductStreamLocus = uieditfield(app.OptimLocusPannel, 'text');
            app.ProductStreamLocus.Position = [345 126 100 22];

            % Create FeedStreamEditFieldLabel_10
            app.FeedStreamEditFieldLabel_10 = uilabel(app.OptimLocusPannel);
            app.FeedStreamEditFieldLabel_10.Position = [29 146 96 22];
            app.FeedStreamEditFieldLabel_10.Text = 'Feed Stream';

            % Create FeedStreamLocus
            app.FeedStreamLocus = uieditfield(app.OptimLocusPannel, 'text');
            app.FeedStreamLocus.Position = [29 126 100 22];

            % Create KeycomponentindexLabel
            app.KeycomponentindexLabel = uilabel(app.OptimLocusPannel);
            app.KeycomponentindexLabel.Position = [29 203 121 22];
            app.KeycomponentindexLabel.Text = 'Key component index';

            % Create KeyIndexLocus
            app.KeyIndexLocus = uieditfield(app.OptimLocusPannel, 'numeric');
            app.KeyIndexLocus.Limits = [0 Inf];
            app.KeyIndexLocus.ValueDisplayFormat = '%.0f';
            app.KeyIndexLocus.Tooltip = {'Enter the index of the key component.'; ''; 'EXAMPLE: '; '2A + B <-> C'; 'B is the key component.'; 'When the stochiometric matrix was specified, B is always in column 2. Then, '; 'Key Component Index = 2 '};
            app.KeyIndexLocus.Position = [29 182 100 22];

            % Create ReactiveSystemLabel_4
            app.ReactiveSystemLabel_4 = uilabel(app.OptimLocusPannel);
            app.ReactiveSystemLabel_4.Position = [127 291 96 22];
            app.ReactiveSystemLabel_4.Text = 'Reactive System';

            % Create ReactiveSystemLocus
            app.ReactiveSystemLocus = uieditfield(app.OptimLocusPannel, 'text');
            app.ReactiveSystemLocus.Position = [125 270 100 22];

            % Create CheckLocusReaction
            app.CheckLocusReaction = uicheckbox(app.OptimLocusPannel);
            app.CheckLocusReaction.ValueChangedFcn = createCallbackFcn(app, @CheckLocusReactionValueChanged, true);
            app.CheckLocusReaction.Text = 'I know this function is only valid for SINGLE, REVERSIBLE EXOTHERMIC reactions';
            app.CheckLocusReaction.FontColor = [1 0 0];
            app.CheckLocusReaction.Position = [7 62 481 22];

            % Create CheckLocusReactor
            app.CheckLocusReactor = uicheckbox(app.OptimLocusPannel);
            app.CheckLocusReactor.ValueChangedFcn = createCallbackFcn(app, @CheckLocusReactionValueChanged, true);
            app.CheckLocusReactor.Text = 'I know ADIABATIC REACTORS are NOT supported in this function';
            app.CheckLocusReactor.FontColor = [1 0 0];
            app.CheckLocusReactor.Position = [7 48 384 22];

            % Create MinimumreactiontimeEditFieldLabel
            app.MinimumreactiontimeEditFieldLabel = uilabel(app.OptimLocusPannel);
            app.MinimumreactiontimeEditFieldLabel.HorizontalAlignment = 'right';
            app.MinimumreactiontimeEditFieldLabel.FontWeight = 'bold';
            app.MinimumreactiontimeEditFieldLabel.Position = [322 302 136 22];
            app.MinimumreactiontimeEditFieldLabel.Text = 'Minimum reaction time';

            % Create MinTimeLocus
            app.MinTimeLocus = uieditfield(app.OptimLocusPannel, 'numeric');
            app.MinTimeLocus.FontWeight = 'bold';
            app.MinTimeLocus.Position = [345 281 100 22];

            % Create MinimumreactorvolumeEditFieldLabel
            app.MinimumreactorvolumeEditFieldLabel = uilabel(app.OptimLocusPannel);
            app.MinimumreactorvolumeEditFieldLabel.HorizontalAlignment = 'right';
            app.MinimumreactorvolumeEditFieldLabel.FontWeight = 'bold';
            app.MinimumreactorvolumeEditFieldLabel.Position = [316 260 148 22];
            app.MinimumreactorvolumeEditFieldLabel.Text = 'Minimum reactor volume';

            % Create MinVolumeLocus
            app.MinVolumeLocus = uieditfield(app.OptimLocusPannel, 'numeric');
            app.MinVolumeLocus.FontWeight = 'bold';
            app.MinVolumeLocus.Position = [345 242 100 22];

            % Create ReactorEditFieldLabel_8
            app.ReactorEditFieldLabel_8 = uilabel(app.OptimLocusPannel);
            app.ReactorEditFieldLabel_8.Position = [165 104 96 22];
            app.ReactorEditFieldLabel_8.Text = 'Reactor';

            % Create ReactorLocus
            app.ReactorLocus = uieditfield(app.OptimLocusPannel, 'text');
            app.ReactorLocus.Position = [225 103 100 22];

            % Create ChoosethekindofproblemtobesolvedListBoxLabel
            app.ChoosethekindofproblemtobesolvedListBoxLabel = uilabel(app.UIFigure);
            app.ChoosethekindofproblemtobesolvedListBoxLabel.HorizontalAlignment = 'right';
            app.ChoosethekindofproblemtobesolvedListBoxLabel.FontWeight = 'bold';
            app.ChoosethekindofproblemtobesolvedListBoxLabel.Position = [199 499 240 22];
            app.ChoosethekindofproblemtobesolvedListBoxLabel.Text = 'Choose the kind of problem to be solved';

            % Create ChoosethekindofproblemtobesolvedListBox
            app.ChoosethekindofproblemtobesolvedListBox = uilistbox(app.UIFigure);
            app.ChoosethekindofproblemtobesolvedListBox.Items = {'', 'Simulate single reactors', 'Simulate an association of reactors', 'Simulate a reactor with recycling', 'Optimize reactor', 'Minimize residence time (exothermic reversible reactions)'};
            app.ChoosethekindofproblemtobesolvedListBox.ValueChangedFcn = createCallbackFcn(app, @ChoosethekindofproblemtobesolvedListBoxValueChanged, true);
            app.ChoosethekindofproblemtobesolvedListBox.Position = [74 378 490 117];
            app.ChoosethekindofproblemtobesolvedListBox.Value = '';

            % Create HelpButton
            app.HelpButton = uibutton(app.UIFigure, 'push');
            app.HelpButton.ButtonPushedFcn = createCallbackFcn(app, @HelpButtonPushed, true);
            app.HelpButton.Position = [77 568 105 23];
            app.HelpButton.Text = 'Help';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = ReactorApp(varargin)

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end
