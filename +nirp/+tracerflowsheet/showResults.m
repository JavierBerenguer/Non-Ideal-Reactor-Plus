function viewer = showResults(result,varargin)
%SHOWRESULTS Display tracer concentration, source signal, and moments.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================
    p = inputParser ;
    addParameter(p,'Visible','on') ;
    addParameter(p,'AppFactory',[]) ;
    parse(p,varargin{:}) ;
    validateResult(result) ;

    visible = char(string(p.Results.Visible)) ;
    hasSource = isfield(result,'sourceSignal') && ...
        numel(result.sourceSignal) == result.grid.length && ...
        all(isfinite(result.sourceSignal)) ;
    fig = uifigure('Name','Tracer Flowsheet Results', ...
        'Tag','NirpTracerResults','Visible',visible, ...
        'Position',[160 70 900 660]) ;
    hasWarning = ~isempty(result.warning) ;
    resultsHeight = 92+24*hasWarning ;
    sourceHeight = 90*hasSource ;
    root = uigridlayout(fig,[4 1], ...
        'RowHeight',{'1x',sourceHeight,resultsHeight,42},'RowSpacing',6, ...
        'Padding',[14 10 14 10]) ;

    ax = uiaxes(root,'Tag','NirpTracerResponseAxes') ;
    hold(ax,'on') ;
    grid(ax,'on') ;
    outletLine = plot(ax,result.grid.t,result.stream.C, ...
        'LineWidth',1.8,'Color',[0 0.4470 0.7410], ...
        'DisplayName','C(t)','Tag','NirpTracerOutlet') ;
    ylabel(ax,'Outlet concentration, C (mol/m^3)') ;

    sourceLine = gobjects(0) ;
    sourceMarker = gobjects(0) ;
    sourceAxes = uiaxes(root,'Tag','NirpTracerSourceAxes') ;
    if hasSource
        hold(sourceAxes,'on') ;
        grid(sourceAxes,'on') ;
        sourceLine = stairs(sourceAxes,result.grid.t,result.sourceSignal,'--', ...
            'LineWidth',1.5,'Color',[0.8500 0.3250 0.0980], ...
            'Tag','NirpTracerSource') ;
        [sourcePeak,peakIndex] = max(result.sourceSignal) ;
        sourceMarker = plot(sourceAxes,result.grid.t(peakIndex),sourcePeak,'o', ...
            'MarkerSize',6,'MarkerFaceColor',[0.8500 0.3250 0.0980], ...
            'MarkerEdgeColor',[0.8500 0.3250 0.0980], ...
            'HandleVisibility','off','Tag','NirpTracerSourcePeak') ;
        ylabel(sourceAxes,'C_{in} (mol/m^3)') ;
        title(sourceAxes,'Source input') ;
        setSourceLimits(sourceAxes,result.sourceSignal) ;
    else
        sourceAxes.Visible = 'off' ;
    end

    % The half-cell margin makes an input pulse at t = 0 visible instead
    % of drawing its vertical edge underneath the y-axis.
    timeSpan = result.grid.t(end)-result.grid.t(1) ;
    timeMargin = max(0.5*result.grid.dt,0.01*timeSpan) ;
    xlim(ax,[result.grid.t(1)-timeMargin result.grid.t(end)]) ;
    if hasSource
        xlim(sourceAxes,[result.grid.t(1)-timeMargin result.grid.t(end)]) ;
    end
    tau = result.concentrationMoments.tau ;
    tauLine = gobjects(0) ;
    if isfinite(tau)
        tauLine = xline(ax,tau,'--',sprintf('\\tau = %.4g s',tau), ...
            'LineWidth',1.3,'Color',[0.25 0.25 0.25], ...
            'FontSize',12,'LabelOrientation','horizontal', ...
            'LabelHorizontalAlignment','right', ...
            'DisplayName','Mean residence time', ...
            'Tag','NirpTracerTau') ;
    end
    if hasSource
        xlabel(sourceAxes,'Time, t (s)') ;
    else
        xlabel(ax,'Time, t (s)') ;
    end
    title(ax,'Tracer response') ;
    legend(ax,'Location','best') ;

    resultsPanel = uipanel(root,'Title','Results','Tag','NirpTracerResultsPanel') ;
    resultsGrid = uigridlayout(resultsPanel,[3 10], ...
        'ColumnWidth',{'fit','1x','fit','1x','fit','1x','fit','1x','fit','1x'}, ...
        'RowHeight',{28,24,24*hasWarning},'ColumnSpacing',5,'RowSpacing',1, ...
        'Padding',[7 2 7 2]) ;
    description = uilabel(resultsGrid,'Interpreter','latex','WordWrap','on', ...
        'Text',['$A$ checks tracer recovery; $\tau$ is the mean time, ' ...
        '$\sigma^2$ is the variance, and ' ...
        '$N\simeq1/\sigma_\theta^2$ is the equivalent tanks-in-series value.$'], ...
        'Tag','NirpTracerResultsDescription') ;
    description.Layout.Row = 1 ;
    description.Layout.Column = [1 10] ;
    values = result.concentrationMoments ;
    resultLabels = {'$A$','$\tau$','$\sigma^2$','$\sigma_\theta^2$', ...
        '$N\simeq1/\sigma_\theta^2$'} ;
    resultValues = {sprintf('$%.6g$',values.area), ...
        sprintf('$%.6g\\;\\mathrm{s}$',values.tau), ...
        sprintf('$%.6g\\;\\mathrm{s}^2$',values.sigma2), ...
        sprintf('$%.6g$',values.sigma2Theta),sprintf('$%.6g$',values.N)} ;
    for k = 1:numel(resultLabels)
        label = uilabel(resultsGrid,'Interpreter','latex', ...
            'HorizontalAlignment','right','Text',resultLabels{k}, ...
            'Tag',sprintf('NirpTracerResultLabel%d',k)) ;
        label.Layout.Row = 2 ;
        label.Layout.Column = 2*k-1 ;
        value = uilabel(resultsGrid,'Interpreter','latex', ...
            'Text',resultValues{k}, ...
            'Tag',sprintf('NirpTracerResultValue%d',k)) ;
        value.Layout.Row = 2 ;
        value.Layout.Column = 2*k ;
    end
    warningLabel = uilabel(resultsGrid,'Text',result.warning, ...
        'FontColor',[0.75 0.1 0.1],'WordWrap','on', ...
        'Tag','NirpTracerAreaWarning') ;
    warningLabel.Layout.Row = 3 ;
    warningLabel.Layout.Column = [1 10] ;
    warningLabel.Visible = onOff(hasWarning) ;

    [peakDominated,clipLimit,clippedArea] = peakDisplay( ...
        result.stream.C,result.grid.dt) ;
    controls = uigridlayout(root,[1 4], ...
        'ColumnWidth',{245,'1x',190,90},'ColumnSpacing',8, ...
        'Padding',[0 0 0 0]) ;
    peakCheckBox = uicheckbox(controls,'Text','Clip narrow peak for detail', ...
        'Tag','NirpTracerPeakClip','Value',peakDominated, ...
        'Tooltip',['Clip only the plotted y-axis to reveal a broad tail; ' ...
        'the signal and all reported results remain unchanged.'], ...
        'ValueChangedFcn',@setPeakDisplay) ;
    explanation = uilabel(controls,'Text','','WordWrap','on', ...
        'Tag','NirpTracerTransferExplanation') ;
    useButton = uibutton(controls,'Text','Use as RTD in Tab 1', ...
        'Tag','NirpTracerUseAsRTD','ButtonPushedFcn',@(~,~)useAsRtd()) ;
    closeButton = uibutton(controls,'Text','Close', ...
        'ButtonPushedFcn',@(~,~)delete(fig)) ; %#ok<NASGU>
    setPeakDisplay(peakCheckBox) ;

    if result.stream.status ~= 1
        useButton.Enable = 'off' ;
        explanation.Text = ['Unavailable: the network contains multiple ' ...
            'tracer sources, so a single global RTD is undefined.'] ;
        useButton.Tooltip = explanation.Text ;
    elseif isempty(result.rtdMoments) || result.rtdMoments.area <= 0
        useButton.Enable = 'off' ;
        explanation.Text = 'Unavailable: the accumulated RTD has zero area.' ;
        useButton.Tooltip = explanation.Text ;
    end
    viewer = struct('Figure',fig,'Axes',ax,'SourceAxes',sourceAxes, ...
        'OutletLine',outletLine, ...
        'SourceLine',sourceLine,'SourceMarker',sourceMarker, ...
        'TauLine',tauLine,'UseButton',useButton, ...
        'PeakCheckBox',peakCheckBox,'ResultsPanel',resultsPanel, ...
        'Description',description,'Warning',warningLabel, ...
        'Explanation',explanation) ;

    function setPeakDisplay(control,~)
        ax.YScale = 'linear' ;
        if control.Value && peakDominated
            ylim(ax,[0 clipLimit]) ;
            explanation.Text = sprintf([ ...
                'Narrow peak clipped visually (area %.1f%%); ' ...
                'results use the full signal.'],100*clippedArea) ;
        else
            ylim(ax,'auto') ;
            explanation.Text = '' ;
        end
    end

    function useAsRtd()
        E = result.stream.E/result.rtdMoments.area ;
        % Use the topology-derived time correction displayed by the tracer
        % viewer when transferring the RTD to Tab 1.
        rawMoments = nirp.tracer.moments(result.grid,result.stream.E) ;
        correction = result.rtdMoments.tau-rawMoments.tau ;
        signal = nirp.conv.signal(result.grid.t+correction,E) ;
        app = [] ;
        figures = findall(groot,'Type','Figure', ...
            'Name','Non-Ideal Reactor Analysis') ;
        for i = 1:numel(figures)
            if isappdata(figures(i),'NirpNonIdealReactorApp')
                app = getappdata(figures(i),'NirpNonIdealReactorApp') ;
                break
            end
        end
        if isempty(app)
            if isempty(p.Results.AppFactory)
                app = NonIdealReactorApp() ;
            else
                app = p.Results.AppFactory() ;
            end
        end
        app.useTracerFlowsheetRTD(signal) ;
    end
end

function validateResult(result)
    required = {'grid','stream','concentrationMoments','rtdMoments','warning'} ;
    if ~isstruct(result) || ~all(isfield(result,required))
        error('nirp:tracerflowsheet:InvalidResult', ...
            'Tracer result is incomplete.') ;
    end
end

function setSourceLimits(ax,sourceSignal)
    finiteValues = sourceSignal(isfinite(sourceSignal)) ;
    low = min(finiteValues) ;
    high = max(finiteValues) ;
    if high > low
        padding = 0.05*(high-low) ;
    else
        padding = max(0.05*abs(high),1) ;
    end
    ylim(ax,[min(0,low-padding) high+padding]) ;
end

function [value,limit,clippedArea] = peakDisplay(signal,dt)
    positive = signal(isfinite(signal) & signal > 0) ;
    value = false ;
    limit = NaN ;
    clippedArea = 0 ;
    if numel(positive) < 2
        return
    end
    sorted = sort(positive) ;
    broadPeak = sorted(end-1) ;
    value = sorted(end) > 20*broadPeak ;
    if value
        limit = 1.25*broadPeak ;
        fullArea = dt*sum(positive) ;
        clippedArea = dt*sum(positive(positive > limit))/fullArea ;
    end
end

function value = onOff(flag)
    if flag
        value = 'on' ;
    else
        value = 'off' ;
    end
end
