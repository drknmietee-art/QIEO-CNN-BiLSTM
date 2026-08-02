%% main_QIEO_PV.m
% Quantum-inspired evolutionary-optimized deep learning framework for
% probabilistic short-term solar PV power forecasting and grid dispatch.
%
% Tested for MATLAB R2024b. Requires:
%   - Deep Learning Toolbox
%   - Statistics and Machine Learning Toolbox
%   - Simulink  (for the dispatch model)
%
% Pipeline:
%   1. Load and preprocess the Chinese State Grid dataset (Figshare).
%   2. Build a CNN-BiLSTM quantile network.
%   3. Tune hyperparameters with a quantum-inspired evolutionary optimizer.
%   4. Train the final model and produce probabilistic forecasts.
%   5. Evaluate deterministic and probabilistic metrics.
%   6. Build and run a Simulink dispatch model driven by the intervals.
%
% Author: Dinesh K. N.
% -------------------------------------------------------------------------

clear; clc; close all; rng(42);

%% 0. User configuration -------------------------------------------------
cfg = struct();
% Path to the Excel file inside the Dataset folder. EDIT IF NEEDED.
cfg.dataFile   = fullfile('..','Dataset', ...
                          'Solar station site 1 (Nominal capacity-50MW).xlsx');
cfg.capacityMW = 50;          % nominal plant capacity
cfg.window     = 96;          % input window length (24 h at 15 min)
cfg.horizonSteps = 1;         % forecast horizon in steps (1 = 15 min).
                              % Use 4 -> 1 h, 8 -> 2 h, 16 -> 4 h.
cfg.quantiles  = [0.05 0.25 0.50 0.75 0.95];
cfg.trainFrac  = 0.70;
cfg.valFrac    = 0.15;        % remainder is test
cfg.maxEpochsFinal = 100;
cfg.maxEpochsSearch = 8;      % shorter epochs during optimization
cfg.miniBatch  = 256;

% Speed controls for the search phase (use a subset of windows while
% tuning; the final model still trains on the full training set).
cfg.searchTrainN = 8000;      % training windows used during optimization
cfg.searchValN   = 3000;      % validation windows used during optimization

% Quantum-inspired evolutionary optimizer settings
cfg.qieo.popSize     = 10;
cfg.qieo.generations = 12;
cfg.qieo.bitsPerGene = 6;
cfg.qieo.rotStep     = 0.05*pi;
% Hyperparameter search ranges [min max]
cfg.qieo.ranges = struct( ...
    'filters',   [16 128], ...
    'kernel',    [2 7],    ...
    'hidden',    [32 256], ...
    'logLR',     [-4 -2],  ...   % learning rate = 10^logLR
    'dropout',   [0.0 0.5]);

fprintf('== Loading data ==\n');
data = loadPVData(cfg);

fprintf('== Running quantum-inspired optimization ==\n');
[bestHP, hist] = qieoOptimize(data, cfg);
disp('Best hyperparameters:'); disp(bestHP);
save('best_hp.mat','bestHP');    % reused by run_ablation.m

fprintf('== Training final model ==\n');
[net, mu, sg] = trainQuantileNet(data, cfg, bestHP, cfg.maxEpochsFinal);

fprintf('== Forecasting on test set ==\n');
Yq = predictQuantiles(net, data.XTest);          % [Q x Ntest]
Yq = sort(Yq,1);                                 % enforce non-crossing (Eq.15)
yTest = data.YTest(:).';                          % [1 x Ntest]

% Denormalize power back to MW
Yq_MW    = Yq   * sg.P + mu.P;
yTest_MW = yTest* sg.P + mu.P;
Yq_MW    = max(Yq_MW,0);                          % power cannot be negative

fprintf('== Metrics ==\n');
M = evalForecast(yTest_MW, Yq_MW, cfg);
disp(M);

%% Save forecast arrays for the Simulink dispatch model -----------------
qIdxMed = find(abs(cfg.quantiles-0.50)<1e-9,1);
qIdxUp  = numel(cfg.quantiles);                  % highest quantile
Pmed = Yq_MW(qIdxMed,:).';
Pup  = Yq_MW(qIdxUp ,:).';
save('forecast_results.mat','Yq_MW','yTest_MW','M','hist','cfg','Pmed','Pup');

%% Plots (for the paper figures) ----------------------------------------
makeFigures(yTest_MW, Yq_MW, hist, cfg);

%% Build and run the Simulink dispatch model ----------------------------
fprintf('== Building Simulink dispatch model ==\n');
mdl = buildDispatchModel(Pmed, Pup, cfg);
fprintf('== Running dispatch simulation ==\n');
dispatch = runDispatch(mdl, Pmed, Pup, cfg);
disp('Dispatch summary:'); disp(dispatch.summary);
save('dispatch_results.mat','dispatch');

fprintf('\nDone. Results saved to forecast_results.mat and dispatch_results.mat\n');
