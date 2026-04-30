function fig = video_viewer(default_path)
    % App state
    
    data = shared.SessionData.instance();
    frameIdx = 0;
    frameRate = 0;
    totalFrames = 0;
    playStep = 1;
    hd = struct();
    
    drawGUI(default_path);


    function drawGUI(default_path)
        % Main UI figure with grid layout
        fig = uifigure('Name', 'Video Viewer', 'Position', [100 100 600 600], ...
            'CloseRequestFcn', @onClose);
        fig.WindowButtonDownFcn   = @(src,evt)onMouseDown(src, evt);
        fig.WindowButtonMotionFcn = @(src,evt)onMouseMove(src, evt);
        fig.WindowButtonUpFcn     = @(src,evt)onMouseUp(src, evt);
        drawnow

        gl = uigridlayout(fig, [4, 2]);
        gl.RowHeight = {30, 30, 40, '1x'};
        gl.ColumnWidth = {'1x', 100};
        gl.Padding = [10 10 10 10];
        gl.RowSpacing = 8;
        gl.ColumnSpacing = 8;
    
        % Row 1: video path and open button
        hPath = uieditfield(gl, 'text', 'Editable', 'off');
        if nargin>=1
            hPath.Value = default_path;
        end
        hPath.Layout.Row = 1; hPath.Layout.Column = 1;
    
        uibutton(gl, 'Text', 'Open Video', 'ButtonPushedFcn', @openVideo, ...
            'Layout', matlab.ui.layout.GridLayoutOptions('Row', 1, 'Column', 2));
    
        % Row 2: frame info
        subgrid1 = uigridlayout(gl, [1 3], 'Padding', [0 0 0 0]);
        subgrid1.ColumnWidth = {'1x', 130, 100, 90};
        subgrid1.Layout.Row = 2; subgrid1.Layout.Column = 1;

            % subgrid1
            hd.info = uilabel(subgrid1, ...
                'Text', 'Info:', 'BackgroundColor','W');
    
            hd.frameRate = uieditfield(subgrid1, 'numeric', ...
                'Limits', [0 Inf], ...
                'ValueDisplayFormat', 'FrameRate: %.2f Hz', ...
                'ValueChangedFcn', @(src,~)updateFrameRate(src.Value));

            hd.time = uieditfield(subgrid1, 'numeric', ...
                'Limits', [0 Inf], ...
                'ValueDisplayFormat', 'time: %.3f s', ...
                'ValueChangedFcn', @(src,~)updateVideoTime(src.Value));
    
            hd.frame = uieditfield(subgrid1, 'numeric', ...
                'Limits', [1 Inf], ...
                'RoundFractionalValues', true, ...
                'ValueDisplayFormat', 'frame: %d', ...
                'ValueChangedFcn', @manualFrameInput);

        subgrid2 = uigridlayout(gl, [1 2], 'Padding', [0 0 0 0]);
        subgrid2.Layout.Row = 2; subgrid2.Layout.Column = 2;

            hd.last = uibutton(subgrid2, 'Text', '<', ...
                'Tooltip','Ctrl+Click to change step size', ...
                'ButtonPushedFcn', @(src,evt)moveVideoFrame(-1));
            hd.next = uibutton(subgrid2, 'Text', '>', ...
                'Tooltip','Ctrl+Click to change step size', ...
                'ButtonPushedFcn', @(src,evt)moveVideoFrame(1));
        
        % Row 3: slider and play button
        hd.slider = uislider(gl, 'ValueChangedFcn', @sliderMoved);
        hd.play = uibutton(gl, 'Text', 'Play', 'ButtonPushedFcn', @togglePlay);
    
        % Row 4: axes for video
        ax = uiaxes(gl);
        ax.Layout.Row = 4; ax.Layout.Column = [1 2];
        ax.XTick = []; ax.YTick = [];
    
        % Timer for playback
        hd.timer = timer('ExecutionMode', 'fixedRate', ...
            'Period', 0.001, ...
            'TimerFcn', @timerRunning);

        hd.path = hPath;
        hd.ax = ax;

        data.video(1).hd = hd;
    end

    function openVideo(~,~)
        filename = hd.path.Value;
        if isempty(filename)
            filename='*.mp4';
        else
            [pathname, file, ext] = fileparts(filename);
            if isempty(ext)
                filename = fullfile(pathname, file, '*.mp4');
            else
                filename = fullfile(pathname, ['*' ext]);
            end
        end
        [file, path] = uigetfile(filename, 'Open Video file');
        if isequal(file, 0); return; end
        filename = fullfile(path, file);
        hd.path.Value = filename;

        data.video.vid = VideoReader(filename);

        % initialize video image
        hold(hd.ax, 'off')
        hd.image = imshow(readFrame(data.video.vid), 'Parent',hd.ax);
        set(hd.image, 'ButtonDownFcn',@manualFixCoord)
        hold(hd.ax, 'on')
        data.video.hd.image = hd.image;
        drawnow

        % add listeners
        hd.timeListener = addlistener(data, 'TimeChanged', @(src, evt)updateVideoTime(src.currentTime));
        hd.infoListener = addlistener(data, 'InfoChanged', @(~,~)updateInfo());
        hd.dataListener = addlistener(data, 'DataChanged', @(~,~)drawDLCMarker());

        data.video.hd = hd;

        frameIdx = 1;
        updateInfo
    end

    function updateInfo()
        % initialize Time, Frame, and slider
        hd.frame.Value = frameIdx;
        hd.time.Value = data.video.vid.CurrentTime;
        data.currentTime = data.video.vid.CurrentTime;
        hd.slider.Value = frameIdx;

        frameRate = data.getFrameRate();
        hd.frameRate.Value = frameRate;
        drawnow

        % below is the slow part. need to wait after opening video.
        totalFrames = data.video.vid.NumFrames;
        data.video.numFrames = totalFrames;

        hd.slider.Limits = [1 totalFrames];
        % major ticks are minute marks, while values are still frame#
        hd.slider.MajorTicks = 1:frameRate*60:totalFrames;
        hd.slider.MajorTickLabels = (0:totalFrames/frameRate/60)+"'";
        
        hd.frame.Limits = [1 totalFrames];
        
        hd.info.Text = sprintf('Size: %dx%dpx\nFrames: %d', ...
            data.video.vid.Height, data.video.vid.Width, totalFrames);
    end

    function updateFrameRate(value)
        data.video.frameRate = value;
        notify(data, 'InfoChanged');
    end

    % move forward or backward frame-by-frame 
    function moveVideoFrame(direction)
        if isempty(fig.CurrentModifier)
            % move frame forward or backward
            newFrameIdx = frameIdx + direction * playStep;
            updateVideoFrame(newFrameIdx);
        elseif ismember('control', fig.CurrentModifier)
            % control + click: adjust step size or play speed
            newStep = bitshift(playStep, direction); % *2 or /2
            if newStep >= 1 && newStep <= 16
                playStep = newStep; 
                textlen = length(dec2bin(playStep));
                hd.next.Text = repmat('>',1, textlen);
                hd.last.Text = repmat('<',1, textlen);
            end
        end
    end

    function timerRunning(~,~)
        updateVideoFrame(frameIdx + playStep);
    end

    %% main == event response callback function
    function updateVideoFrame(newFrameIdx)
        if ~data.has('video') || ...
                newFrameIdx < 1 || ...
                newFrameIdx > totalFrames
            stop(hd.timer);
            hd.play.Text = 'Play';
            return; 
        end

        hd.image.CData = read(data.video.vid, newFrameIdx);
        frameIdx = newFrameIdx;

        % update Time, Frame, and slider
        hd.frame.Value = frameIdx;
        hd.time.Value = frameIdx / frameRate;
        hd.slider.Value = frameIdx;

        drawDLCMarker
        data.setTime(hd.time.Value);
    end

    function updateVideoTime(newTime)
        newFrameIdx = round(newTime * frameRate);
        updateVideoFrame(newFrameIdx);
    end

    function sliderMoved(src,~)
        updateVideoFrame(round(src.Value));
    end

    function manualFrameInput(~,~)
        frameIdx = round(hd.frame.Value);
        updateVideoFrame(frameIdx);
    end

    function togglePlay(~,~)
        if strcmp(hd.play.Text, 'Play')
            hd.play.Text = 'Pause';
            start(hd.timer);
        else
            hd.play.Text = 'Play';
            stop(hd.timer);
        end
    end

    function manualFixCoord(~,evt)
        if data.has('dlc')
            % Can only fix temp xy lines
            if ismember('temp_x', data.dlc.table.Properties.VariableNames)
                % get mouse click coordinates
                coords = evt.IntersectionPoint(1:2);
        
                % update temp data
                data.dlc.table{frameIdx, 'temp_x'} =coords(1);
                data.dlc.table{frameIdx, 'temp_y'} =coords(2);
            
                % trigger data changed event
                notify(data,'DataChanged')
            end
        end
    end

    % if there's DLC, draw the marker on the video
    function drawDLCMarker()
        disp('video.drawDLCmarker')
        if data.has('dlc') 
            hd1 = data.dlc.hd;

            % show temp marker
            if isfield(hd1, 'tempXplot')
                hd1 = shared.myPlot( ...
                    @plot, hd1, 'videoTempMarker', hd.ax, ...
                    hd1.tempXplot.YData(frameIdx), hd1.tempYplot.YData(frameIdx), ...
                    'r+', 'LineWidth', 2, 'HitTest','off');
            end

            % show marker
            hd1 = shared.myPlot(@plot, hd1, 'videoMarker', hd.ax, ...
                    hd1.xplot.YData(frameIdx), hd1.yplot.YData(frameIdx), ...
                    'g+', 'LineWidth', 2, 'HitTest','off');
            
            data.dlc.hd = hd1;
        end
        drawGaitMarker()
    end

    % if there's gait, draw gait landmarks on the video
    function drawGaitMarker()
        if data.has('gait')

        end
    end

    function onMouseDown(src, evt)
        % begin dragging
        cp = hd.ax.CurrentPoint;   % [x y] in axes data units
        cx = cp(1,1); cy = cp(1,2);
        xlims = hd.ax.XLim;
        ylims = hd.ax.YLim;
        tolx = 0.01 * diff(xlims);
        toly = 0.01 * diff(ylims);

        if data.has('dlc') 
            hd1 = data.dlc.hd;
            
            if (isfield(hd1, 'videoMarker') && ...
                hd1.videoMarker.Visible && ...
                abs(cx - hd1.videoMarker.XData) < tolx && ... 
                abs(cy - hd1.videoMarker.YData) < toly)
                    hd.dragging = hd1.videoMarker;
                    hd.offsetX = cx - hd1.videoMarker.XData;
                    hd.offsetY = cy - hd1.videoMarker.YData;
            end
            if (isfield(hd1, 'videoTempMarker') && ...
                hd1.videoTempMarker.Visible && ...
                abs(cx - hd1.videoTempMarker.XData) < tolx && ... 
                abs(cy - hd1.videoTempMarker.YData) < toly)
                    hd.dragging = hd1.videoTempMarker;
                    data.video.offsetX = cx - hd1.videoTempMarker.XData;
                    data.video.offsetY = cy - hd1.videoTempMarker.YData;
            end
        end
    end

    function onMouseUp(src, evt)
        % update data and finish dragging
        if isfield(hd, 'dragging') && ~isempty(hd.dragging)
            hd1 = data.dlc.hd;

            if isequal(hd.dragging, hd1.videoMarker)
                bodypart = hd1.list_bodyparts.Value;
                data.dlc.table.([bodypart '_x'])(frameIdx) = hd.dragging.XData;
                data.dlc.table.([bodypart '_y'])(frameIdx) = hd.dragging.YData;
            elseif isequal(hd.dragging, hd1.videoTempMarker)
                data.dlc.table.temp_x(frameIdx) = hd.dragging.XData;
                data.dlc.table.temp_y(frameIdx) = hd.dragging.YData;
            end
            notify(data,'DataChanged');
            hd.dragging = [];
        end
    end

    function onMouseMove(src, evt)
        cp = hd.ax.CurrentPoint;
        cx = cp(1,1);  cy = cp(1,2);
        xlims = hd.ax.XLim;
        ylims = hd.ax.YLim;
        tolx = 0.01 * diff(xlims);
        toly = 0.01 * diff(ylims);
        
        if ~isfield(hd, 'dragging') || isempty(hd.dragging)
            % not dragging, only change curser
            if data.has('dlc') 
                hd1 = data.dlc.hd;
                
                if (isfield(hd1, 'videoMarker') && ...
                    hd1.videoMarker.Visible && ...
                    abs(cx - hd1.videoMarker.XData) < tolx && ... 
                    abs(cy - hd1.videoMarker.YData) < toly) ...
                    || ...
                   (isfield(hd1, 'videoTempMarker') && ...
                    hd1.videoTempMarker.Visible && ...
                    abs(cx - hd1.videoTempMarker.XData) < tolx && ... 
                    abs(cy - hd1.videoTempMarker.YData) < toly)
                        fig.Pointer = 'hand';
                else
                        fig.Pointer = 'arrow';
                end
            end
        else
            % dragging
            newX = cx - data.video.offsetX;
            newY = cy - data.video.offsetY;
        
            hd.dragging.XData = newX;
            hd.dragging.YData = newY;
        end
    end

    function onClose(~,~)

        % Stop timer
        if isfield(hd, 'timer') && isvalid(hd.timer)
            stop(hd.timer);
        end
    
        % Clear all the handles, listeners, timer;
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
        data.video = struct();
    
        delete(fig);  % finally close the GUI
    end

end
