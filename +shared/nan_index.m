function output = nan_index(A, B)
    % Create output array and fill with NaN
    output = NaN(size(B));
    valid_indices = ~isnan(B);
    output(valid_indices) = A(B(valid_indices));
end