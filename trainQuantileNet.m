function [net, mu, sg] = trainQuantileNet(data, cfg, hp, maxEpochs)
%TRAINQUANTILENET Build and train the CNN-BiLSTM quantile network.
%   hp fields: filters, kernel, hidden, lr, dropout
%   Uses trainnet with a custom multi-quantile pinball loss (R2024b).
%
%   The predictor sequences must reach the input layer as channels-by-time
%   (CT). To be robust to how the toolchain resolves the data format, the
%   function first tries the sequences as stored, and if a channel-size
%   error occurs it transposes every sequence and retrains.

    Q = numel(cfg.quantiles);
    nFeat = data.nFeat;
    mu = data.mu; sg = data.sg;

    % Architecture variant for the ablation study. Default is CNN-BiLSTM.
    if ~isfield(hp,'arch') || isempty(hp.arch); hp.arch = 'cnn_bilstm'; end
    layers = buildLayers(hp, nFeat, Q);

    % Targets replicated across the Q output channels so the network output
    % [Q x N] and the target [Q x N] share the same shape. trainnet takes
    % responses as rows: [numObs x Q].
    YTr = repmat(data.YTrain(:), 1, Q);               % [Ntr x Q]
    YVa = repmat(data.YVal(:),   1, Q);               % [Nval x Q]

    tau = cfg.quantiles(:);                            % [Q x 1]
    lossFcn = @(Ypred,Ttrue) pinballLoss(Ypred,Ttrue,tau);

    XTr = data.XTrain; XVa = data.XVal;

    net = trainOnce(XTr, YTr, XVa, YVa);
    return;

    % ---- nested helper (captures layers/lossFcn/cfg) -------------------
    function net = trainOnce(XTr, YTr, XVa, YVa)
        opts = trainingOptions("adam", ...
            "MaxEpochs",maxEpochs, ...
            "InitialLearnRate",hp.lr, ...
            "MiniBatchSize",cfg.miniBatch, ...
            "Shuffle","every-epoch", ...
            "ValidationData",{XVa, YVa}, ...
            "ValidationFrequency",50, ...
            "ValidationPatience",5, ...
            "OutputNetwork","best-validation", ...
            "GradientThreshold",1, ...
            "Verbose",false, ...
            "Plots","none");
        net0 = dlnetwork(layers);
        try
            net = trainnet(XTr, YTr, net0, lossFcn, opts);
        catch ME
            if channelError(ME)
                % Flip sequence orientation and retry once.
                XTr = cellfun(@transpose, XTr, "UniformOutput", false);
                XVa = cellfun(@transpose, XVa, "UniformOutput", false);
                opts = trainingOptions("adam", ...
                    "MaxEpochs",maxEpochs, ...
                    "InitialLearnRate",hp.lr, ...
                    "MiniBatchSize",cfg.miniBatch, ...
                    "Shuffle","every-epoch", ...
                    "ValidationData",{XVa, YVa}, ...
                    "ValidationFrequency",50, ...
                    "GradientThreshold",1, ...
                    "Verbose",false, ...
                    "Plots","none");
                net0 = dlnetwork(layers);
                net = trainnet(XTr, YTr, net0, lossFcn, opts);
            else
                rethrow(ME);
            end
        end
    end
end

function tf = channelError(ME)
    m = lower(ME.message);
    tf = contains(m,"channel") || contains(m,"invalid input") || ...
         contains(m,"invalid size");
end

function layers = buildLayers(hp, nFeat, Q)
%BUILDLAYERS Architecture variants for the ablation study.
    inL  = sequenceInputLayer(nFeat,"Name","in");
    convBlock = [
        convolution1dLayer(hp.kernel, hp.filters,"Padding","causal","Name","conv1d")
        reluLayer("Name","relu")
        layerNormalizationLayer("Name","ln")];
    dropL = dropoutLayer(hp.dropout,"Name","drop");
    fcL   = fullyConnectedLayer(Q,"Name","fc");
    switch lower(hp.arch)
        case 'cnn_bilstm'      % full proposed model
            layers = [inL; convBlock; ...
                bilstmLayer(hp.hidden,"OutputMode","last","Name","rnn"); dropL; fcL];
        case 'bilstm'          % no convolution
            layers = [inL; ...
                bilstmLayer(hp.hidden,"OutputMode","last","Name","rnn"); dropL; fcL];
        case 'cnn_lstm'        % unidirectional LSTM
            layers = [inL; convBlock; ...
                lstmLayer(hp.hidden,"OutputMode","last","Name","rnn"); dropL; fcL];
        case 'lstm'            % plain LSTM
            layers = [inL; ...
                lstmLayer(hp.hidden,"OutputMode","last","Name","rnn"); dropL; fcL];
        case 'cnn'             % convolution only, pooled to a vector
            layers = [inL; convBlock; ...
                globalAveragePooling1dLayer("Name","gap"); dropL; fcL];
        otherwise
            error("Unknown arch: %s", hp.arch);
    end
end
