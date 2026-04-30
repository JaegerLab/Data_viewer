function [x_fix, y_fix, p_fix, all_flags] = dlc_fix_alt(x, y, p, params)
% 
% 
%

%% input validation ============================
x = x(:);
y = y(:);
data_length = numel(x);

if numel(y) ~= data_length
    error('x and y must have the same length.');
end

if ~isfield(params, 'jump_thresh') || isempty(params.jump_thresh)
    jump_thresh = 20;
else
    jump_thresh = params.jump_thresh;
end
if ~isfield(params, 'win_width') || isempty(params.win_width)
    win_width = 30;
else
    win_width = params.win_width;
end


%% === algorithm starts =======================
if ~isfield(params, 'section') || isempty(params.section)
    % without passing section in parameter

    % find edge index before the jump
    edges = find(hypot(diff(x),diff(y)) > jump_thresh);
    
    % divice data trace into sections, based on edges
    n_section = length(edges)+1;
    section = array2table(zeros(n_section, 4), ...
        VariableNames={'start', 'end', 'length', 'flag'});
    section.start = [1; edges+1];
    section.end = [edges; data_length];
    section.length = section.end - section.start + 1;
    
    % flag matrix, based on neighboring sections, 
    % assuming good sections and bad sections are alternating.
    % flags: 0=unflagged, 1=good, 2=bad, 3=questionable
    % If neighbors are (0,0), current section = 1 (good)
    % If neighbors are (1,0) or (0,1) or (1,1), current section = 2 (bad)
    % If neighbors are (2,0) or (0,2) or (2,2), current section = 1 (good)
    % If neighbors are (1,2) or (2,1), current section = 3 (questionable)
    % pseudocode: current_flag = flag_matrix(left_flag+1, right_flag+1)
    flag_matrix = [1 2 1; ...
                   2 2 3; ...
                   1 3 1;];
    
    % Sections longer than win_width are good, work as starting seeds
    section.flag(section.length >= win_width) = 1;
    
    % Start from the flagged ones, only flag the neighboring sections.
    % Propagate until all sections are flagged
    while any(section.flag == 0)
        left_flag = [0; section.flag(1:end-1)];
        right_flag = [section.flag(2:end); 0];
        % only select the unflagged ones adjacent to the flagged ones
        select = (section.flag == 0 & left_flag+right_flag > 0);
        % transform (left_flag+1, right_flag+1) into indices for the flag_matrix
        idx = sub2ind(size(flag_matrix), left_flag(select)+1, right_flag(select)+1);
        section.flag(select) = flag_matrix(idx);
    end
else
    section = params.section;
    n_section = height(section);
end

% Generate a continuous flag vector and good index mask
all_flags = zeros(data_length,1);
for k=1:n_section
    all_flags(section.start(k):section.end(k))=section.flag(k);
end
good = (all_flags == 1);

%% fix x and y based on pchip interpolation ============
index = (1:data_length)'; % index for x and y
x_fix = interp1(index(good), x(good), index, 'pchip', 'extrap');
y_fix = interp1(index(good), y(good), index, 'pchip', 'extrap');
p_fix = p; p_fix(~good) = 1;
