function viewer = showResults(result,varargin)
%SHOWRESULTS Display tracer concentration, source signal, and moments.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================
    p=inputParser;addParameter(p,'Visible','on');addParameter(p,'AppFactory',[]);parse(p,varargin{:});
    validateResult(result);visible=char(string(p.Results.Visible));
    fig=uifigure('Name','Tracer Flowsheet Results','Tag','NirpTracerResults', ...
        'Visible',visible,'Position',[160 100 860 590]);
    root=uigridlayout(fig,[3 1],'RowHeight',{'1x',125,45},'Padding',[14 12 14 12]);
    ax=uiaxes(root);hold(ax,'on');grid(ax,'on');yyaxis(ax,'left');
    plot(ax,result.grid.t,result.stream.C,'LineWidth',1.8,'DisplayName','C(t)');
    ylabel(ax,'Outlet concentration, C (mol/m^3)');
    if isfield(result,'sourceSignal')&&numel(result.sourceSignal)==result.grid.length&&all(isfinite(result.sourceSignal))
        yyaxis(ax,'right');
        plot(ax,result.grid.t,result.sourceSignal,'--','LineWidth',1.2,'DisplayName','C_{in}(t)');
        ylabel(ax,'Source concentration, C_{in} (mol/m^3)');
        yyaxis(ax,'left');
    end
    tau=result.concentrationMoments.tau;
    if isfinite(tau),xline(ax,tau,'--','\tau','LineWidth',1.2,'DisplayName','Mean residence time');end
    xlabel(ax,'Time, t (s)');title(ax,'Tracer response');legend(ax,'Location','best');
    values=result.concentrationMoments;
    summary=uilabel(root,'Interpreter','latex','WordWrap','on','FontSize',13, ...
        'Text',sprintf(['Area = %.6g, $\\tau$ = %.6g s, $\\sigma^2$ = %.6g s$^2$, ' ...
        '$\\sigma_\\theta^2$ = %.6g, $N \\approx 1/\\sigma_\\theta^2$ = %.6g\n%s'], ...
        values.area,values.tau,values.sigma2,values.sigma2Theta,values.N,result.warning));
    controls=uigridlayout(root,[1 3],'ColumnWidth',{'1x',190,260});
    explanation=uilabel(controls,'Text','','WordWrap','on');
    useButton=uibutton(controls,'Text','Use as RTD in Tab 1','Tag','NirpTracerUseAsRTD', ...
        'ButtonPushedFcn',@(~,~)useAsRtd());
    closeButton=uibutton(controls,'Text','Close','ButtonPushedFcn',@(~,~)delete(fig)); %#ok<NASGU>
    if result.stream.status~=1
        useButton.Enable='off';
        explanation.Text='Unavailable: the network contains multiple tracer sources, so a single global RTD is undefined.';
        useButton.Tooltip=explanation.Text;
    elseif isempty(result.rtdMoments)||result.rtdMoments.area<=0
        useButton.Enable='off';explanation.Text='Unavailable: the accumulated RTD has zero area.';useButton.Tooltip=explanation.Text;
    end
    viewer=struct('Figure',fig,'Axes',ax,'UseButton',useButton,'Summary',summary,'Explanation',explanation);

    function useAsRtd()
        E=result.stream.E/result.rtdMoments.area;
        % Use the topology-derived time correction displayed by the tracer
        % viewer when transferring the RTD to Tab 1.
        correction=result.rtdMoments.tau-nirp.tracer.moments(result.grid,result.stream.E).tau;
        signal=nirp.conv.signal(result.grid.t+correction,E);
        app=[];figures=findall(groot,'Type','Figure','Name','Non-Ideal Reactor Analysis');
        for i=1:numel(figures)
            if isappdata(figures(i),'NirpNonIdealReactorApp'),app=getappdata(figures(i),'NirpNonIdealReactorApp');break,end
        end
        if isempty(app)
            if isempty(p.Results.AppFactory),app=NonIdealReactorApp();else,app=p.Results.AppFactory();end
        end
        app.useTracerFlowsheetRTD(signal);
    end
end

function validateResult(result)
required={'grid','stream','concentrationMoments','rtdMoments','warning'};
if ~isstruct(result)||~all(isfield(result,required)),error('nirp:tracerflowsheet:InvalidResult','Tracer result is incomplete.');end
end
