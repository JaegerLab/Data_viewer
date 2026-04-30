function fig = dlc_viewer(default_path)
    data = shared.SessionData.instance();

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
        
        hd = struct();
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
            hd.chk_x = uicheckbox(subgrid1,'Text','X','Value',1, ...
                'ValueChangedFcn', @checkXChanged);
            hd.chk_y = uicheckbox(subgrid1,'Text','Y','Value',1, ...
                'ValueChangedFcn', @checkYChanged);
            uibutton(subgrid1,'Text','GetFrameRate', 'ButtonPushedFcn',@getFrameRate);
            hd.frameRate = uieditfield(subgrid1,'numeric','Value',1, ...
                'ValueDisplayFormat','%.2f Hz','ValueChangedFcn', @frameRateChanged);
            hd.currentFrame = uieditfield(subgrid1,'numeric','Value',1, ...
                'ValueDisplayFormat','Frame: %d');
            
        % subgrid3 = uigridlayout(grid1, [1 2], 'Padding', [0 0 0 0]);
        % subgrid3.Layout.Row = 2; subgrid3.Layout.Column = 2;
        uibutton(grid1,'Text','DLC Fix', 'ButtonPushedFcn',@openFix);
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
            'ValueChangedFcn', @(src,evt)listChanged());
        hd.list_bodyparts.Layout.Row = 3; hd.list_bodyparts.Layout.Column = 2;
    
        %% Row 4:  zoom in, zoom out, update buttons        
        subgrid2 = uigridlayout(grid1, [1 3], 'Padding', [0 0 0 0]);
        uibutton(subgrid2,'Text','🔍︎+','ButtonPushedFcn',@zoomIn);
        uibutton(subgrid2,'Text','🔍︎-','ButtonPushedFcn',@zoomOut);
        uibutton(subgrid2,'Text','⭮','ButtonPushedFcn',@(src,evt)updateInfo());

        data.dlc(1).hd = hd;
    end

    function openDLC(~,~)
        hd = data.dlc.hd;
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
        frameRate = data.getFrameRate();
        hd.frameRate.Value = frameRate;
        
        currentFrame = round(data.currentTime * frameRate);
        if currentFrame == 0
            currentFrame = 1;
            
        end
        totalFrame = height(tabledlc);
        data.dlc.t = (1:totalFrame)/frameRate;

        % update info
        hd.info.Text = sprintf( ...
            'total frames: %d\ntotal time: %.2f', ...
            totalFrame, data.dlc.t(end));
        hd.currentFrame.Value = currentFrame;
        
        axis(hd.ax,'tight');
        ylim(hd.ax, [0 1200]);

        % add listeners
        hd.timeListener = addlistener(data, 'TimeChanged', @(src, evt)updateDLCtime(src.currentTime));
        hd.zoomListener = addlistener(data, 'ZoomChanged', @(src, evt)updateDLCzoom(src.currentZoom));
        hd.dataListener = addlistener(data, 'DataChanged', @(src, evt)showBodypart());
        hd.infoListener = addlistener(data, 'InfoChanged', @(src, evt)updateInfo());
        data.dlc.hd = hd;

        % draw time line
        notify(data,'TimeChanged')
        % draw trajectory plot
        notify(data,'DataChanged');
    end

    function listChanged()
        notify(data,'DataChanged');
    end

    % main update function.=========================
    function showBodypart()
        hd = data.dlc.hd;
        disp('dlc_showbodypart')
        bodypart = hd.list_bodyparts.Value;

        % update dlc plots
        tabledlc = data.dlc.table;
        xdata = tabledlc.([bodypart '_x']);
        ydata = tabledlc.([bodypart '_y']);

        % plot xy plots
        hold(hd.ax, "on");
        hd = shared.myPlot(@plot, hd, 'xplot', hd.ax, ...
                data.dlc.t, xdata, ...
                'b-', 'ButtonDownFcn', @axClicked);
        hd = shared.myPlot(@plot, hd, 'yplot', hd.ax, ...
                data.dlc.t, ydata, ...
                'g-', 'ButtonDownFcn', @axClicked);

        hd.xplot.Visible = hd.chk_x.Value;
        hd.yplot.Visible = hd.chk_y.Value;

        % if exist temp data, superimpose the temp plot.
        if ismember('temp_x', tabledlc.Properties.VariableNames)
            hd = shared.myPlot(@plot, hd, 'tempXplot', hd.ax, ...
                data.dlc.t, tabledlc.temp_x, ...
                'r-', 'ButtonDownFcn', @axClicked);
            hd.tempXplot.Visible = hd.chk_x.Value; 
            uistack(hd.tempXplot, "bottom");
            
            hd = shared.myPlot(@plot, hd, 'tempYplot', hd.ax, ...
                data.dlc.t, tabledlc.temp_y, ...
                'r-', 'ButtonDownFcn', @axClicked);
            hd.tempYplot.Visible = hd.chk_y.Value; 
            uistack(hd.tempYplot, "bottom");

            % show mask good/bad points
            bad = ~tabledlc.temp_likelihood; %select bad points
            hd = shared.myPlot(@plot, hd, 'tempXmask', hd.ax, ...
                data.dlc.t(bad), xdata(bad), ...
                'rx', 'HitTest', 'off');
            hd.tempXmask.Visible = hd.chk_x.Value;
            uistack(hd.tempXmask, "bottom");
            hd = shared.myPlot(@plot, hd, 'tempYmask', hd.ax, ...
                data.dlc.t(bad), ydata(bad), ...
                'rx', 'HitTest', 'off');
            hd.tempYmask.Visible = hd.chk_y.Value;
            uistack(hd.tempYmask, "bottom");
        else
            if isfield(hd, 'tempXplot') && ishghandle(hd.tempXplot)
                hd.tempXplot.Visible = false;
                hd.tempYplot.Visible = false;
                hd.tempXmask.Visible = false;
                hd.tempYmask.Visible = false;
            end
        end
        data.dlc.hd = hd;
    end

    % checkbox callback
    function checkXChanged(src,~)
        hd = data.dlc.hd;
        if isfield(hd, 'xplot') && ishghandle(hd.xplot)
            hd.xplot.Visible = src.Value;
        end
        if isfield(hd, 'tempXplot') && ishghandle(hd.tempXplot)
            has_temp = ismember('temp_x', data.dlc.table.Properties.VariableNames);
            hd.tempXplot.Visible = src.Value && has_temp;
            hd.tempXmask.Visible = src.Value && has_temp;
        end
        if data.has('gait')
            if isfield(data.gait.hd, 'poiXDLC') && ishghandle(data.gait.hd.poiXDLC)
                data.gait.hd.poiXDLC.Visible = src.Value && data.gait.hd.poiCheck.Value;
            end
        end
    end
    function checkYChanged(src,~)
        hd = data.dlc.hd;
        if isfield(hd, 'yplot') && ishghandle(hd.yplot)
            hd.yplot.Visible = src.Value;
        end
        if isfield(hd, 'tempYplot') && ishghandle(hd.tempYplot)
            has_temp = ismember('temp_y', data.dlc.table.Properties.VariableNames);
            hd.tempYplot.Visible = src.Value && has_temp;
            hd.tempYmask.Visible = src.Value && has_temp;
        end
        if data.has('gait')
            if isfield(data.gait.hd, 'poiYDLC') && ishghandle(data.gait.hd.poiYDLC)
                data.gait.hd.poiYDLC.Visible = src.Value && data.gait.hd.poiCheck.Value;
            end
        end
    end

    % button callback
    function getFrameRate(~,~)
        frameRate = data.getFrameRate();
        data.dlc.hd.frameRate.Value = frameRate;
        updateFrameRate(frameRate);
    end

    % manually change frame rate edit field.
    function frameRateChanged(~,~)
        data.dlc.frameRate = data.dlc.hd.frameRate.Value;
        frameRate = data.dlc.frameRate;
        updateFrameRate(frameRate);
    end

    function updateFrameRate(frameRate)
        hd = data.dlc.hd;
        data.dlc.t = (1:totalFrame) / frameRate;
        hd.info.Text = sprintf( ...
            'total frames: %d\ntotal time: %.2f', ...
            totalFrame, data.dlc.t(end));
        hd.frameRate.Value = frameRate;
        hd.xplot.XData = data.dlc.t;
        hd.yplot.XData = data.dlc.t;
        
        if hd.frameRate.Value == 1
            xlabel(hd.ax, 'Frame')
        else
            xlabel(hd.ax, 'Time (s)')
        end
    end

    % triggered by info event
    function updateInfo()
        updateFrameRate(data.getFrameRate());
    end

    function openFix(~,~)
        % draw new window where the mouse is
        mousePos = get(0, 'PointerLocation');
        hd = data.dlc.hd;
        if ~isfield(hd, 'fixGUI') || ~isgraphics(hd.fixGUI, 'figure')
            % open a new window
            hd.fixGUI = DLC.DLC_fix_GUI(mousePos);
        else
            % if window is already open, activate it.
            figure(hd.fixGUI)
        end
        data.dlc.hd = hd;
    end

    % === sync time and zoom ===========
    function axClicked(~,evt)
        clickType = get(fig, 'SelectionType');

        if isequal(clickType, "normal")
            % direct click, change time.
            data.setTime(evt.IntersectionPoint(1));
        else
            % ctrl or shift click, modify mask manually.
            if ismember('temp_likelihood', data.dlc.table.Properties.VariableNames)
                % find index of the clicked point
                [~,index] = min(abs(data.dlc.t - evt.IntersectionPoint(1)));
                mask = data.dlc.table.temp_likelihood;
                field = data.dlc.hd.list_bodyparts.Value;
                xdata = data.dlc.table.([field '_x']);
                ydata = data.dlc.table.([field '_y']);

                % toggle good/bad on the mask
                if isequal(clickType, "alt")
                    % ctrl-click, toggle 1 data point.
                    mask(index) = ~mask(index);
                elseif isequal(clickType, "extend")
                    % shift-click, toggle whole section of the same value.
                    edges = find(diff(mask)~=0);
                    left_edge = edges(find(edges<index, 1, "last"))+1;
                    right_edge = edges(find(edges>index, 1, "first"));
                    range = left_edge:right_edge;
                    mask(range) = ~mask(range);
                end

                % change interpolation based on new mask
                [tempX, tempY] = DLC.dlc_fix_predict(xdata,ydata,[],[],mask);
        
                data.dlc.table.temp_x = tempX;
                data.dlc.table.temp_y = tempY;
                data.dlc.table.temp_likelihood = mask;
                notify(data, 'DataChanged');
            end
        end
    end

    function updateDLCtime(currentTime)
        if data.has('dlc')
            hd = data.dlc.hd;
            currentFrame = round(currentTime * data.getFrameRate());
            hd.currentFrame.Value = currentFrame;
            % draw time line
            hd = shared.myPlot(@xline, hd, 'timeline_dlc', hd.ax, ...
                data.currentTime,  'k', ...
                'HitTest', 'off', 'HandleVisibility', 'off');
            data.setTime(currentTime);
    
            zoomlim = shared.zoom(get(hd.ax,'xLim'), currentTime, 'pan');
            data.setZoom(zoomlim);
            data.dlc.hd = hd;
        end
    end

    function zoomIn(~, ~)
        zoomlim = shared.zoom(get(data.dlc.hd.ax,'xLim'), data.currentTime, 'in');
        data.setZoom(zoomlim);
    end

    function zoomOut(~, ~)
        zoomlim = shared.zoom(get(data.dlc.hd.ax,'xLim'), data.currentTime, 'out');
        data.setZoom(zoomlim);
    end

    function axZoomChanged(src,~)
        data.setZoom(src.Limits);
    end

    function updateDLCzoom(newZoom)
        if data.has('dlc')
            newZoom(1) = max([0 newZoom(1)]);
            newZoom(2) = min([newZoom(2) data.dlc.t(end)]);
            xlim(data.dlc.hd.ax, newZoom);
            data.currentZoom = newZoom;
        end
    end

    % close function =================================
    function onClose(src,~)
        hd=data.dlc.hd;
        % close fix GUI first.
        if isfield(hd, 'fixGUI')
            close(hd.fixGUI)
        end
        % Clear all the handles and plots;
        field = fields(hd);
        for k=1:length(field)
            try
                disp(field{k})
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