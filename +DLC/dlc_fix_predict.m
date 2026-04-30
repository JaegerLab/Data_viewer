function [x_fix, y_fix, mask] = dlc_fix_predict(x, y, jump_thresh, win_width, mask, visualize)
% Fix DLC mislabels based on prediction algorithm.
% Starting with good sections longer than win_width, only select the
% sections that are close to the interpolation as good. Repeat the
% propagate until all sections are flagged.
%
% Syntax:
% [x_fix, y_fix, mask] = ...
%       dlc_fix_predict(x, y, jump_thresh, win_width, mask)
%
% parameters:
% x,y: coordinates for the body part, vertical vector.
% p: optional, the likelihood.
% jump_thresh: threshold for jump detection, in pixel, default: 20
% win_width: threshold for continuous frames without jumps, default: 30
% mask: optional, boolean vector same size as x or y, good=true; bad=false.
%       if mask is provided, jump_thresh and win_width are ignored.

%% input validation ============================
x = x(:);
y = y(:);
data_length = numel(x);
index = (1:data_length)'; % index for x and y

if numel(y) ~= data_length
    error('x and y must have the same length.');
end

if ~exist('visualize', 'var')
    visualize = false;
end
if visualize
    figure; hold on; colors = {'go','rx','m^'};
    plot(index, [x,y], 'k-');
end

%%
if exist('mask', 'var')
    % mask is provided
    if numel(mask) ~= data_length
        error('mask must have the same length as data.');
    end
else
    % if no mask
    if ~exist('jump_thresh', 'var') || isempty(jump_thresh)
        jump_thresh = 20;
    end
    if ~exist('win_width', 'var') || isempty(win_width)
        win_width = 30;
    end
    
    %% === algorithm starts =======================
    
    % find edge index before the jump
    edges = find(hypot(diff(x),diff(y)) > jump_thresh);
    
    % divide data trace into sections, based on edges
    n_section = length(edges)+1;
    section = array2table(zeros(n_section, 4), ...
        VariableNames={'start', 'end', 'length', 'flag'});
    section.start = [1; edges+1];
    section.end = [edges; data_length];
    section.length = section.end - section.start + 1;
    
    % flags: 0=unflagged, 1=good, 2=bad, 3=questionable
    
    % Sections longer than win_width are good, work as starting seeds
    section.flag(section.length >= win_width) = 1;
    
    % Start from the flagged ones, only flag the neighboring sections.
    % Propagate until all sections are flagged
    growing = true;
    while any(section.flag == 0) || growing
        % if there're new good section, mark neighboring ones as bad.
        if growing
            left_flag = [0; section.flag(1:end-1)];
            right_flag = [section.flag(2:end); 0];
            % only select the unflagged ones adjacent to the good ones
            select = find((section.flag == 0 | section.flag == 3) ...
                        & (left_flag == 1 | right_flag == 1));
            % sections jump away from good ones must be bad.
            section.flag(select) = 2;
    
            if visualize
                for i=1:length(select)
                    k = select(i); % section number
                    range = section.start(k):section.end(k);
                    plot(index(range), [x(range), y(range)], colors{section.flag(k)});
                end
            end
        end
    
        % select the unflagged or questionable ones next to the flagged ones
        left_flag = [0; section.flag(1:end-1)];
        right_flag = [section.flag(2:end); 0];
        select = find((section.flag == 0 | section.flag == 3) ...
                    & (left_flag >= 2 | right_flag >= 2));
        if isempty(select)
            break;
        end
        
        if growing 
            % Generate a continuous flag vector and good index mask
            delta = zeros(data_length+1,1);
            delta(section.start) = section.flag;
            delta(section.end+1) = delta(section.end+1) - section.flag;
            all_flags = cumsum(delta);
            all_flags(end) = [];
            mask = (all_flags == 1);
        
            % Preliminary interpolation based on good sections
            x_fix = interp1(index(mask), x(mask), index, 'pchip', mean(x(mask)));
            y_fix = interp1(index(mask), y(mask), index, 'pchip', mean(y(mask)));
    
            if visualize
                if ~exist("hx", "var")
                    hx = plot(index, x_fix, 'c-');
                    hy = plot(index, y_fix, 'c-');
                    uistack(hx, "bottom");
                    uistack(hy, "bottom");
                else
                    set(hx, "YData", x_fix);
                    set(hy, "YData", y_fix);
                end
            end
        end
    
        % Check if selected sections are close enough to prelimiary fix
        growing = false;
        for i=1:length(select)
            k = select(i); % section number
            % only compare the beginning and/or the end next to flagged ones
            if left_flag(k) > 0 
                range = [section.start(k)];
            else
                range = [];
            end
            if right_flag(k) > 0 
                range = [range; section.end(k)];
            end
            err = mean(hypot(x(range)-x_fix(range), y(range)-y_fix(range)));
            old_flag = section.flag(k);
            if err < jump_thresh
                section.flag(k) = 1;
                % label shows there're new good sections
                growing = true; 
            else
                section.flag(k) = 3; % not necessarily bad, questionable
            end
    
            if visualize
                if section.flag(k) ~= old_flag
                    range = section.start(k):section.end(k);
                    plot(index(range), [x(range), y(range)], colors{section.flag(k)});
                end
            end
        end
        drawnow;
    end
    
    % Generate a continuous flag vector and good index mask
    delta = zeros(data_length+1,1);
    delta(section.start) = section.flag;
    delta(section.end+1) = delta(section.end+1) - section.flag;
    all_flags = cumsum(delta);
    all_flags(end) = [];
    mask = (all_flags == 1);
end

%% fix x and y based on pchip interpolation ============    
x_fix = interp1(index(mask), x(mask), index, 'pchip', mean(x(mask)));
y_fix = interp1(index(mask), y(mask), index, 'pchip', mean(y(mask)));
% No extrapolation, use mean value to replace missing edge values.

