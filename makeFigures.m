function makeFigures(y, Yq, hist, cfg)
%MAKEFIGURES Generate the figures used in the paper.
    q = cfg.quantiles;
    n = min(672, numel(y));           % one test week at 15 min
    idx = 1:n;
    iMed = find(abs(q-0.50)<1e-9,1);

    % Fig 3: optimizer convergence
    f3 = figure('Name','QIEO convergence','Color','w');
    plot(hist,'-o','LineWidth',1.5); grid on;
    xlabel('Generation'); ylabel('Best validation pinball loss');
    title('Quantum-inspired optimizer convergence');
    saveas(f3,'Fig3_convergence.png');

    % Fig 6: median forecast vs measured
    f6 = figure('Name','Forecast vs actual','Color','w');
    plot(idx, y(idx),'k','LineWidth',1.2); hold on;
    plot(idx, Yq(iMed,idx),'b','LineWidth',1.0); grid on;
    xlabel('Time step (15 min)'); ylabel('Power (MW)');
    legend('Measured','Median forecast','Location','best');
    title('Median forecast vs measured PV power');
    saveas(f6,'Fig6_forecast.png');

    % Fig 7: prediction intervals (90%)
    f7 = figure('Name','Prediction intervals','Color','w');
    xf = [idx, fliplr(idx)];
    yf = [Yq(1,idx), fliplr(Yq(end,idx))];
    fill(xf,yf,[0.8 0.9 1],'EdgeColor','none'); hold on;
    plot(idx, y(idx),'k','LineWidth',1.0);
    plot(idx, Yq(iMed,idx),'b','LineWidth',1.0); grid on;
    xlabel('Time step (15 min)'); ylabel('Power (MW)');
    legend('90% interval','Measured','Median','Location','best');
    title('Probabilistic PV forecast intervals');
    saveas(f7,'Fig7_intervals.png');

    % Fig 8: reliability diagram
    f8 = figure('Name','Reliability','Color','w');
    emp = zeros(1,numel(q));
    for k=1:numel(q)
        emp(k) = mean(y <= Yq(k,:));
    end
    plot(q, emp,'-o','LineWidth',1.5); hold on;
    plot([0 1],[0 1],'k--'); grid on; axis([0 1 0 1]);
    xlabel('Nominal quantile'); ylabel('Empirical coverage');
    title('Reliability diagram');
    saveas(f8,'Fig8_reliability.png');
end
