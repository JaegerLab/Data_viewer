function gait = gait_analysis(filename, frame_rate, body_thres, paw_thres)


% filename='E:\Openfield\Basler_acA1920-155umMED__40118562__20230901_130800493_modDLC_resnet50_OpenfieldNov21shuffle1_800000.csv';
if ischar(filename)
    data=DLC.read_dlc(filename);
    gait.filename = filename;
elseif istable(filename)
    data=filename;
    gait.filename = filename.Properties.Description;
else 
    error('input error');
end

% get frame rate from bpod

gait.frame_rate = frame_rate;


% convert length from pixel to cm: length_in_pixel * length_convert_factor = cm
% video: 1200 * 1200 pixels, open field box: 40 * 40 cm^2
gait.length_convert_factor = 40/1200; % 40cm/1200px 

% convert speed from pixel/frame to cm/s: speed * speed_convert_factor
% 1200 pixel/1 frame = 40 cm/(1/fs) s = 40*fs cm/s
% 1 pixel/frame = (fs*40/1200) cm/s = (fs*length_convert_factor) cm/s
gait.speed_convert_factor = gait.frame_rate/30; 

% internally use pixel/frame, output is cm/s
gait.bodythres = body_thres;  % threshold should be irrelevant of frame rate
gait.pawthres = paw_thres;
% convert cm/s to pixel/frame, threshold's lower when frame rate's higher
bodythres = gait.bodythres/gait.speed_convert_factor;
pawthres = gait.pawthres/gait.speed_convert_factor;

MinTimeInterval = 5;
MaxTimeInterval = 30;
MaxStepLength = 250;
MaxSpeedLimit = 5;


gait.frameNum = height(data);
gait.t = (0:gait.frameNum-1)'./gait.frame_rate; % convert frame to second

spaceFiller = zeros(gait.frameNum,1);
pawNames = {'L_forepaw','R_forepaw','L_hindpaw','R_hindpaw'};
gait.pawNames = pawNames;
template = struct('name', '', ...
                  'x', spaceFiller, ...
                  'y', spaceFiller, ...
                  'speed', spaceFiller, ...
                  'pawUp', spaceFiller, ...
                  'pawDown', spaceFiller, ...
                  'peak', spaceFiller, ...
                  'maxspeed', spaceFiller, ...
                  'valley', spaceFiller, ...
                  'interval', spaceFiller, ...
                  'stride', spaceFiller, ...
                  'swing', spaceFiller, ...
                  'stance', spaceFiller, ...
                  'swingPercent', spaceFiller ...
                 );
gait.paw = repmat(template, 4, 1);

gait.body.name = 'body_midpoint';

gait.body.x = data.([gait.body.name, '_x']);
gait.body.y = data.([gait.body.name, '_y']);
              
n=round(0.125*frame_rate); 
% detection span for body speed, compare frame x with x+n 

% body speed
body_speed=GAIT.smooth_speed(gait.body.x, gait.body.y, n);
body_speed = body_speed(:); % make sure vertical array;
gait.body.speed = body_speed.*gait.speed_convert_factor;



%% read 4 paw x and y
for ii = 1:4
    gait.paw(ii).name = pawNames{ii};
    % % [x,y] = DLC_fix(data.([pawNames{ii} '_x']), ...
    %                 data.([pawNames{ii} '_y']), ...
    %                 data.([pawNames{ii} '_likelihood']) , ...
    %                 40, 1);
    x = data.([pawNames{ii} '_x']);
    y = data.([pawNames{ii} '_y']);
    gait.paw(ii).x = x;
    gait.paw(ii).y = y;

    speed = GAIT.smooth_speed(x, y, 1);
    speed(speed > 80) = NaN;
    gait.paw(ii).speed = speed * gait.speed_convert_factor;

    % paw up and paw down
    pawup = find(speed(1:end-1)<=pawthres & speed(2:end)>pawthres);
    pawdown = find(speed(1:end-1)>pawthres & speed(2:end)<=pawthres)+1;
    pawup(body_speed(pawup)<bodythres)=NaN;
    pawdown(body_speed(pawdown)<bodythres)=NaN;

    % line up pawup, pawdown, noMove, sort them. then diff.
    % the reason need to insert noMove in there is to break up the
    % non-continuous pawups and pawdowns.
    noMove = find(body_speed < bodythres) ;
    pawlineup = [pawup(:), ones(length(pawup),1); ...
                pawdown(:), ones(length(pawdown),1).*2; ...
                noMove(:), NaN(length(noMove),1)];
    pawlineup = sortrows(pawlineup, 1);
    pawinterval = diff(pawlineup);
    swing_idx = pawinterval(:,2)==1 & ~isnan(pawinterval(:,1));
    stance_idx = pawinterval(:,2)==-1 & ~isnan(pawinterval(:,1));

    % swing & stance: duration, from, to
    swing = table(pawinterval(swing_idx,1), ...
                  pawlineup(swing_idx,1), ...
                  pawlineup([false; swing_idx],1), ...
                  'VariableNames',{'duration','from','to'});
    swing(swing.duration==0,:)=[];
    stance = table(pawinterval(stance_idx,1), ...
                  pawlineup(stance_idx,1), ...
                  pawlineup([false; stance_idx],1), ...
                  'VariableNames',{'duration','from','to'});
    stance(stance.duration==0,:)=[];
    swing_percent = mean(swing.duration) / (mean(swing.duration) + mean(stance.duration));

    gait.paw(ii).pawUp = pawup(~isnan(pawup));
    gait.paw(ii).pawDown = pawdown(~isnan(pawdown));
    gait.paw(ii).swing = swing;
    gait.paw(ii).stance = stance;
    gait.paw(ii).swingPercent = swing_percent;

    % peak and maxspeed
    [maxspeed,peak] = findpeaks(speed, "MinPeakProminence", pawthres, "MinPeakDistance", MinTimeInterval); 
    maxspeed(body_speed(peak)<=bodythres)=NaN;
    peak(body_speed(peak)<=bodythres)=NaN;
    
    gait.paw(ii).peak = peak./gait.frame_rate;
    gait.paw(ii).maxspeed = maxspeed.*gait.speed_convert_factor;

    % interval
    timeInterval=diff(pawup);
    timeInterval(timeInterval > MaxTimeInterval)=[];

    gait.paw(ii).interval = timeInterval./gait.frame_rate;

    % valley
    [~,valley] = findpeaks(70-speed, 'MinPeakProminence', pawthres, "MinPeakDistance", MinTimeInterval); 
    valley(speed(valley)>MaxSpeedLimit | body_speed(valley)<=bodythres)=NaN;
    gait.paw(ii).valley = valley./gait.frame_rate;

    % stride length
    stride=sqrt(diff(shared.nan_index(x,valley)).^2+diff(shared.nan_index(y,valley)).^2);
    stride(stride>MaxStepLength)=[];
    gait.paw(ii).stride = stride.*gait.length_convert_factor;

end
    % swing / stance

% 
% 
% %% stride frequency
% 
% %% stride length
% 
% MaxStepLength = 250;
% MaxSpeedLimit = 5;
% [~,L_pawdown] = findpeaks(70-L_speed, 'MinPeakProminence', pawthres, "MinPeakDistance", MinTimeInterval); 
% 
% if isempty(L_pawdown)
%     noMove;
% end
% L_pawdown( L_speed(L_pawdown)>MaxSpeedLimit)=[];
% L_pawdown(body_speed(L_pawdown)<=bodythres)=NaN;
% 
% L_stride=sqrt(diff(nan_index(Lx,L_pawdown)).^2+diff(nan_index(Ly,L_pawdown)).^2);
% % step_start = find(isnan(L_stride(1:end-1)) & ~isnan(L_stride(2:end)));
% % L_stride(step_start+1) = NaN;
% % L_stride(L_stride > MaxStepLength)=[];
% % [n,x]=hist(L_stride,50);
% % [~,idx]=max(n);
% % Ls=x(idx);
% 
% [~,R_pawdown] = findpeaks(70-R_speed, 'MinPeakProminence', pawthres, "MinPeakDistance", MinTimeInterval);
% 
% if isempty(R_pawdown)
%     noMove;
% end
% R_pawdown( R_speed(R_pawdown)>MaxSpeedLimit)=[];
% R_pawdown(body_speed(R_pawdown)<=bodythres)=NaN;
% 
% R_stride=sqrt(diff(nan_index(Rx,R_pawdown)).^2+diff(nan_index(Ry,R_pawdown)).^2);
% % step_start = find(isnan(R_stride(1:end-1)) & ~isnan(R_stride(2:end)));
% % R_stride(step_start+1) = NaN;
% % R_stride(R_stride > MaxStepLength)=[];
% % [n,x]=hist(R_stride,50);
% % [~,idx]=max(n);
% % Rs=x(idx);
% 
% gait.stride{1} = L_stride./30;
% gait.stride{2} = R_stride./30;
% gait.stride_median = [nanmedian(L_stride), nanmedian(R_stride)]./30;
% gait.stride_cv = [nanstd(L_stride./30), nanstd(R_stride./30)];
% 
% gait.step{1} = L_pawdown./40;
% gait.step{2} = R_pawdown./40;
% 
% %% phase 
% % find the starting and ending point
% startThres = 4;
% L_start = find(L_speed(2:end)>= startThres & L_speed(1:end-1)<startThres);
% % L_stop = find(L_speed(1:end-1)>= startThres & L_speed(2:end)<startThres)+1;
% L_start(body_speed(L_start)<=bodythres)=NaN;
% 
% R_start = find(R_speed(2:end)>= startThres & R_speed(1:end-1)<startThres);
% % R_stop = find(R_speed(1:end-1)>= startThres & R_speed(2:end)<startThres)+1;
% R_start(body_speed(R_start)<=bodythres)=NaN;
% 
% LF_start = find(LF_speed(2:end)>= startThres & LF_speed(1:end-1)<startThres);
% % LF_stop = find(LF_speed(1:end-1)>= startThres & LF_speed(2:end)<startThres)+1;
% LF_start(body_speed(LF_start)<=bodythres)=NaN;
% 
% RF_start = find(RF_speed(2:end)>= startThres & RF_speed(1:end-1)<startThres);
% % RF_stop = find(RF_speed(1:end-1)>= startThres & RF_speed(2:end)<startThres)+1;
% RF_start(body_speed(RF_start)<=bodythres)=NaN;
% 
% gait.start = {L_start, R_start, LF_start, RF_start};
% 
% % L_dspeed = diff(L_speed);
% % [~, L_start] = findpeaks(L_dspeed, 'MinPeakProminence', startThres, "MinPeakDistance", MinTimeInterval);
% % [~, L_stop] = findpeaks(-L_dspeed, 'MinPeakProminence', startThres, "MinPeakDistance", MinTimeInterval);
% % L_stop=L_stop+1;
% % 
% % R_dspeed = diff(R_speed);
% % [~, R_start] = findpeaks(R_dspeed, 'MinPeakProminence', startThres, "MinPeakDistance", MinTimeInterval);
% % [~, R_stop] = findpeaks(-R_dspeed, 'MinPeakProminence', startThres, "MinPeakDistance", MinTimeInterval);
% % R_stop=R_stop+1;
% 
% % %% phase
% % % combine the L and R stops and label them with 1 and 2
% % starts = [L_start(:), ones(length(L_start),1)*1; ...
% %           R_start(:), ones(length(R_start),1)*2];
% % % sort rows based on points
% % starts = sortrows(starts);
% % % NaN out the points when body speed isn't above threshold.
% % starts(Msp(starts)<=bodythres,1)=NaN;
% % % remove the points where left and right are not alternating
% % starts(diff(starts(:,2))==0,1)=NaN;
% % % calculate phase
% % ph = [NaN; diff(starts(:,1))] ./ [NaN; starts(3:end,1) - starts(1:end-2,1); NaN];
% % L_ph = ph(starts(:,2)==1);
% % R_ph = ph(starts(:,2)==2);
% 
% %% find the phase between the neighboring
% Lph = NaN(size(L_start));
% for ii=1:length(L_start)
%     R_before = find(R_start < L_start(ii),1,'last');
%     if ~isempty(R_before)
%         R_before = R_start(R_before);
%     else
%         R_before = NaN;
%     end
%     R_after = find(R_start > L_start(ii),1,'first');
%     if ~isempty(R_after)
%         R_after = R_start(R_after);
%     else
%         R_after = NaN;
%     end
%     R_dur = R_after - R_before;
%     if ~isnan(R_dur) && R_dur > MinTimeInterval && R_dur < MaxTimeInterval
%         Lph(ii) = (L_start(ii) - R_before)/R_dur;
%     end
% end
% LFph = NaN(size(LF_start));
% for ii=1:length(LF_start)
%     R_before = find(R_start < LF_start(ii),1,'last');
%     if ~isempty(R_before)
%         R_before = R_start(R_before);
%     else
%         R_before = NaN;
%     end
%     R_after = find(R_start > LF_start(ii),1,'first');
%     if ~isempty(R_after)
%         R_after = R_start(R_after);
%     else
%         R_after = NaN;
%     end
%     R_dur = R_after - R_before;
%     if ~isnan(R_dur) && R_dur > MinTimeInterval && R_dur < MaxTimeInterval
%         LFph(ii) = (LF_start(ii) - R_before)/R_dur;
%     end
% end
% RFph = NaN(size(RF_start));
% for ii=1:length(RF_start)
%     L_before = find(L_start < RF_start(ii),1,'last');
%     if ~isempty(L_before)
%         L_before = L_start(L_before);
%     else
%         L_before = NaN;
%     end
%     L_after = find(L_start > RF_start(ii),1,'first');
%     if ~isempty(L_after)
%         L_after = L_start(L_after);
%     else
%         L_after = NaN;
%     end
%     L_dur = L_after - L_before;
%     if ~isnan(L_dur) && L_dur > MinTimeInterval && L_dur < MaxTimeInterval
%         RFph(ii) = (RF_start(ii) - L_before)/L_dur;
%     end
% end
% Rph = NaN(size(R_start));
% for ii=1:length(R_start)
%     L_before = find(L_start < R_start(ii),1,'last');
%     if ~isempty(L_before)
%         L_before = L_start(L_before);
%     else
%         L_before = NaN;
%     end
%     L_after = find(L_start > R_start(ii),1,'first');
%     if ~isempty(L_after)
%         L_after = L_start(L_after);
%     else
%         L_after = NaN;
%     end
%     L_dur = L_after - L_before;
%     if ~isnan(L_dur) && L_dur > MinTimeInterval && L_dur < MaxTimeInterval
%         Rph(ii) = (R_start(ii) - L_before)/L_dur;
%     end
% end
% gait.phase{1}=LFph;
% gait.phase{2}=RFph;
% gait.phase{3}=Lph;
% gait.phase{4}=Rph;

