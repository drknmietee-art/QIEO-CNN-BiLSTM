%% run_ablation.m
% Ablation study for the proposed framework.
% Two groups are tested on the same test set and metrics:
%   (A) Architecture / input ablations, all trained with the tuned settings.
%   (B) Optimizer ablation: default vs PSO-tuned vs QIEO-tuned.
%
% Results are printed and saved to ablation_results.mat. Copy the printed
% table into Table 7 of the manuscript.
%
% Requires: loadPVData, trainQuantileNet (with arch support), predictQuantiles,
%           evalForecast, qieoOptimize, psoOptimize.
% Tested for MATLAB R2024b.
% -------------------------------------------------------------------------

clear; clc; close all; rng(42);

%% Base configuration (edit to match main_QIEO_PV.m) --------------------
cfg = struct();
cfg.dataFile   = fullfile('..','Dataset', ...
                          'Solar station site 1 (Nominal capacity-50MW).xlsx');
cfg.capacityMW = 50;
cfg.window     = 96;
cfg.horizonSteps = 1;
cfg.quantiles  = [0.05 0.25 0.50 0.75 0.95];
cfg.trainFrac  = 0.70; cfg.valFrac = 0.15;
cfg.miniBatch  = 256;
cfg.maxEpochsSearch = 8;
cfg.maxEpochsFinal  = 60;      % a bit shorter for the ablation sweep
cfg.searchTrainN = 8000; cfg.searchValN = 3000;
cfg.qieo.popSize = 10; cfg.qieo.generations = 12;
cfg.qieo.bitsPerGene = 6; cfg.qieo.rotStep = 0.05*pi;
cfg.qieo.ranges = struct('filters',[16 128],'kernel',[2 7], ...
    'hidden',[32 256],'logLR',[-4 -2],'dropout',[0.0 0.5]);

% Tuned hyperparameters. If best_hp.mat exists it is loaded, otherwise the
% values from the reported QIEO run are used. Edit if needed.
if isfile('best_hp.mat')
    S = load('best_hp.mat'); tunedHP = S.bestHP;
else
    tunedHP = struct('filters',46,'kernel',6,'hidden',60, ...
                     'lr',6.4e-3,'dropout',0.05);
end
tunedHP.arch = 'cnn_bilstm';

rows = {};   % {name, nRMSE, MAE, PICP, CRPS}

%% (A) Architecture and input ablations ---------------------------------
data = loadPVData(cfg);                       % standard inputs

variants = {
    'Proposed (CNN-BiLSTM)', 'cnn_bilstm', cfg
    'No convolution (BiLSTM)', 'bilstm',   cfg
    'CNN-LSTM',               'cnn_lstm',  cfg
    'Plain LSTM',             'lstm',      cfg
    'CNN only',               'cnn',       cfg
};
for i = 1:size(variants,1)
    hp = tunedHP; hp.arch = variants{i,2};
    fprintf('== %s ==\n', variants{i,1});
    rows(end+1,:) = evalVariant(variants{i,1}, data, cfg, hp); %#ok<SAGROW>
end

% Input ablation: no time features
cfgNT = cfg; cfgNT.useTimeFeatures = false;
dataNT = loadPVData(cfgNT);
rows(end+1,:) = evalVariant('No time features', dataNT, cfgNT, tunedHP);

% Input ablation / improvement: add recent power as input
cfgPL = cfg; cfgPL.usePowerLag = true;
dataPL = loadPVData(cfgPL);
rows(end+1,:) = evalVariant('With recent-power input', dataPL, cfgPL, tunedHP);

%% (B) Optimizer ablation -----------------------------------------------
% Default hyperparameters (no search)
defHP = struct('filters',32,'kernel',3,'hidden',64,'lr',1e-3, ...
               'dropout',0.1,'arch','cnn_bilstm');
rows(end+1,:) = evalVariant('Default hyperparameters', data, cfg, defHP);

% PSO-tuned
dS = subsampleForSearch(data, cfg);
fprintf('== Optimizer ablation: PSO search ==\n');
psoHP = psoOptimize(dS, cfg); psoHP.arch = 'cnn_bilstm';
rows(end+1,:) = evalVariant('PSO-tuned CNN-BiLSTM', data, cfg, psoHP);

% QIEO-tuned (the proposed optimizer)
fprintf('== Optimizer ablation: QIEO search ==\n');
qieoHP = qieoOptimize(dS, cfg); qieoHP.arch = 'cnn_bilstm';
rows(end+1,:) = evalVariant('QIEO-tuned CNN-BiLSTM', data, cfg, qieoHP);

%% Report ----------------------------------------------------------------
T = cell2table(rows, 'VariableNames', ...
    {'Variant','nRMSE_pct','MAE_MW','PICP','CRPS_MW'});
disp(T);
writetable(T,'ablation_results.csv');
save('ablation_results.mat','T');
fprintf('\nSaved ablation_results.csv and .mat. Copy into Table 7.\n');

%% ----------------------------------------------------------------------
function row = evalVariant(name, data, cfg, hp)
    net = trainQuantileNet(data, cfg, hp, cfg.maxEpochsFinal);
    Yq  = sort(predictQuantiles(net, data.XTest),1);
    y   = data.YTest(:).';
    Yq  = max(Yq*data.sg.P + data.mu.P, 0);
    y   = y*data.sg.P + data.mu.P;
    M   = evalForecast(y, Yq, cfg);
    row = {name, round(M.nRMSE,3), round(M.MAE,3), round(M.PICP,4), round(M.CRPS,4)};
    fprintf('   %-26s nRMSE=%.3f MAE=%.3f PICP=%.4f CRPS=%.4f\n', ...
        name, M.nRMSE, M.MAE, M.PICP, M.CRPS);
end

function dS = subsampleForSearch(data, cfg)
    nTr = numel(data.XTrain); nVa = numel(data.XVal);
    iTr = round(linspace(1,nTr,min(cfg.searchTrainN,nTr)));
    iVa = round(linspace(1,nVa,min(cfg.searchValN,nVa)));
    dS = data;
    dS.XTrain = data.XTrain(iTr); dS.YTrain = data.YTrain(iTr);
    dS.XVal   = data.XVal(iVa);   dS.YVal   = data.YVal(iVa);
end
