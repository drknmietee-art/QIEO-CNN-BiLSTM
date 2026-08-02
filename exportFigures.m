%% exportFigures.m
% Regenerate all result figures from the SAVED results as editable MATLAB
% .fig files (plus high-resolution PNG and vector PDF). No retraining needed.
%
% Requires forecast_results.mat and dispatch_results.mat in this folder,
% which main_QIEO_PV.m already produced.
%
% Output for each figure: <name>.fig (editable), <name>.png (300 dpi),
% <name>.pdf (vector). Open a .fig with:  openfig('Fig8_forecast.fig')
% then resize and restyle freely.
% -------------------------------------------------------------------------

clear; clc; close all;
assert(isfile('forecast_results.mat'),'forecast_results.mat not found');
assert(isfile('dispatch_results.mat'),'dispatch_results.mat not found');
F = load('forecast_results.mat');   % Yq_MW, yTest_MW, hist, cfg, Pmed
D = load('dispatch_results.mat');   % dispatch

q   = F.cfg.quantiles;
y   = F.yTest_MW(:).';
Yq  = F.Yq_MW;
iMed= find(abs(q-0.50)<1e-9,1);
n   = min(672, numel(y));
idx = 1:n;

% Fig 5 : optimizer convergence
f = figure('Color','w','Name','QIEO convergence');
plot(F.hist,'-o','LineWidth',1.5); grid on;
xlabel('Generation'); ylabel('Best validation pinball loss');
title('Quantum-inspired optimizer convergence');
saveAll(f,'Fig5_convergence');

% Fig 8 : median forecast vs measured
f = figure('Color','w','Name','Forecast vs actual');
plot(idx,y(idx),'k','LineWidth',1.2); hold on;
plot(idx,Yq(iMed,idx),'b','LineWidth',1.0); grid on;
xlabel('Time step (15 min)'); ylabel('Power (MW)');
legend('Measured','Median forecast','Location','best');
title('Median forecast vs measured PV power');
saveAll(f,'Fig8_forecast');

% Fig 9 : prediction intervals (90%)
f = figure('Color','w','Name','Prediction intervals');
xf=[idx,fliplr(idx)]; yf=[Yq(1,idx),fliplr(Yq(end,idx))];
fill(xf,yf,[0.8 0.9 1],'EdgeColor','none'); hold on;
plot(idx,y(idx),'k','LineWidth',1.0);
plot(idx,Yq(iMed,idx),'b','LineWidth',1.0); grid on;
xlabel('Time step (15 min)'); ylabel('Power (MW)');
legend('90% interval','Measured','Median','Location','best');
title('Probabilistic PV forecast intervals');
saveAll(f,'Fig9_intervals');

% Fig 10 : reliability diagram
f = figure('Color','w','Name','Reliability');
emp=arrayfun(@(k) mean(y<=Yq(k,:)), 1:numel(q));
plot(q,emp,'-o','LineWidth',1.5); hold on; plot([0 1],[0 1],'k--');
grid on; axis([0 1 0 1]);
xlabel('Nominal quantile'); ylabel('Empirical coverage');
title('Reliability diagram');
saveAll(f,'Fig10_reliability');

% Fig 6 : dispatch schedule
d = D.dispatch; m = min(672,numel(d.Pg));
f = figure('Color','w','Name','Dispatch schedule');
plot(1:m,d.D(1:m),'k','LineWidth',1.2); hold on;
plot(1:m,F.Pmed(1:m),'b','LineWidth',1.0);
plot(1:m,d.Pg(1:m),'r','LineWidth',1.0);
plot(1:m,d.R(1:m),'g','LineWidth',1.0); grid on;
xlabel('Time step (15 min)'); ylabel('Power (MW)');
legend('Demand','PV median','Conventional Pg','Reserve','Location','best');
title('Forecast-driven economic dispatch');
saveAll(f,'Fig6_dispatch');

fprintf('\nAll figures exported as .fig (editable), .png (300 dpi), .pdf (vector).\n');

% ---- local function (must be at end of a script file) -------------------
function saveAll(fh, name)
    savefig(fh, [name '.fig']);                              % editable .fig
    exportgraphics(fh, [name '.png'], 'Resolution', 300);    % 300 dpi PNG
    exportgraphics(fh, [name '.pdf'], 'ContentType', 'vector'); % vector PDF
    fprintf('  saved %s .fig/.png/.pdf\n', name);
end
