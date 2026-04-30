function long_speed = traverse(x, y, t)

n = find(t>=1, 1); % find the first index at 1 second

% calculate long term speed after 1 second
long_speed = GAIT.smooth_speed(x, y, n);



