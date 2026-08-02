function data = loadPVData(cfg)
%LOADPVDATA Load and preprocess the solar station dataset.
%   Reads the Excel file, cleans it, adds time features, normalizes, and
%   builds sliding-window sequences for a quantile forecaster.
%
%   Output struct fields:
%     XTrain/XVal/XTest : cell arrays, each cell [numFeatures x window]
%     YTrain/YVal/YTest : normalized target power (column vectors)
%     mu, sg            : normalization mean/std for each variable
%     featNames         : feature names

    T = readtable(cfg.dataFile, 'VariableNamingRule','preserve');

    % --- Identify columns by keyword (robust to header spacing) --------
    vn = string(T.Properties.VariableNames);
    getCol = @(k) T{:, find(contains(lower(vn), lower(k)),1)};

    time  = T{:,1};
    Gtot  = getCol('total solar');
    Gdni  = getCol('direct normal');
    Gghi  = getCol('global horizontal');
    Temp  = getCol('air temperature');
    Pres  = getCol('atmosphere');
    Hum   = getCol('relative humidity');
    Power = getCol('power');

    % --- Parse time and build minute-of-day cyclical features ---------
    if ~isdatetime(time)
        time = datetime(string(time),'InputFormat','yyyy-MM-dd HH:mm:ss');
    end
    mod = hour(time)*60 + minute(time);
    sinT = sin(2*pi*mod/1440);
    cosT = cos(2*pi*mod/1440);

    % --- Feature toggles (used by the ablation study) -----------------
    useT = ~isfield(cfg,'useTimeFeatures') || cfg.useTimeFeatures;   % default on
    useP =  isfield(cfg,'usePowerLag')     && cfg.usePowerLag;       % default off

    feats = [Gtot Gdni Gghi Temp Pres Hum];
    featNames = {'Gtot','Gdni','Gghi','Temp','Pres','Hum'};
    if useT
        feats = [feats sinT cosT];
        featNames = [featNames {'sinT','cosT'}];
    end
    if useP
        % Past power as a predictor. The window ends at time t and the
        % target is at t+h (h>=1), so this is not future leakage.
        feats = [feats Power];
        featNames = [featNames {'Plag'}];
    end
    raw = [feats Power];                        % last column is the target
    raw = fillmissing(raw,'linear');            % linear interpolation
    nFeat = numel(featNames);

    % --- Z-score normalization (store stats to invert power later) ----
    mu.all = mean(raw,1);  sg.all = std(raw,[],1); sg.all(sg.all==0)=1;
    norm = (raw - mu.all)./sg.all;
    mu.P = mu.all(end); sg.P = sg.all(end);

    X = norm(:,1:nFeat);      % predictors
    y = norm(:,end);          % normalized power target

    % --- Sliding windows ---------------------------------------------
    L = cfg.window; h = cfg.horizonSteps;
    N = size(X,1) - L - h + 1;
    Xc = cell(N,1); Yc = zeros(N,1);
    for i = 1:N
        win = X(i:i+L-1, :).';            % [nFeat x L]
        if size(win,1) ~= nFeat          % orientation guard -> channels first
            win = win.';
        end
        Xc{i} = win;                     % guaranteed [nFeat x L] (CT format)
        Yc(i) = y(i+L-1+h);              % target h steps ahead
    end
    fprintf('  Sequence cell size (channels x time): [%d x %d]\n', ...
        size(Xc{1},1), size(Xc{1},2));

    % --- Chronological split -----------------------------------------
    nTr = floor(cfg.trainFrac*N);
    nVa = floor(cfg.valFrac*N);
    idxTr = 1:nTr;
    idxVa = nTr+1:nTr+nVa;
    idxTe = nTr+nVa+1:N;

    data.XTrain = Xc(idxTr); data.YTrain = Yc(idxTr);
    data.XVal   = Xc(idxVa); data.YVal   = Yc(idxVa);
    data.XTest  = Xc(idxTe); data.YTest  = Yc(idxTe);
    data.mu = mu; data.sg = sg;
    data.featNames = featNames; data.nFeat = nFeat;

    fprintf('  Samples: train=%d val=%d test=%d (features=%d, window=%d)\n', ...
        numel(idxTr), numel(idxVa), numel(idxTe), nFeat, L);
end
