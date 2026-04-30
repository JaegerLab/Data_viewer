function [jump_idx, details] = dlc_detect_jumps(x, y, params)
% DLC_DETECT_JUMPS Detect trajectory discontinuities using bidirectional
% linear-consistency residuals, fully vectorized.
%
%   [jump_idx, score, details] = dlc_detect_jumps(x, y)
%   [jump_idx, score, details] = dlc_detect_jumps(x, y, params)
%
% Inputs
%   x, y   : numeric vectors of equal length
%   params : struct with optional fields
%       .method   : 'thresh' or 'predict'
%       .nFrame   : number of past/future frames used for local linear
%                   prediction (default = 2)
%       .tau      : threshold on bidirectional residual score
%                   (default = 20)
%
% Outputs
%   jump_idx : indices where score > tau
%   score    : bidirectional consistency score, Nx1
%   details  : struct with diagnostics
%       .resFwd   : forward residual
%       .resBwd   : backward residual
%       .predFwdX : forward-predicted x
%       .predFwdY : forward-predicted y
%       .predBwdX : backward-predicted x
%       .predBwdY : backward-predicted y
%       .valid    : logical mask of frames with valid forward and backward
%                   predictions
%       .wFwd     : forward linear-prediction weights
%       .wBwd     : backward linear-prediction weights
%       .params   : params actually used
%
% Notes
%   For each frame t, forward prediction fits a line to frames:
%       t-nFrame, ..., t-1
%   and predicts the current frame t.
%
%   Backward prediction fits a line to frames:
%       t+1, ..., t+nFrame
%   and predicts the current frame t.
%
%   The least-squares prediction at the current frame is a fixed linear
%   combination of the neighboring samples, so the whole computation can
%   be written as FIR filtering with precomputed weights.
%
% Example
%   [jump_idx, score, details] = dlc_detect_jumps(x, y);
%
%   p = struct('nFrame', 3, 'tau', 25);
%   [jump_idx, score, details] = dlc_detect_jumps(x, y, p);

    if nargin < 3 || isempty(params)
        params = struct();
    end

    if ~isfield(params, 'nFrame') || isempty(params.nFrame)
        params.nFrame = 2;
    end
    if ~isfield(params, 'tau') || isempty(params.tau)
        params.tau = 20;
    end

    nFrame = params.nFrame;
    tau    = params.tau;

    validateattributes(x, {'numeric'}, {'vector','real','finite'}, mfilename, 'x', 1);
    validateattributes(y, {'numeric'}, {'vector','real','finite'}, mfilename, 'y', 2);
    validateattributes(nFrame, {'numeric'}, {'scalar','integer','positive'}, mfilename, 'params.nFrame');
    validateattributes(tau, {'numeric'}, {'scalar','real','finite','nonnegative'}, mfilename, 'params.tau');

    x = x(:);
    y = y(:);

    if numel(x) ~= numel(y)
        error('x and y must have the same length.');
    end

    N = numel(x);
    if N < 2*nFrame + 1
        error('Trajectory too short. Need at least 2*nFrame + 1 samples.');
    end

    % ---------------------------------------------------------------------
    % Precompute least-squares linear-prediction weights
    % ---------------------------------------------------------------------
    %
    % For forward prediction, use past frames at times:
    %   -nFrame, ..., -1
    % and predict at time 0.
    %
    % For backward prediction, use future frames at times:
    %   +1, ..., +nFrame
    % and predict at time 0.
    %
    % Since the design matrix is fixed, the prediction is:
    %   xhat = w * window
    % with constant weights w.
    % ---------------------------------------------------------------------

    tf = (-nFrame:-1).';
    Xf = [tf, ones(nFrame,1)];
    wFwd = ([0, 1] / (Xf' * Xf)) * Xf';   % 1 x nFrame

    tb = (1:nFrame).';
    Xb = [tb, ones(nFrame,1)];
    wBwd = ([0, 1] / (Xb' * Xb)) * Xb';   % 1 x nFrame

    % ---------------------------------------------------------------------
    % Vectorized forward prediction
    %
    % filter(w,1,x) computes:
    %   y(t) = w(1)*x(t) + w(2)*x(t-1) + ...
    %
    % We want:
    %   xhat_f(t) = wFwd(1)*x(t-nFrame) + ... + wFwd(end)*x(t-1)
    %
    % Therefore pad the coefficient vector with a trailing zero:
    %   bF = [0, wFwd(end:-1:1)]
    %
    % Then:
    %   filter(bF,1,x)(t) = wFwd(1)*x(t-nFrame)+...+wFwd(end)*x(t-1)
    % ---------------------------------------------------------------------

    bF = [0, fliplr(wFwd)];
    predFwdX = filter(bF, 1, x);
    predFwdY = filter(bF, 1, y);

    % ---------------------------------------------------------------------
    % Vectorized backward prediction
    %
    % Desired:
    %   xhat_b(t) = wBwd(1)*x(t+1) + ... + wBwd(end)*x(t+nFrame)
    %
    % Compute this by reversing the signal, doing the same kind of causal
    % filtering, then reversing back.
    % ---------------------------------------------------------------------

    bB = [0, fliplr(wBwd)];
    xr = flipud(x);
    yr = flipud(y);

    predBwdX = flipud(filter(bB, 1, xr));
    predBwdY = flipud(filter(bB, 1, yr));

    % ---------------------------------------------------------------------
    % Valid mask
    % Forward predictor valid for t = nFrame+1 : N
    % Backward predictor valid for t = 1 : N-nFrame
    % Combined valid region:
    %   t = nFrame+1 : N-nFrame
    % ---------------------------------------------------------------------

    valid = false(N,1);
    valid((nFrame+1):(N-nFrame)) = true;

    % Mark invalid predictions explicitly as NaN for cleaner downstream use
    predFwdX(~valid) = NaN;
    predFwdY(~valid) = NaN;
    predBwdX(~valid) = NaN;
    predBwdY(~valid) = NaN;

    % Residuals and score
    resFwd = hypot(x - predFwdX, y - predFwdY);
    resBwd = hypot(x - predBwdX, y - predBwdY);

    % next fwd > Threshold and this bwd > threshold;
    jump_mask = valid & (resBwd > tau) & (circshift(resFwd, -1) > tau);
    jump_idx  = find(jump_mask);

    % Diagnostics
    details = struct();
    details.resFwd   = resFwd;
    details.resBwd   = resBwd;
    details.predFwdX = predFwdX;
    details.predFwdY = predFwdY;
    details.predBwdX = predBwdX;
    details.predBwdY = predBwdY;
    details.valid    = valid;
    details.wFwd     = wFwd;
    details.wBwd     = wBwd;
    details.params   = params;
end