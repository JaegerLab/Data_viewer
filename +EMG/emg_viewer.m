function fig = emg_viewer(default_path)
    % App state
    data = shared.SessionData.instance();
    
    hd = struct();

    
    drawGUI(default_path);

    function drawGUI(default_path)
        % EMG viewer window with uigridlayout
        fig = uifigure('Name', 'EMG Viewer', 'Position', [100 100 1000 500], ...
            'CloseRequestFcn', @onClose);
        drawnow
        grid1 = uigridlayout(fig, ...
            'RowHeight', {30, 30, '1x', 30}, ...
            'ColumnWidth',{'1x', 140});
        
        
        %% Row 1: Folder and open button
        hd.path = uieditfield(grid1, 'text'); 
        if nargin>=1
            hd.path.Value = default_path;
        end
        uibutton(grid1, 'Text', 'Open EMG', 'ButtonPushedFcn', @openEMG);
    
        %% Row 2: Preprocess group
        subgrid1 = uigridlayout(grid1, [1 5], 'Padding', [0 0 0 0]);
        subgrid1.ColumnWidth = {'1x', 120, 100, 100, 100};
            hd.info = uilabel(subgrid1, 'Text', 'Sample Rate (Hz):');
            uibutton(subgrid1, 'Text', 'Push Frame Rate', 'ButtonPushedFcn', @pushFrameRate);
            hd.time = uieditfield(subgrid1,'numeric','Value',0, ...
                    'ValueDisplayFormat', 'time: %.3f s');
            uibutton(subgrid1, 'Text', 'Pre-Process', 'ButtonPushedFcn', @preprocess);
            hd.datatype = uidropdown(subgrid1, "Items", "Raw", "ValueChangedFcn", @typeChanged);

        uibutton(grid1, 'Text', 'Load Channel Map', 'ButtonPushedFcn', @(src,evt)loadChannelMap(true)); %true = sort muscles
    
        %% Row 3: Listbox + Axes
        hd.ax = uiaxes(grid1);
        hold(hd.ax, "on"); axis(hd.ax, 'tight');
        hd.ax.Layout.Row = [3 4]; hd.ax.Layout.Column = 1;
        hd.ax.XAxis.LimitsChangedFcn = @(src,evt)axZoomChanged(src,evt);
        xlabel(hd.ax, 'Time (s)'); ylabel(hd.ax, 'Voltage');
        disableDefaultInteractivity(hd.ax)
    
        hd.chanList = uilistbox(grid1, 'Multiselect', 'on', ...
            'ValueChangedFcn', @(src,evt)updatePlots());
        hd.chanList.Layout.Row = 3; hd.chanList.Layout.Column = 2;

        %% Row 4: zoom in, zoom out, update buttons
        subgrid2 = uigridlayout(grid1, [1 3], 'Padding', [0 0 0 0]);
        uibutton(subgrid2,'Text','🔍︎+','ButtonPushedFcn',@zoomIn);
        uibutton(subgrid2,'Text','🔍︎-','ButtonPushedFcn',@zoomOut);
        uibutton(subgrid2,'Text','⭮','ButtonPushedFcn',@(src,evt)updatePlots());

        % add listeners
        hd.timeListener = addlistener(data, 'TimeChanged', @(src, evt)updateEMGtime(src.currentTime));
        hd.zoomListener = addlistener(data, 'ZoomChanged', @(src, evt)updateEMGzoom(src.currentZoom));
        hd.dataListener = addlistener(data, 'DataChanged', @(src, evt)updatePlots());
        hd.InfoListener = addlistener(data, 'InfoChanged', @(src, evt)updateInfo());

        data.emg(1).hd = hd;
    end

    %% === Load EMG the first time === %%
    function openEMG(~, ~)
        % open file----------------
        default_file = hd.path.Value;
        if isempty(default_file)
            default_file='*.rhd';
        else
            [pathname, file, ext] = fileparts(default_file);
            if isempty(ext)
                % the last part is a folder
                default_file = fullfile(pathname, file, '*.rhd');
            else
                % the last part is a file
                default_file = fullfile(pathname, ['*' ext]);
            end
        end
        [files, path] = uigetfile(default_file, 'Select EMG File(s)', 'MultiSelect', 'on');
        if isequal(files, 0), return; end
        if ischar(files), files = {files}; end  % ensure cell

        fullPaths = fullfile(path, files);
        emgData = EMG.read_intan(fullPaths);

        % Update state ---------------
        data.emg.filename = fullPaths;
        data.emg.display_name = [fullPaths{1} ' ~ ' files{end}];
        data.emg.analog_data = emgData.analog_data;
        data.emg.analog_channels = {emgData.analog_channels.custom_channel_name};
        data.emg.sample_rate = emgData.sample_rate;
        if isfield(emgData, 'dig_in_data')
            data.emg.trigger.data = emgData.dig_in_data;
        end
        data.emg.t = emgData.t;

        updateInfo();
        updatePlots();
    end

    % separate reading and updating info, because reading is slow, and
    % data is saved in SessionData. No need to repeat reading for update.
    function updateInfo()
        % trigger time
        if isfield(data.emg, 'trigger')
            data.emg.trigger.time = data.emg.t(1 + find(diff(data.emg.trigger.data)>0.5));
            data.emg.trigger.freq = 1/median(diff(data.emg.trigger.time));
            data.emg.trigger.number = length(data.emg.trigger.time);
            if data.has('dlc')
                data.dlc.hd.frameRate = data.emg.trigger.freq;
            end
        end

        % Update UI -------------------
        hd.path.Value = data.emg.display_name;
        hd.chanList.Items = data.emg.analog_channels;
        hd.chanList.ItemsData = 1:length(data.emg.analog_channels);

        hd.info.Text = sprintf( ...
            'Rate: %d Hz, Length: %.2f s\nTrigger#: %d, Freq: %.2f Hz', ...
            data.emg.sample_rate, data.emg.t(end), ...
            data.emg.trigger.number, data.emg.trigger.freq);
    end

    function pushFrameRate(~,~)
        notify(data, 'InfoChanged');
    end

    %% main update
    function updatePlots()
        channels = hd.chanList.Value;
        
        % raw plot
        if isequal(hd.datatype.Value, "Raw") ||  isfield(data.emg, 'temp')
            t = data.emg.t;
            y = data.emg.analog_data(:,channels);
            if isfield(hd, 'rawPlot') && ishghandle(hd.rawPlot)
                hd.rawPlot.XData = t;
                hd.rawPlot.YData = y;
                hd.rawPlot.Visible = true;
            else
                hd.rawPlot = plot(hd.ax, t, y, 'ButtonDownFcn',@axClicked);
            end
        else 
            if isfield(hd, 'rawPlot') && ishghandle(hd.rawPlot)
                hd.rawPlot.Visible = false;
            end
        end
        % temp plot
        if isfield(data.emg, 'temp')
            t = data.emg.temp.t;
            y = data.emg.temp.data;
            if isfield(hd, 'tempPlot') && ishghandle(hd.tempPlot)
                hd.tempPlot.XData = t;
                hd.tempPlot.YData = y;
                hd.tempPlot.Visible = true;
            else
                hd.tempPlot = plot(hd.ax, t, y,'ButtonDownFcn',@axClicked);
            end
        else
            if isfield(hd, 'tempPlot') && ishghandle(hd.tempPlot)
                hd.tempPlot.Visible = false;
            end
        end
        if isequal(hd.datatype.Value, "Processed") && isfield(data.emg, 'processed')
            t = data.emg.processed.t;
            y = data.emg.processed.data(:,channels);
            if isfield(hd, 'prosPlot') && ishghandle(hd.prosPlot)
                hd.prosPlot.XData = t;
                hd.prosPlot.YData = y;
                hd.prosPlot.Visible = true;
            else
                hd.prosPlot = plot(hd.ax, t, y, 'ButtonDownFcn',@axClicked);
            end
        else
            if isfield(hd, 'prosPlot') && ishghandle(hd.prosPlot)
                hd.prosPlot.Visible = false;
            end
        end
        
        if isfield(hd, 'timeline') && ishghandle(hd.timeline)
            hd.timeline.Value = data.currentTime;
        else
            hd.timeline = xline(hd.ax, data.currentTime, 'k', 'HitTest','off');
        end
        data.emg.hd = hd;
    end

    function loadChannelMap(sort_mapping)
        % get default fileter
        default_file = hd.path.Value;
        if isempty(default_file)
            default_file='*.csv';
        else
            path = fileparts(default_file);
            default_file = fullfile(path, '*.csv');
        end
        % select file
        [file, path] = uigetfile(default_file, 'Select Channel Mapping File', 'MultiSelect', 'off');
        filename = fullfile(path, file);
        if isequal(path,0) || ~exist(filename, "file"), return; end
        
        % read channel mapping csv file
        ch_mapping = readtable(filename);

        % check if channel number is correct.
        if height(ch_mapping) == size(data.emg.analog_data, 2)
            % mono-pole recording
        elseif height(ch_mapping) == 2*size(data.emg.analog_data, 2)
            % differential recording
            ch_mapping = ch_mapping(1:2:end, :);
        else
            error('Channel number mismatch');
        end

        % connect columns in the table
        ch_names = strcat(num2str(ch_mapping.Channel), '_', ...
                                   ch_mapping.Muscle, '_', ...
                                   ch_mapping.Note);
        if sort_mapping
            [~, orders] = sort(ch_mapping.Muscle);
        else
            orders = 1:height(ch_mapping);
        end

        % save name in the list
        hd.chanList.Items = ch_names(orders);
        hd.chanList.ItemsData = orders;
    end

    %% pre-process data
    function preprocess(~,~)
        % force single channel
        hd.chanList.Value = hd.chanList.Value(1);
        
        % draw new window where the mouse is
        mousePos = get(0, 'PointerLocation');
        
        if ~isfield(hd, 'prepGUI') || ~isgraphics(hd.prepGUI, 'figure')
            hd.prepGUI = EMG.emg_prep_GUI(mousePos);
        else
            % if window is already open, don't open another one.
            figure(hd.prepGUI)
        end
    end

    function typeChanged(~,~)
        updatePlots
    end

    %% sync figures' time and zoom between windows ========
    function axClicked(~,evt)
        data.setTime(evt.IntersectionPoint(1));
    end

    function updateEMGtime(currentTime)
        if data.has('emg')

            hd.timeline.Value = currentTime;
            
            hd.time.Value = currentTime;
    
            zoomlim = shared.zoom(data.currentZoom, currentTime, 'pan');
            data.setZoom(zoomlim);
        end
    end

    function zoomIn(~, ~)
        zoomlim = shared.zoom(get(hd.ax, 'xLim'), data.currentTime, 'in');
        data.setZoom(zoomlim);
    end

    function zoomOut(~, ~)
        zoomlim = shared.zoom(get(hd.ax, 'xLim'), data.currentTime, 'out');
        data.setZoom(zoomlim);
    end

    function axZoomChanged(src, ~)
        data.setZoom(src.Limits);
    end

    function updateEMGzoom(newZoom)
        if data.has('emg')
            newZoom(1)=max([0 newZoom(1)]);
            newZoom(2)=min([newZoom(2), data.emg.t(end)]);
            xlim(hd.ax, newZoom);
            data.currentZoom = newZoom;
        end
    end

    % close function
    function onClose(~,~)
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

        % Clear the data
        data.emg = struct();
    
        delete(fig);  % finally close the GUI
    end

end
