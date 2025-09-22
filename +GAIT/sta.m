function [sta, x, info] = sta(emg, emg_t, event_time, varargin)

% GAIT.sta: Spike-triggered Averaging
% 
%  [sta, x] = GAIT.sta(emg, emg_t, event_time, max_lag, plotit)
% 
%  emg: EMG.
%  emg_t: the t axis of EMG, unit in Second
%  event_time  : An array of each event time. in Seconds.
%  max_lag     : the result range is [-max_lag, max_lag] 
%                and the length is 2*max_lag+1. unit in S.
%  plotit      : 'plot' to plot the mean averaged over traces.
%                or specify an axes object to plot in.
%  gait        : provide gait structure to 
%  x   : x axis for the average.

% assign the arguments========================
narginchk(3,6)

for k=1:length(varargin)
    if ischar(varargin{k})
        plotit=varargin{k};
    elseif isnumeric(varargin{k})
        max_lag=varargin{k};
    elseif isa(varargin{k}, 'matlab.graphics.axis.Axes')
        plotit = varargin{k};
    elseif isstruct(varargin{k})
        gait = varargin{k};
    else
        error('Wrong argument')
    end
end
if ~exist('max_lag', 'var')
    max_lag=0.5;
    max_lag=min(max_lag, max(emg_t));
end
sample_rate = round(1/mean(diff(emg_t)));

% remove out of bound data
emg(emg_t<=0)=[];
emg_t(emg_t<=0)=[];
traceLength=length(emg);
event_time(isnan(event_time))=[];
event_index=round(event_time.*sample_rate);

if any(event_index>traceLength | event_index<=0)
    event_index(event_index>traceLength | event_index<=0)=[];
    warning('Event time out of bound');
end

% construct event train
eventNum = length(event_index);
event_train=zeros(traceLength,1);
event_train(event_index)=1/eventNum;

% calculate spike triggered average, using xcorr function
[sta, m_lags]=xcorr(emg, event_train,round(max_lag*sample_rate));
x = m_lags(:)./sample_rate;

info = struct();
% =============== random control ======================
random_method = 3;
k=3; % grey box of random sta: 2*std = 95% CI, 3*std = 99.7% CI
if random_method ==1
    % mean(emg) +- std(emg)/sqrt(eventNum)
    random_mean = mean(emg);
    random_std = std(emg);
elseif random_method == 2
    % mean +- std within moving periods
    if exist('gait','var')
        random_range = repelem(gait.body.speed>gait.bodythres, 1, 500);
    else
        random_range = 1:length(emg);
    end
    random_mean = mean(emg(random_range));
    random_std = std(emg(random_range));
elseif random_method ==3
    % === randomly shift real event time =======
    rep = 40;
    random_sta = zeros(2*max_lag*sample_rate+1, rep);
    % disp('randomized control repitition:')
    for kk=1:rep
        % add random shift
        random_index=event_index + round(0.3*sample_rate.*(rand(size(event_index))-0.5));
        random_index(random_index>traceLength | random_index<=0)=[];
        random_train=zeros(traceLength,1);
        random_train(random_index)=1/eventNum;
        [random_sta(:,kk), random_sta_x]=xcorr(emg, random_train, round(max_lag*sample_rate));
    end
    random_sta_t = random_sta_x(:)./sample_rate;
    random_mean = mean(random_sta, 2);
    random_std = std(random_sta, 0, 2);

end
info.random_sta_t = random_sta_t;
info.random_mean = random_mean;
info.random_std = random_std;

if exist('plotit','var')
    if isequal(plotit, 'plot')
        fig = figure();
        ax = axes(fig);
    elseif isa(plotit, 'matlab.graphics.axis.Axes')
        ax = axes(plotit);
    end
    
    % ============ sta result ======================
    plot(ax, x, sta, 'k');

    hold on;
    % random control
    if random_method == 3
        line1 = plot(random_sta_t, random_mean, 'k--');
        fill1 = fill([random_sta_t; flipud(random_sta_t)], ...
            [random_mean; flipud(random_mean)]+k.*[random_std; -flipud(random_std)], ...
            'k', 'EdgeColor', 'none', 'FaceAlpha', 0.15);
    else
        line1 = yline(random_mean, 'k--');
        fill1 = fill(max_lag*[-1 1 1 -1], ...
            random_mean+k*random_std/sqrt(eventNum)*[-1 -1 1 1], ...
        'k', 'EdgeColor', 'none', 'FaceAlpha', 0.15);
    end
    uistack(line1,"down")
    uistack(fill1,"bottom")

    % central vertical line
    xline(0,':k','HandleVisibility', 'off');

	% peak texts
    [max_sta,index_max_sta] = max(sta-random_mean);
	text(x(index_max_sta), max_sta+random_mean(index_max_sta), num2str(x(index_max_sta)), ...
        'VerticalAlignment','bottom','HorizontalAlignment','center')
    [min_sta,index_min_sta] = min(sta-random_mean);
    text(x(index_min_sta), min_sta+random_mean(index_min_sta), num2str(x(index_min_sta)), ...
        'VerticalAlignment','top','HorizontalAlignment','center')

    % figure title and axis labels
    xlabel('t (s)');
    percentage = {'68.3%','95.5%','99.7%'};
    legend({ [num2str(k) '*STD CI:' percentage{k}], 'random mean', 'STA'})

    % title([inputname(1) ', ' inputname(3)], 'Interpreter','none')

	hold off;
end
