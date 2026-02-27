function fig = dlc_viewer(default_path)
    data = shared.SessionData.instance();
    hd = struct();
    currentFrame = 0;
    totalFrame = 0;
    frameRate = 1;

    drawGUI(default_path);

    function drawGUI(default_path)
        % DLC viewer window with uigridlayout
        fig = uifigure('Name', 'DLC Viewer', 'Position', [100 100 1000 500], ...
            'CloseRequestFcn', @onClose);
        drawnow
        grid1 = uigridlayout(fig, [4 2]);
        grid1.Padding = [20,20,20,20];
        grid1.ColumnWidth = {'1x', 140};
        grid1.RowHeight = {30, 30, '1x', 30};
        
    
        %% Row 1: Folder and open button
        hd.path = uieditfield(grid1, 'text'); 
        if nargin>=1
            hd.path.Value = default_path;
        end
        uibutton(grid1, 'Text', 'Open DLC', 'ButtonPushedFcn', @openDLC);
    
        %% Row 2: DLC processing
        subgrid1 = uigridlayout(grid1, [1 6], 'Padding', [0 0 0 0], ...
            'Layout', matlab.ui.layout.GridLayoutOptions('Row', 2, 'Column', 1));
        subgrid1.ColumnWidth = {'1x', 30, 30, 100, 80, 100};
            hd.info = uilabel(subgrid1,'Text',' Info:', 'BackgroundColor','w');
            hd.chk_x = uicheckbox(subgrid1,'Text','X','Value',1);
            hd.chk_y = uicheckbox(subgrid1,'Text','Y','Value',1);
            uibutton(subgrid1,'Text','GetFrameRate', 'ButtonPushedFcn',@getFrameRate);
            hd.frameRate = uieditfield(subgrid1,'numeric','Value',1, ...
                'ValueDisplayFormat','%.2f Hz','ValueChangedFcn', @frameRateChanged);
            hd.currentFrame = uieditfield(subgrid1,'numeric','Value',1, ...
                'ValueDisplayFormat','Frame: %d');
            
        % subgrid3 = uigridlayout(grid1, [1 2], 'Padding', [0 0 0 0]);
        % subgrid3.Layout.Row = 2; subgrid3.Layout.Column = 2;
        uibutton(grid1,'Text','Auto Fix', 'ButtonPushedFcn',@openFix);
            % hd.manualFix = uicheckbox(subgrid3,'Text','Man. Fix','Value', 0, ...
            %     'ValueChangedFcn',@manualFix);
        
    
        %% Row 3: DLC plot
        hd.ax = uiaxes(grid1); 
        hd.ax.Layout.Row = [3 4]; hd.ax.Layout.Column = 1;
        hd.ax.XAxis.LimitsChangedFcn = @(src,evt)axZoomChanged(src,evt);
        axis(hd.ax, 'ij'); 
        xlabel(hd.ax, 'Frame'); ylabel(hd.ax, 'Location (pixel)');
        disableDefaultInteractivity(hd.ax);

        hd.list_bodyparts = uilistbox(grid1, 'Multiselect', 'off', ...
            'ValueChangedFcn', @(src,evt)showBodypart());
        hd.list_bodyparts.Layout.Row = 3; hd.list_bodyparts.Layout.Column = 2;
    
        %% Row 4:  zoom in, zoom out, update buttons        
        subgrid2 = uigridlayout(grid1, [1 3], 'Padding', [0 0 0 0]);
        uibutton(subgrid2,'Text','🔍︎+','ButtonPushedFcn',@zoomIn);
        uibutton(subgrid2,'Text','🔍︎-','ButtonPushedFcn',@zoomOut);
        uibutton(subgrid2,'Text','⭮','ButtonPushedFcn',@(src,evt)updateInfo());

        data.dlc(1).hd = hd;
    end

    function openDLC(~,~)
        filename = hd.path.Value;
        if isempty(filename)
            filename='*.csv';
        else
            [pathname, file, ext] = fileparts(filename);
            if isempty(ext)
                filename = fullfile(pathname, file, '*.csv');
            else
                filename = fullfile(pathname, ['*' ext]);
            end
        end
        [filename, pathname]=uigetfile(filename, 'Open DeepLabCut file');
        filename=fullfile(pathname, filename);
        
        if isequal(pathname,0), return; end
        if ~exist(filename, "file"), return; end

        hd.path.Value = filename;
    
        % This reading function handles different kinds of data formats
        tabledlc = DLC.read_dlc(filename);
        data.dlc.table = tabledlc;

        % update body part list
        hd.list_bodyparts.Items = tabledlc.Properties.UserData;

        % collect info
        bodypart = hd.list_bodyparts.Value;
        xdata = tabledlc.([bodypart '_x']);
        ydata = tabledlc.([bodypart '_y']);
        frameRate = data.getFrameRate();
        hd.frameRate.Value = frameRate;
        if data.has('video')
            currentFrame = round(data.currentTime * frameRate);
        else
            currentFrame = 1;
            data.currentTime = currentFrame / frameRate;
        end
        totalFrame = height(tabledlc);
        data.dlc.t = (1:totalFrame)/frameRate;

        % update info
        hd.info.Text = sprintf( ...
            'total frames: %d\ntotal time: %.2f', ...
            totalFrame, data.dlc.t(end));
        hd.currentFrame.Value = currentFrame;
    
        % plot xy plots
        hold(hd.ax, "off");
        hd.xplot = plot(hd.ax, data.dlc.t, xdata, 'ButtonDownFcn', @axClicked);
        hold(hd.ax, 'on');
        hd.yplot = plot(hd.ax, data.dlc.t, ydata, 'ButtonDownFcn', @axClicked);
        hd.timeline_dlc = xline(hd.ax, data.currentTime, 'k', 'HitTest', 'off');

        % add listeners
        hd.timeListener = addlistener(data, 'TimeChanged', @(src, evt)updateDLCtime(src.currentTime));
        hd.zoomListener = addlistener(data, 'ZoomChanged', @(src, evt)updateDLCzoom(src.currentZoom));
        hd.dataListener = addlistener(data, 'DataChanged', @(src, evt)showBodypart());
        hd.infoListener = addlistener(data, 'InfoChanged', @(src, evt)updateInfo());
        data.dlc(1).hd = hd;

        updateVideoMarker(currentFrame)
    end

    % main update function.=========================
    function showBodypart()
        bodypart = hd.list_bodyparts.Value;

        % update dlc plots
        tabledlc = data.dlc.table;
        xdata = tabledlc.([bodypart '_x']);
        ydata = tabledlc.([bodypart '_y']);

        hd.xplot.YData = xdata;
        hd.yplot.YData = ydata;

        % if exit temp preview, superimpose it.
        if ismember('temp_x', tabledlc.Properties.VariableNames)
            hd = shared.myPlot(@plot, hd, 'tempXplot', hd.ax, ...
                data.dlc.t, tabledlc.temp_x, ...
                'HitTest', 'off');
            hd = shared.myPlot(@plot, hd, 'tempYplot', hd.ax, ...
                data.dlc.t, tabledlc.temp_y, ...
                'HitTest', 'off');
            hd.tempXplot.Visible = true; hd.tempXplot.HitTest = 'off';
            hd.tempYplot.Visible = true; hd.tempYplot.HitTest = 'off';
        else
            if isfield(hd, 'tempXplot') && ishghandle(hd.tempXplot)
                hd.tempXplot.Visible = false;
                hd.tempYplot.Visible = false;
            end
        end

        % update markers on video
        updateVideoMarker(currentFrame)
    end

    % if there's video, draw the marker on the video
    function updateVideoMarker(frame)
        if data.has('video') 
            % show temp marker
            if ismember('temp_x', data.dlc.table.Properties.VariableNames)
                hd = shared.myPlot( ...
                    @plot, hd, 'tempMarker', data.video.hd.ax, ...
                    hd.tempXplot.YData(frame), hd.tempYplot.YData(frame), ...
                    'y+', 'LineWidth', 2, 'HitTest','off');
            end

            % show marker
            hd = shared.myPlot(@plot, hd, 'marker', data.video.hd.ax, ...
                    hd.xplot.YData(frame), hd.yplot.YData(frame), ...
                    'g+', 'LineWidth', 2, 'HitTest','off');
            data.dlc.hd = hd;

            % % always need to check if plot handle is still valid.
            % if isfield(hd, 'marker') && ishghandle(hd.marker)
            %     hd.marker.XData = hd.xplot.YData(frame);
            %     hd.marker.YData = hd.yplot.YData(frame);            
            % else
            %     hd.marker = plot(data.video.hd.ax, ...
            %         hd.xplot.YData(frame), hd.yplot.YData(frame), ...
            %         'g+', 'LineWidth', 2, 'HitTest','off');
            %     data.dlc.hd = hd;
            % end
        end
    end

    % button callback
    function getFrameRate(~,~)
        frameRate = data.getFrameRate();
        hd.frameRate.Value = frameRate;
        updateFrameRate(frameRate);
    end

    % manually change frame rate edit field.
    function frameRateChanged(~,~)
        data.dlc.frameRate = hd.frameRate.Value;
        frameRate = data.dlc.frameRate;
        updateFrameRate(frameRate);
    end

    function updateFrameRate(frameRate)
        data.dlc.t = (1:totalFrame) / frameRate;
        hd.info.Text = sprintf( ...
            'total frames: %d\ntotal time: %.2f', ...
            totalFrame, data.dlc.t(end));
        hd.frameRate.Value = frameRate;
        hd.xplot.XData = data.dlc.t;
        hd.yplot.XData = data.dlc.t;
        axis(hd.ax,'tight');
        if hd.frameRate.Value == 1
            xlabel(hd.ax, 'Frame')
        else
            xlabel(hd.ax, 'Time (s)')
        end
    end

    % triggered by data event
    function updateInfo()
        updateFrameRate(data.getFrameRate());
    end

    function openFix(~,~)
        % draw new window where the mouse is
        mousePos = get(0, 'PointerLocation');
        
        if ~isfield(hd, 'fixGUI') || ~isgraphics(hd.fixGUI, 'figure')
            % open a new window
            hd.fixGUI = DLC.DLC_fix_GUI(mousePos);
        else
            % if window is already open, activate it.
            figure(hd.fixGUI)
        end
    end

    % function manualFix(src, evt)
    %     if evt.Value
    %         % opt.WindowStyle = 'modal';
    %         % new_name = hd.list_bodyparts.Value;
    %         % new_name = inputdlg('Save fixed trace as:', 'Save Trace', [1 30], {new_name}, opt);
    %         % 
    %         % if ~isempty(new_name)
    %         %     if ismember(new_name, hd.list_bodyparts.Items)
    %         %         uialert(fig, 'Overwrite?', 'Warning');
    %         %     else
    %         %         assignin('base', new_name{1}, data);
    %         % 
    %         %     end
    %         % end
    %     end
    % end

    % === sync time and zoom ===========
    function axClicked(~,evt)
        data.setTime(evt.IntersectionPoint(1));
    end

    function updateDLCtime(currentTime)
        if data.has('dlc')
            currentFrame = round(currentTime * data.getFrameRate());
            hd.currentFrame.Value = currentFrame;
            set(hd.timeline_dlc, 'Value', currentTime);
    
            zoomlim = shared.zoom(get(hd.ax,'xLim'), currentTime, 'pan');
            data.setZoom(zoomlim);

            updateVideoMarker(currentFrame)
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

    function updateDLCzoom(newZoom)
        if data.has('dlc')
            newZoom(1) = max([0 newZoom(1)]);
            newZoom(2) = min([newZoom(2) data.dlc.t(end)]);
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
        data.dlc = struct();
    
        delete(src);  % finally close the GUI
    end
end