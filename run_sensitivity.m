%% run_sensitivity.m
% Sensitivity analysis for the proposed framework.
%   Part A: dispatch sensitivity from the SAVED forecast (no retraining).
%           Varies the reserve multiplier k in R = k*(P95 - P50).
%   Part B: model sensitivity (optional, retrains): input window length L
%           and learning rate, on a subset for speed.
%
% Results are printed and saved. Copy Part A into Table 8.
% Tested for MATLAB R2024b.
% -------------------------------------------------------------------------

clear; clc; close all; rng(42);
doRetrain = true;     % set false to run only the cheap dispatch sensitivity

%% ---------------- Part A: dispatch sensitivity (no retrain) -----------
assert(isfile('forecast_results.mat'),'forecast_results.mat not found');
F = load('forecast_results.mat');
q   = F.cfg.quantiles; cap = F.cfg.capacityMW;
Pmed = F.Yq_MW(abs(q-0.50)<1e-9,:).';
P95  = F.Yq_MW(end,:).';
N = numel(Pmed); t = (0:N-1).';
base = 0.6*cap; daily = 0.25*cap*sin(2*pi*(t/96));
D = max(base + daily + 0.3*Pmed, Pmed);
cg = 40; cr = 8;

kList = [0.50 0.75 1.00 1.25 1.50];
rowsA = {};
for k = kList
    R = k*max(P95 - Pmed,0);
    Pg = max(D - Pmed,0);
    cost = cg*Pg + cr*R;
    lolp = mean( (Pg + Pmed + R) < D );
    rowsA(end+1,:) = {k, round(sum(cost)), round(mean(R),3), round(lolp,5)}; %#ok<SAGROW>
    fprintf('k=%.2f  cost=%d  meanReserve=%.3f MW  LOLP=%.5f\n', ...
        k, round(sum(cost)), mean(R), lolp);
end
TA = cell2table(rowsA,'VariableNames', ...
    {'ReserveMultiplier_k','TotalCost','MeanReserve_MW','LOLP'});
disp(TA); writetable(TA,'sensitivity_dispatch.csv');

%% ---------------- Part B: model sensitivity (retrains) ---------------
if doRetrain
    cfg = struct();
    cfg.dataFile = fullfile('..','Dataset', ...
        'Solar station site 1 (Nominal capacity-50MW).xlsx');
    cfg.capacityMW = 50; cfg.horizonSteps = 1;
    cfg.quantiles = [0.05 0.25 0.50 0.75 0.95];
    cfg.trainFrac = 0.70; cfg.valFrac = 0.15; cfg.miniBatch = 256;
    cfg.maxEpochsFinal = 40;
    hp = struct('filters',46,'kernel',6,'hidden',60,'lr',6.4e-3, ...
                'dropout',0.05,'arch','cnn_bilstm');

    rowsB = {};
    % window length sweep
    for L = [48 96 192]
        c = cfg; c.window = L;
        rowsB(end+1,:) = evalModel(sprintf('window L=%d',L), c, hp); %#ok<SAGROW>
    end
    % learning rate sweep (window fixed at 96)
    for lr = [1e-3 3e-3 1e-2]
        c = cfg; c.window = 96; h = hp; h.lr = lr;
        rowsB(end+1,:) = evalModel(sprintf('lr=%.0e',lr), c, h); %#ok<SAGROW>
    end
    TB = cell2table(rowsB,'VariableNames', ...
        {'Setting','nRMSE_pct','PICP','CRPS_MW'});
    disp(TB); writetable(TB,'sensitivity_model.csv');
end

fprintf('\nSaved sensitivity_dispatch.csv (Table 8) and, if retrained, sensitivity_model.csv.\n');

%% ----------------------------------------------------------------------
function row = evalModel(name, cfg, hp)
    data = loadPVData(cfg);
    net  = trainQuantileNet(data, cfg, hp, cfg.maxEpochsFinal);
    Yq   = sort(predictQuantiles(net, data.XTest),1);
    y    = data.YTest(:).';
    Yq   = max(Yq*data.sg.P + data.mu.P, 0);
    y    = y*data.sg.P + data.mu.P;
    M    = evalForecast(y, Yq, cfg);
    row  = {name, round(M.nRMSE,3), round(M.PICP,4), round(M.CRPS,4)};
    fprintf('   %-14s nRMSE=%.3f PICP=%.4f CRPS=%.4f\n', name, M.nRMSE, M.PICP, M.CRPS);
end
