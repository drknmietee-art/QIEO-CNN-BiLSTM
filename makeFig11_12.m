%% makeFig11_12.m
% Generate Figure 11 (ablation) and Figure 12 (sensitivity) as editable
% MATLAB .fig files, plus 300 dpi PNG and vector PDF.
%
% It loads the saved result files if present:
%   ablation_results.mat        (table T from run_ablation.m)
%   sensitivity_dispatch.csv    (from run_sensitivity.m)
%   sensitivity_model.csv       (from run_sensitivity.m, optional)
% If a file is missing, the values from the reported run are used as a
% fallback, so the figures always render.
%
% Tested for MATLAB R2024b.
% -------------------------------------------------------------------------

clear; clc; close all;

%% -------- Load or fall back: ABLATION ---------------------------------
names = {'Proposed (CNN-BiLSTM)','No conv (BiLSTM)','CNN-LSTM','Plain LSTM', ...
         'CNN only','No time features','+Recent power','Default HP', ...
         'PSO-tuned','QIEO-tuned'};
nRMSE = [10.42 9.63 10.67 9.97 10.11 10.15 3.25 13.11 11.87 10.67];
CRPS  = [1.310 1.246 1.437 1.337 1.427 1.335 0.433 1.711 1.585 1.330];
if isfile('ablation_results.mat')
    S = load('ablation_results.mat');
    if isfield(S,'T')
        names = S.T.Variant(:).';
        nRMSE = S.T.nRMSE_pct(:).';
        CRPS  = S.T.CRPS_MW(:).';
    end
end

%% -------- Figure 11 : ablation bar chart ------------------------------
f11 = figure('Color','w','Name','Ablation','Position',[100 100 900 460]);
tl = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

nexttile;
barh(categorical(names,names), nRMSE, 'FaceColor',[0.30 0.55 0.85]);
xlabel('nRMSE (%)'); title('(a) Normalized error'); grid on;

nexttile;
barh(categorical(names,names), CRPS, 'FaceColor',[0.85 0.45 0.30]);
xlabel('CRPS (MW)'); title('(b) Probabilistic score'); grid on;

title(tl,'Ablation study');
savefig(f11,'Fig11_ablation.fig');
exportgraphics(f11,'Fig11_ablation.png','Resolution',300);
exportgraphics(f11,'Fig11_ablation.pdf','ContentType','vector');
fprintf('Saved Fig11_ablation .fig/.png/.pdf\n');

%% -------- Load or fall back: SENSITIVITY ------------------------------
k    = [0.50 0.75 1.00 1.25 1.50];
cost = [9757083 9797065 9837056 9877056 9917034];
resv = [0.951 1.427 1.902 2.378 2.853];
if isfile('sensitivity_dispatch.csv')
    A = readtable('sensitivity_dispatch.csv');
    k = A.ReserveMultiplier_k(:).'; cost = A.TotalCost(:).'; resv = A.MeanReserve_MW(:).';
end
Lwin   = [48 96 192];      nRMSE_L  = [10.217 10.205 10.325];
lrVals = [1e-3 3e-3 1e-2]; nRMSE_lr = [12.125 10.056 11.574];
if isfile('sensitivity_model.csv')
    B = readtable('sensitivity_model.csv');
    s = string(B.Setting);
    li = contains(s,'window'); ri = contains(s,'lr');
    if any(li); nRMSE_L  = B.nRMSE_pct(li).';  end
    if any(ri); nRMSE_lr = B.nRMSE_pct(ri).';  end
end

%% -------- Figure 12 : sensitivity curves ------------------------------
f12 = figure('Color','w','Name','Sensitivity','Position',[100 100 1100 380]);
tl2 = tiledlayout(1,3,'TileSpacing','compact','Padding','compact');

% (a) dispatch: cost and reserve vs k
nexttile; yyaxis left
plot(k,cost/1e6,'-o','LineWidth',1.6); ylabel('Total cost (million units)');
yyaxis right
plot(k,resv,'-s','LineWidth',1.6); ylabel('Mean reserve (MW)');
xlabel('Reserve multiplier k'); title('(a) Dispatch sensitivity'); grid on;

% (b) window length
nexttile;
plot(Lwin,nRMSE_L,'-o','LineWidth',1.6,'Color',[0.30 0.55 0.85]); grid on;
xlabel('Input window L (steps)'); ylabel('nRMSE (%)'); title('(b) Window length');
xticks(Lwin);

% (c) learning rate
nexttile;
semilogx(lrVals,nRMSE_lr,'-o','LineWidth',1.6,'Color',[0.85 0.45 0.30]); grid on;
xlabel('Learning rate'); ylabel('nRMSE (%)'); title('(c) Learning rate');
xticks(lrVals);

title(tl2,'Sensitivity analysis');
savefig(f12,'Fig12_sensitivity.fig');
exportgraphics(f12,'Fig12_sensitivity.png','Resolution',300);
exportgraphics(f12,'Fig12_sensitivity.pdf','ContentType','vector');
fprintf('Saved Fig12_sensitivity .fig/.png/.pdf\n');
