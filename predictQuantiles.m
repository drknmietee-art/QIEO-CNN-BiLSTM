function Yq = predictQuantiles(net, Xcell)
%PREDICTQUANTILES Return quantile forecasts [Q x N] for a cell of sequences.
%   Robust to sequence orientation: if a channel-size error occurs, the
%   sequences are transposed and prediction is retried.
    N = numel(Xcell);
    try
        Yout = minibatchpredict(net, Xcell, "MiniBatchSize",256);
    catch ME
        m = lower(ME.message);
        if contains(m,"channel") || contains(m,"invalid input") || ...
           contains(m,"invalid size")
            Xcell = cellfun(@transpose, Xcell, "UniformOutput", false);
            Yout = minibatchpredict(net, Xcell, "MiniBatchSize",256);
        else
            rethrow(ME);
        end
    end
    % minibatchpredict returns [N x Q]; transpose to [Q x N].
    if size(Yout,1) == N
        Yq = Yout.';
    else
        Yq = Yout;
    end
end
