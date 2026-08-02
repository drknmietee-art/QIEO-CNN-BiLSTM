function M = evalForecast(y, Yq, cfg)
%EVALFORECAST Deterministic and probabilistic metrics. Eq. (28)-(35).
%   y  : [1 x N] measured power (MW)
%   Yq : [Q x N] quantile forecasts (MW), rows match cfg.quantiles
%   Returns struct M with scalar metrics.

    y  = y(:).';
    q  = cfg.quantiles;
    Q  = numel(q);
    N  = numel(y);
    cap= cfg.capacityMW;

    % Median forecast for deterministic scores
    iMed = find(abs(q-0.50)<1e-9,1);
    yhat = Yq(iMed,:);

    err  = y - yhat;
    M.RMSE  = sqrt(mean(err.^2));                      % Eq.28
    M.MAE   = mean(abs(err));                          % Eq.29
    M.nRMSE = M.RMSE/cap*100;                          % Eq.30
    ssRes = sum(err.^2); ssTot = sum((y-mean(y)).^2);
    M.R2    = 1 - ssRes/max(ssTot,eps);                % Eq.31

    % Central interval from lowest and highest quantiles
    L = Yq(1,:); U = Yq(end,:);
    inside = (y>=L) & (y<=U);
    M.PICP  = mean(inside);                            % Eq.32
    M.PINAW = mean(U-L)/cap;                           % Eq.33
    mu = q(end)-q(1);                                  % nominal coverage
    gamma = 50; kappa = 10;
    M.CWC   = M.PINAW*(1 + gamma*exp(-kappa*(M.PICP-mu)));  % Eq.34

    % CRPS approximated from the discrete quantiles (pinball average). Eq.35
    tau = q(:);
    e = y - Yq;
    M.CRPS = 2*mean(max(tau.*e,(tau-1).*e),"all");
end
