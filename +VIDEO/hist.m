function md = hist(result, fieldname)

nums_of_results = length(result); % how many days
colors = {'b','r'};
md = zeros(nums_of_results,1);

cla; hold on;
for m=1:2 % left and right
    LR = sign(m-1.5); % left or right

    for k=1:nums_of_results % loop through dates
        % calculate age in weeks
        age = result(k).age_day/7;

        % remove outlier
        no_outlier = result(k).gait.(fieldname){m};
        no_outlier = no_outlier(~isoutlier(no_outlier));
        if ~isempty(no_outlier)
            % plot histogram
            % [f, xi] = ksdensity(no_outlier);
            [f, xi] = hist(no_outlier, 15);
            x = [age + LR * f./max(f)/2, age, age]; 
            y = [xi, xi(end), xi(1)];
    
            p = polyshape(x,y);
            plot(p, 'EdgeColor', colors{m}, 'FaceColor', colors{m});
    
            % get percent tiles
            P = prctile(no_outlier,[10 25 50 75 90]);
            % plot 5 lines of percent tiles
            [y,x]=meshgrid(P, age+[0;0.4*LR]);
            plot(x,y, colors{m})
            md(k) = P(3);
        end
    end
    
    % plot the median line between animals
    plot([result.age_week] + LR*0.2, md, colors{m});
end
xlabel('age (week)')
ylabel(fieldname)
title([result(1).ID ', ' result(1).MP{1}]);