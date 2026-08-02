function loss = pinballLoss(Ypred, Ttrue, tau)
%PINBALLLOSS Multi-quantile pinball (quantile) loss. Eq. (13)-(14).
%   Ypred : [Q x N] dlarray, one row per quantile level
%   Ttrue : [Q x N] target power (each row is the same measured value)
%   tau   : [Q x 1] quantile levels
%
%   loss  = mean_{n,q} max( tau_q * e , (tau_q - 1) * e ),  e = y - yhat

    e = Ttrue - Ypred;                 % [Q x N]
    loss = max(tau.*e, (tau-1).*e);    % pinball per element (tau broadcasts)
    loss = mean(loss,"all");
end
