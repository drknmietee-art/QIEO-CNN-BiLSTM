function [bestHP, hist] = psoOptimize(data, cfg)
%PSOOPTIMIZE Particle swarm optimization of the forecaster hyperparameters.
%   Conventional optimizer used as the ablation baseline against QIEO.
%   Same search space, fitness, and budget as qieoOptimize for fairness.

    R = cfg.qieo.ranges;                 % reuse the same ranges
    D = 5;                               % genes: filters,kernel,hidden,logLR,dropout
    P = cfg.qieo.popSize;
    Gen = cfg.qieo.generations;
    tau = cfg.quantiles(:);

    w = 0.7; c1 = 1.5; c2 = 1.5;         % inertia and acceleration
    X = rand(P,D); V = zeros(P,D);       % positions in [0,1], velocities
    pbest = X; pbestFit = inf(P,1);
    gbest = X(1,:); gbestFit = inf;
    hist = zeros(Gen,1);

    for g = 1:Gen
        for p = 1:P
            hp = decodeHP(X(p,:), R);
            f  = fitness(data, cfg, hp, tau);
            if f < pbestFit(p); pbestFit(p) = f; pbest(p,:) = X(p,:); end
            if f < gbestFit;    gbestFit = f;    gbest = X(p,:);      end
        end
        % velocity and position update
        r1 = rand(P,D); r2 = rand(P,D);
        V = w*V + c1*r1.*(pbest - X) + c2*r2.*(gbest - X);
        X = min(max(X + V, 0), 1);
        hist(g) = gbestFit;
        bh = decodeHP(gbest, R);
        fprintf('  PSO Gen %2d/%2d bestFit=%.5f (filters=%d kernel=%d hidden=%d lr=%.1e drop=%.2f)\n', ...
            g, Gen, gbestFit, bh.filters, bh.kernel, bh.hidden, bh.lr, bh.dropout);
    end
    bestHP = decodeHP(gbest, R);
end

function hp = decodeHP(x, R)
    hp.filters = max(round(R.filters(1) + x(1)*diff(R.filters)),4);
    hp.kernel  = max(round(R.kernel(1)  + x(2)*diff(R.kernel)),2);
    hp.hidden  = max(round(R.hidden(1)  + x(3)*diff(R.hidden)),8);
    hp.lr      = 10^(R.logLR(1) + x(4)*diff(R.logLR));
    hp.dropout = R.dropout(1) + x(5)*diff(R.dropout);
    hp.arch    = 'cnn_bilstm';
end

function f = fitness(data, cfg, hp, tau)
    try
        net = trainQuantileNet(data, cfg, hp, cfg.maxEpochsSearch);
        Yq  = sort(predictQuantiles(net, data.XVal),1);
        yv  = data.YVal(:).'; e = yv - Yq;
        f = mean(max(tau.*e,(tau-1).*e),"all");
    catch ME
        warning("PSO fitness failed: %s", ME.message); f = 1e6;
    end
end
