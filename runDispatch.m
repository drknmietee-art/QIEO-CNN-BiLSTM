function dispatch = runDispatch(mdl, Pmed, Pup, cfg)
%RUNDISPATCH Supply forecast signals to the Simulink model and simulate.
%   Builds a demand profile, runs the model, and summarizes the outcome.
%   Also computes a fixed-reserve baseline for comparison (Table 5).

    N = numel(Pmed);
    t = (0:N-1).';

    % --- Synthetic demand: base load plus a daily shape --------------
    base = 0.6*cfg.capacityMW;
    daily = 0.25*cfg.capacityMW*sin(2*pi*(t/96)) ; % 96 steps per day
    D = base + daily + 0.3*Pmed;
    D = max(D, Pmed);                               % demand not below PV

    % --- Clean and push signals as timeseries to base workspace ------
    % From Workspace blocks require timeseries/timetable with no NaN/Inf.
    Pmed = cleanSig(Pmed); Pup = cleanSig(Pup); D = cleanSig(D);
    assignin('base','ts_Pmed', timeseries(Pmed, t));
    assignin('base','ts_Pup',  timeseries(Pup,  t));
    assignin('base','ts_D',    timeseries(D,    t));

    % --- Simulate ----------------------------------------------------
    simOut = sim(mdl,'ReturnWorkspaceOutputs','on');

    Pg   = getSig(simOut,'sim_Pg');
    R    = getSig(simOut,'sim_R');
    Cost = getSig(simOut,'sim_Cost');

    % --- Proposed (interval-based reserve) summary -------------------
    dispatch.time = t;
    dispatch.Pg = Pg; dispatch.R = R; dispatch.Cost = Cost; dispatch.D = D;

    prop.totalCost = sum(Cost);
    prop.meanReserve = mean(R);
    % LOLP proxy: probability upper-quantile headroom fails to cover the
    % 95% band. With reserve = P95 - P50 it is bounded by alpha.
    prop.LOLP = mean( (Pg + Pup) < D );

    % --- Fixed-reserve baseline (10% of capacity) --------------------
    Rfix = 0.10*cfg.capacityMW*ones(N,1);
    cg = 40; cr = 8;
    PgFix = max(D - Pmed,0);
    CostFix = cg*PgFix + cr*Rfix;
    base_.totalCost = sum(CostFix);
    base_.meanReserve = mean(Rfix);
    base_.LOLP = mean( (PgFix + Pmed + Rfix) < D );

    dispatch.summary = struct( ...
        'Proposed_TotalCost',prop.totalCost, ...
        'Proposed_MeanReserveMW',prop.meanReserve, ...
        'Proposed_LOLP',prop.LOLP, ...
        'Fixed_TotalCost',base_.totalCost, ...
        'Fixed_MeanReserveMW',base_.meanReserve, ...
        'Fixed_LOLP',base_.LOLP);

    % --- Dispatch schedule figure (Fig 4) ---------------------------
    n = min(672,N);
    f = figure('Name','Dispatch schedule','Color','w');
    plot(1:n, D(1:n),'k','LineWidth',1.2); hold on;
    plot(1:n, Pmed(1:n),'b','LineWidth',1.0);
    plot(1:n, Pg(1:n),'r','LineWidth',1.0);
    plot(1:n, R(1:n),'g','LineWidth',1.0); grid on;
    xlabel('Time step (15 min)'); ylabel('Power (MW)');
    legend('Demand','PV median','Conventional Pg','Reserve','Location','best');
    title('Forecast-driven economic dispatch');
    saveas(f,'Fig4_dispatch.png');
end

function v = cleanSig(v)
%CLEANSIG Column vector free of NaN/Inf for Simulink From Workspace blocks.
    v = v(:);
    v(~isfinite(v)) = 0;
    v = fillmissing(v,'linear');
    v(~isfinite(v)) = 0;
end

function s = getSig(simOut, name)
    v = simOut.get(name);
    if isnumeric(v); s = v(:);
    elseif isprop(v,'Data') || isfield(v,'Data'); s = v.Data(:);
    else; s = v(:);
    end
end
