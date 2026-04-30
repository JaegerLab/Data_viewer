function [x_s, y_s] = kalman_smooth(x, y, badMask)

N = length(x);

% State vector: [x; y; vx; vy]
A = [1 0 1 0;
     0 1 0 1;
     0 0 1 0;
     0 0 0 1];

H = [1 0 0 0;
     0 1 0 0];

Q = 0.01 * eye(4);   % process noise
R = 5 * eye(2);      % measurement noise

% Initialize
x_est = zeros(4,N);
P = eye(4);

% Forward pass (Kalman filter)
for t = 1:N
    % Prediction
    x_pred = A * x_est(:,max(t-1,1));
    P_pred = A * P * A' + Q;

    if badMask(t)
        % No measurement update
        x_est(:,t) = x_pred;
        P = P_pred;
    else
        % Measurement update
        z = [x(t); y(t)];
        K = P_pred * H' / (H * P_pred * H' + R);
        x_est(:,t) = x_pred + K * (z - H * x_pred);
        P = (eye(4) - K * H) * P_pred;
    end
end

% Backward pass (RTS smoother)
x_smooth = x_est;
for t = N-1:-1:1
    P_pred = A * P * A' + Q;
    C = P * A' / P_pred;
    x_smooth(:,t) = x_est(:,t) + C * (x_smooth(:,t+1) - A * x_est(:,t));
end

x_s = x_smooth(1,:)';
y_s = x_smooth(2,:)';

end