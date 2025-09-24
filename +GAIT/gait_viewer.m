function fig = gait_viewer(default_path)

    data = shared.SessionData.instance();
    hd = struct;
    drawGUI(default_path)
    data.gait(1).hd = hd;
    
    function drawGUI(default_path)
    
        % gait viewer window with uigridlayout
        fig = uifigure('Name', 'Gait Viewer', 'Position', [100 100 1000 400], ...
            'CloseRequestFcn',@onClose);
        drawnow
        grid1 = uigridlayout(fig, Padding = [20,20,20,20], ...
            ColumnWidth = {'1x', 140}, RowHeight = {30, 30, '1x', 30});

        %% Row 1: Folder and open button
        hd.path = uieditfield(grid1, 'text'); 
        if nargin>=1
            hd.path.Value = default_path;
        end
        uibutton(grid1, 'Text', 'Import DLC', 'ButtonPushedFcn', @importPaws);
        
        %% Row 2: DLC processing
        subgrid1 = uigridlayout(grid1, [1 7], 'Padding', [0 0 0 0], ...
            'Layout', matlab.ui.layout.GridLayoutOptions('Row', 2, 'Column', 1));
        subgrid1.ColumnWidth = {'1x', 120,120,120,100,50};
        hd.frameRate = uieditfield(subgrid1,'numeric','Value',1, ...
            'ValueDisplayFormat','Frame rate: %.2f Hz');
        hd.lengthFactor = uieditfield(subgrid1,'numeric','Value',30, ...
            'ValueDisplayFormat','Resolution: %d px/cm');
        
        hd.bodythresh = uieditfield(subgrid1,'numeric','Value',5, ...
            'ValueDisplayFormat','Body thresh: %d cm/s', ...
            'ValueChangedFcn', @bodyThreshChanged);
        hd.pawthresh = uieditfield(subgrid1,'numeric','Value',10, ...
            'ValueDisplayFormat','Paw thresh: %d cm/s', ...
            'ValueChangedFcn', @pawThreshChanged);
        uibutton(subgrid1, 'Text', 'Gait Analysis', 'ButtonPushedFcn', @gaitAnalysis);
        % uibutton(subgrid1,'Text','STA');
        uilabel(subgrid1,'Text','Body:','HorizontalAlignment','Right');

        hd.body = uidropdown(grid1, 'ValueChangedFcn', @bodyChanged, ...
            'Enable','off');

        
        %% Row 3: DLC plot
        hd.ax = uiaxes(grid1); 
        hd.ax.XAxis.LimitsChangedFcn = @(src,evt)axZoomChanged(src,evt);
        hd.ax.Layout.Row = [3 4]; hd.ax.Layout.Column = 1;
        ylabel(hd.ax, 'Speed (cm/s)'); xlabel(hd.ax, 'Time (s)')
        disableDefaultInteractivity(hd.ax)

        subgrid3 = uigridlayout(grid1, [3 1], Padding = [0 0 0 0], ...
            RowHeight={'1x', 30, '1x'});
        subgrid3.Layout.Row = 3; subgrid3.Layout.Column = 2;
        hd.pawList = uilistbox(subgrid3, 'Multiselect', 'off', ...
            'ValueChangedFcn', @pawChanged, 'Enable','off');
        subgrid4 = uigridlayout(subgrid3, [1 2], Padding = [0 0 0 0]);
            hd.poiCheck = uicheckbox(subgrid4, Text='Plot POI', Value=0, ...
                Enable='off', ValueChangedFcn=@poiCheckChanged);
            hd.sta = uibutton(subgrid4, Text='STA', Enable='off', ...
                ButtonPushedFcn=@plotSTA);
        hd.poiList = uilistbox(subgrid3, 'Multiselect', 'off', ...
            'ValueChangedFcn', @poiChanged, 'Enable','off');

        %% Row 4: zoom in, zoom out, update buttons
        subgrid2 = uigridlayout(grid1, [1 3], 'Padding', [0 0 0 0]);
        subgrid2.Layout.Row = 4; subgrid2.Layout.Column = 2;
        uibutton(subgrid2,'Text','🔍︎+','ButtonPushedFcn',@zoomIn);
        uibutton(subgrid2,'Text','🔍︎-','ButtonPushedFcn',@zoomOut);
        uibutton(subgrid2,'Text','⭮','ButtonPushedFcn',@(src,evt)updateInfo());

        data.gait(1).hd = hd;
    end

    function importPaws(~,~)
        if ~data.has('dlc')
            % read dlc from file.
            filename = hd.path.Value;
            [filename, pathname]=uigetfile(filename, 'Open DeepLabCut file');
            if isequal(pathname,0), return; end
            filename=fullfile(pathname, filename);
            if ~exist(filename, "file"), return; end
            hd.path.Value = pathname;
        
            data.dlc.table = DLC.read_dlc(filename);
        end

        % get bodypart list
        list = data.dlc.hd.list_bodyparts.Items;
        
        % body and paw selection
        [bodyIdx, tf] = listdlg('PromptString','Select body:','ListString',list);
        if ~tf, return; end
        [pawIdx, tf] = listdlg('PromptString','Select paws:','ListString',list);
        if ~tf, return; end

        % add selected body parts into GUI lists
        hd.body.Items = list(bodyIdx); hd.body.Enable = 'on';
        hd.pawList.Items = list(pawIdx); hd.pawList.Enable = 'on';
        hd.pawList.ItemsData = 1:numel(pawIdx);

        getSpeeds();
        plotSpeeds();

        % add listeners
        hd.timeListener = addlistener(data, 'TimeChanged', @(src, evt)updateGaitTime(src.currentTime));
        hd.zoomListener = addlistener(data, 'ZoomChanged', @(src, evt)updateGaitZoom(src.currentZoom));
        hd.dataListener = addlistener(data, 'DataChanged', @(~,~)updateInfo());
        hd.infoListener = addlistener(data, 'InfoChanged', @(~,~)updateInfo());

        data.gait.hd = hd;
    end

    function getSpeeds()
        hd.frameRate.Value = data.getFrameRate;
        data.gait.speedFactor = hd.frameRate.Value / hd.lengthFactor.Value;

        % get body xy
        data.gait.body.name = hd.body.Value;
        data.gait.body.x = data.dlc.table.([hd.body.Value, '_x']);
        data.gait.body.y = data.dlc.table.([hd.body.Value, '_y']);

        n=round(0.125*data.getFrameRate); 
        body_speed=GAIT.smooth_speed(data.gait.body.x, data.gait.body.y, n);
        body_speed = body_speed(:).*data.gait.speedFactor; 
        data.gait.body.speed = body_speed;

        for ii = 1:numel(hd.pawList.Items)                
            data.gait.paw(ii).name = hd.pawList.Items{ii};
            x = data.dlc.table.([data.gait.paw(ii).name '_x']);
            y = data.dlc.table.([data.gait.paw(ii).name '_y']);

            data.gait.paw(ii).x = x;
            data.gait.paw(ii).y = y;
        
            paw_speed = GAIT.smooth_speed(x, y, 3).*data.gait.speedFactor;
            
            % remove paw speed below body thresh
            paw_speed(body_speed < hd.bodythresh.Value) = NaN;

            data.gait.paw(ii).speed = paw_speed;
        end
    end
   
    function plotSpeeds()
        hold(hd.ax, 'on');
        data.gait.t = data.dlc.t;

        % body speed
        hd = shared.myPlot(@plot, hd, 'bodyPlot', hd.ax, ...
                        data.gait.t, data.gait.body.speed, ...
                        'k-', 'ButtonDownFcn', @axClicked);
        % paw speed
        pawIdx = hd.pawList.Value;
        hd = shared.myPlot(@plot, hd, 'pawPlot', hd.ax, ...
                        data.gait.t, data.gait.paw(pawIdx).speed, ...
                        'b-', 'ButtonDownFcn', @axClicked);

        % threshold lines
        hd = shared.myPlot(@yline, hd, 'bodyThresLine', hd.ax, ...
                        [], hd.bodythresh.Value, ...
                        'k:', 'HitTest', 'off');
        hd = shared.myPlot(@yline, hd, 'pawThresLine', hd.ax, ...
                        [], hd.pawthresh.Value, ...
                        'b:', 'HitTest', 'off');

        % time line
        hd = shared.myPlot(@xline, hd, 'timeline', hd.ax, ...
                        data.currentTime, [], ...
                        'k-', 'HitTest', 'off');

        data.gait.hd = hd;
    end

    function getPOIs()
        body_speed = data.gait.body.speed;
        bodythres = hd.bodythresh.Value;
        pawthres = hd.pawthresh.Value;

        MinTimeInterval = 0.2*data.getFrameRate();
        MaxSpeedLimit = 50;

        for ii = 1:numel(data.gait.paw)
            speed = data.gait.paw(ii).speed;
            
            % find the first index of each no move period.
            % insert noMove to break up the non-continuous pawups and pawdowns.
            noMoveIdx = find(diff(body_speed < bodythres)==1) + 1 ;
            data.gait.paw(ii).noMove = noMoveIdx;

            % paw up
            pawUpIdx = find(speed(1:end-1)<=pawthres & speed(2:end)>pawthres);
            data.gait.paw(ii).pawUp = pawUpIdx;

            % paw down
            pawDownIdx = find(speed(1:end-1)>pawthres & speed(2:end)<=pawthres)+1;
            data.gait.paw(ii).pawDown = pawDownIdx;
        
            % peak and maxspeed
            [maxSpeed,peakIdx] = findpeaks(speed, "MinPeakProminence", pawthres, "MinPeakDistance", MinTimeInterval); 
            data.gait.paw(ii).peak = peakIdx;
            data.gait.paw(ii).maxSpeed = maxSpeed;
            
            % valley
            [~,valleyIdx] = findpeaks(70-speed, 'MinPeakProminence', pawthres, "MinPeakDistance", MinTimeInterval); 
            valleyIdx(speed(valleyIdx)>MaxSpeedLimit)=[];
            data.gait.paw(ii).valley = valleyIdx;

            % % interval
            % pawlineup = diff(sortrows([t(pawUpIdx), ones(size(pawUpIdx)); ...
            %             t(noMoveIdx), NaN(size(noMoveIdx))], 1));
            % data.gait.paw(ii).interval = pawlineup(pawlineup(:,2)==0,1);
            % 
            % % stride length
            % stride=sqrt(diff(shared.nan_index(x,valleyIdx)).^2+diff(shared.nan_index(y,valleyIdx)).^2);
            % stride(stride>MaxStepLength)=[];
            % gait.paw(ii).stride = stride.*gait.length_convert_factor;
            % 
            % % swing and stance
            % pawlineup = [pawUpIdx(:), ones(length(pawUpIdx),1); ...
            %             pawDownIdx(:), ones(length(pawDownIdx),1).*2; ...
            %             noMoveIdx(:), NaN(length(noMoveIdx),1)];
            % pawlineup = sortrows(pawlineup, 1);
            % pawinterval = diff(pawlineup);
            % swing_idx = pawinterval(:,2)==1 & ~isnan(pawinterval(:,1));
            % stance_idx = pawinterval(:,2)==-1 & ~isnan(pawinterval(:,1));
            % 
            % % swing & stance: duration, from, to
            % swing = table(pawinterval(swing_idx,1), ...
            %               pawlineup(swing_idx,1), ...
            %               pawlineup([false; swing_idx],1), ...
            %               'VariableNames',{'duration','from','to'});
            % swing(swing.duration==0,:)=[];
            % stance = table(pawinterval(stance_idx,1), ...
            %               pawlineup(stance_idx,1), ...
            %               pawlineup([false; stance_idx],1), ...
            %               'VariableNames',{'duration','from','to'});
            % stance(stance.duration==0,:)=[];
            % swing_percent = mean(swing.duration) / (mean(swing.duration) + mean(stance.duration));
            % 
            % data.gait.paw(ii).swing = swing;
            % data.gait.paw(ii).stance = stance;
            % data.gait.paw(ii).swingPercent = swing_percent;
        
        end
        % add them to List
        hd.poiCheck.Enable = 'on';
        hd.poiCheck.Value = 1;
        hd.sta.Enable = 'on';
        hd.poiList.Enable = 'on';
        hd.poiList.Items = {'pawUp','pawDown','peak','valley'};
    end

    function plotPOIs()
        if hd.poiCheck.Value
            % paw POIs
            pawIdx = hd.pawList.Value;
            poiName = hd.poiList.Value;
            poiIdx = data.gait.paw(pawIdx).(poiName);
            poiT = data.gait.t(poiIdx);
            poiX = data.gait.paw(pawIdx).x(poiIdx);
            poiY = data.gait.paw(pawIdx).y(poiIdx);
                
            linespec = 'ro';
            hd = shared.myPlot(@scatter, hd, 'poiGait', hd.ax, ...
                            poiT, hd.pawPlot.YData(poiIdx), ...
                            linespec);
    
            if data.has('emg')
                hd = shared.myPlot(@scatter, hd, 'poiEMG', data.emg.hd.ax, ...
                                poiT, zeros(size(poiT)), linespec);
            end
    
            if data.has('dlc')
                hd = shared.myPlot(@scatter, hd, 'poiXDLC', data.dlc.hd.ax, ...
                                poiT, poiX, linespec);
                hd = shared.myPlot(@scatter, hd, 'poiYDLC', data.dlc.hd.ax, ...
                                poiT, poiY, linespec);
            end
    
            if data.has('video') 
                hd = shared.myPlot(@scatter, hd, 'poiVideo', data.video.hd.ax, ...
                                poiX, poiY, linespec);
                timeWindow = 1;
                alpha(hd.poiVideo, 2./(1 + exp(abs(poiT-data.currentTime)/timeWindow)));
            end
    
            data.gait.hd = hd;
        end
    end

    function updateInfo()
        getSpeeds()
        plotSpeeds()
        % gaitAnalysis()
        % plotPOIs()
    end

    function gaitAnalysis(~,~)
        getPOIs();
        plotPOIs();
    end

    function plotSTA(~,~)
        if ~data.has('emg')
            uialert(fig, 'Requires EMG', 'Error');
            return;
        end

        channel = data.emg.hd.chanList.Value;
        emgType = data.emg.hd.datatype.Value;
        if strcmp(emgType, "Raw")
            emg = data.emg.analog_data(:,channel);
            emgT = data.emg.t;
        else
            emg = data.emg.processed.data(:,channel);
            emgT = data.emg.processed.t;
        end
        
        pawIdx = hd.pawList.Value;
        poiName = hd.poiList.Value;
        poiIdx = data.gait.paw(pawIdx).(poiName);
        poiT = data.gait.t(poiIdx);
        
        [ydata, xdata, info] = GAIT.sta(emg, emgT, poiT, 'plot');

        sta = info;
        sta.ydata = ydata;
        sta.xdata = xdata;
        sta.emgType = emgType;
        sta.emgChan = channel;
        sta.emgChanName = data.emg.hd.chanList.Items{channel};
        sta.pawName = data.gait.paw(pawIdx).name;
        sta.poiName = poiName;

        data.gait.sta = sta;
        assignin('base', 'sta', sta);
    end

    function pawChanged(~,~)
        plotSpeeds();
        plotPOIs();
    end

    function bodyChanged(~,~)
        getSpeeds();
        plotSpeeds();
    end

    function bodyThreshChanged(~,~)
        hd = shared.myPlot(@yline, hd, 'bodyThresLine', hd.ax, ...
                        [], hd.bodythresh.Value, ...
                        'k:', 'HitTest', 'off');
    end

    function pawThreshChanged(~,~)
        hd = shared.myPlot(@yline, hd, 'pawThresLine', hd.ax, ...
                        [], hd.pawthresh.Value, ...
                        'b:', 'HitTest', 'off');

    end

    function poiChanged(~,~)
        plotPOIs();
    end

    function poiCheckChanged(src,~)
        handles = {'poiGait','poiEMG','poiXDLC','poiYDLC','poiVideo'};
        for k=1:numel(handles)
            if isfield(hd, handles{k}) && ishghandle(hd.(handles{k}))
                hd.(handles{k}).Visible = src.Value;
            end
        end
        plotPOIs();
    end

    % === sync time and zoom ===========
    function axClicked(~,evt)
        data.setTime(evt.IntersectionPoint(1));
    end
    
    function updateGaitTime(currentTime)
        if data.has('gait')
            % currentFrame = round(currentTime * data.dlc.frameRate);
            % hd.currentFrame.Value = currentFrame;
            set(hd.timeline, 'Value', currentTime);
    
            zoomlim = shared.zoom(get(hd.ax,'xLim'), currentTime, 'pan');
            data.setZoom(zoomlim);
    
            if data.has('video')
                updateVideoMarker(currentTime)
            end
        end
    end

    function updateVideoMarker(currentTime)
        if isfield(hd, 'poiVideo') && ishghandle(hd.poiVideo)
            poiIdx = data.gait.paw(hd.pawList.Value).(hd.poiList.Value);
            poiT = data.gait.t(poiIdx);
            set(hd.poiVideo, ...
                "AlphaData", 2./(1 + exp(abs(poiT-currentTime))) );
        end
    end
    
    function zoomIn(~, ~)
        zoomlim = shared.zoom(get(hd.ax,'xLim'), data.currentTime, 'in');
        data.setZoom(zoomlim);
    end
    
    function zoomOut(~, ~)
        zoomlim = shared.zoom(get(hd.ax,'xLim'), data.currentTime, 'out');
        data.setZoom(zoomlim);
    end
    
    function axZoomChanged(src,~)
        data.setZoom(src.Limits);
    end
    
    function updateGaitZoom(newZoom)
        if data.has('gait')
            newZoom(1) = max([0 newZoom(1)]);
            newZoom(2) = min([newZoom(2) data.gait.t(end)]);
            xlim(hd.ax, newZoom);
            data.currentZoom = newZoom;
        end
    end
    
    % close function =================================
    function onClose(src,~)
        
        % Clear all the handles and plots;
        field = fields(hd);
        for k=1:length(field)
            try
                delete(hd.(field{k}))
            catch ME
                disp(field{k})
                disp(hd.(field{k}))
                warning(ME.identifier, '%s', ME.message);
            end
        end

        % Clear data and graphic handles
        data.gait = struct();
    
        delete(src);  % finally close the GUI
    end

end 