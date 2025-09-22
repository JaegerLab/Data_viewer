function idx = find_index(t, t1)
% find the closest time of t1 in t, and return the index in t.

t1=t1(~isnan(t1));

idx = zeros(size(t1));
for k = 1:numel(t1)
    [~, idx(k)] = min(abs(t- t1(k)));
end