function [bestHP, hist] = qieoOptimize(data, cfg)
%QIEOOPTIMIZE Quantum-inspired evolutionary optimization of hyperparameters.
%   Implements Eq. (17)-(22): qubit encoding, measurement, rotation-gate
%   update, and pinball-loss fitness on the validation set.
%
%   Genes (in order): filters, kernel, hidden, logLR, dropout
%   Each gene uses B bits. A chromosome has G*B qubits.

    G  = 5;                       % number of genes
    B  = cfg.qieo.bitsPerGene;
    Lq = G*B;                     % total qubits per individual
    P  = cfg.qieo.popSize;
    Gen= cfg.qieo.generations;
    dth= cfg.qieo.rotStep;
    tau= cfg.quantiles(:);

    % Qubit amplitudes, initialized to equal superposition (Eq.17)
    alpha = ones(P,Lq)/sqrt(2);
    beta  = ones(P,Lq)/sqrt(2);

    bestFit = inf; bestBits = zeros(1,Lq); bestHP = [];
    hist = zeros(Gen,1);

    % --- Build a smaller data set for the search phase (speed) ---------
    dataS = subsampleData(data, cfg);

    % --- Memoization cache: same hyperparameters -> reuse fitness ------
    cache = containers.Map('KeyType','char','ValueType','double');

    for g = 1:Gen
        bitsPop = zeros(P,Lq);
        fitPop  = zeros(P,1);

        for p = 1:P
            % --- Measurement (Eq.18) ---
            r = rand(1,Lq);
            bits = double(r > alpha(p,:).^2);
            bitsPop(p,:) = bits;

            % --- Decode + evaluate (with cache) ---
            hp  = decodeHP(bits, B, cfg);
            key = sprintf('%d_%d_%d_%.5f_%.3f', hp.filters, hp.kernel, ...
                          hp.hidden, hp.lr, hp.dropout);
            if isKey(cache, key)
                fitPop(p) = cache(key);
            else
                fitPop(p) = evalFitness(dataS, cfg, hp, tau);
                cache(key) = fitPop(p);
            end
        end

        [fg, ip] = min(fitPop);
        if fg < bestFit
            bestFit  = fg;
            bestBits = bitsPop(ip,:);
            bestHP   = decodeHP(bestBits, B, cfg);
        end
        hist(g) = bestFit;
        fprintf('  Gen %2d/%2d  bestFit=%.5f  (filters=%d kernel=%d hidden=%d lr=%.1e drop=%.2f)\n', ...
            g, Gen, bestFit, bestHP.filters, bestHP.kernel, bestHP.hidden, bestHP.lr, bestHP.dropout);

        % --- Rotation-gate update toward the best (Eq.20-21) ---
        for p = 1:P
            s = dth * sign(bestBits - bitsPop(p,:));   % angle per qubit
            a = alpha(p,:); b = beta(p,:);
            alpha(p,:) = cos(s).*a - sin(s).*b;
            beta(p,:)  = sin(s).*a + cos(s).*b;
        end
    end
end

% ------------------------------------------------------------------------
function hp = decodeHP(bits, B, cfg)
%DECODEHP Map a binary chromosome to real hyperparameters (Eq.19).
    R = cfg.qieo.ranges;
    g = @(k) binGene(bits, k, B);           % normalized value in [0,1]
    hp.filters = round(R.filters(1) + g(1)*diff(R.filters));
    hp.kernel  = round(R.kernel(1)  + g(2)*diff(R.kernel));
    hp.hidden  = round(R.hidden(1)  + g(3)*diff(R.hidden));
    logLR      =        R.logLR(1)  + g(4)*diff(R.logLR);
    hp.lr      = 10^logLR;
    hp.dropout =        R.dropout(1)+ g(5)*diff(R.dropout);
    hp.filters = max(hp.filters,4);
    hp.kernel  = max(hp.kernel,2);
    hp.hidden  = max(hp.hidden,8);
end

function v = binGene(bits, geneIdx, B)
%BINGENE Decode one gene block to a value in [0,1].
    seg = bits((geneIdx-1)*B + (1:B));
    d = sum(seg .* 2.^(B-1:-1:0));
    v = d / (2^B - 1);
end

% ------------------------------------------------------------------------
function dS = subsampleData(data, cfg)
%SUBSAMPLEDATA Evenly spaced subset of windows for fast fitness evaluation.
    nTr = numel(data.XTrain); nVa = numel(data.XVal);
    kTr = min(cfg.searchTrainN, nTr);
    kVa = min(cfg.searchValN,   nVa);
    iTr = round(linspace(1, nTr, kTr));
    iVa = round(linspace(1, nVa, kVa));
    dS = data;
    dS.XTrain = data.XTrain(iTr); dS.YTrain = data.YTrain(iTr);
    dS.XVal   = data.XVal(iVa);   dS.YVal   = data.YVal(iVa);
    fprintf('  Search subset: train=%d val=%d\n', kTr, kVa);
end

% ------------------------------------------------------------------------
function fit = evalFitness(data, cfg, hp, tau)
%EVALFITNESS Train briefly and return validation pinball loss (Eq.22).
    try
        net = trainQuantileNet(data, cfg, hp, cfg.maxEpochsSearch);
        Yq  = predictQuantiles(net, data.XVal);
        Yq  = sort(Yq,1);
        yv  = data.YVal(:).';
        e   = yv - Yq;
        fit = mean(max(tau.*e,(tau-1).*e),"all");
    catch ME
        warning("Fitness eval failed: %s", ME.message);
        fit = 1e6;             % penalize invalid configurations
    end
end
