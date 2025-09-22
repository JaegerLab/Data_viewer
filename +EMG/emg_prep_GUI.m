function fig = emg_prep_GUI(mousePos)
% pre process window

    data = shared.SessionData.instance();
    parameters = struct();
    
    %% draw GUI
    % grid 4x3
    mousePos(2)=mousePos(2)-150;
    fig = uifigure('Name', 'EMG Pre-Process', 'Position', [mousePos 400 150], ...
        'CloseRequestFcn', @onClose);
    grid1 = uigridlayout(fig, [4 3]);

    % line 1 - high pass filter
    chkHighPass = uicheckbox(grid1,'Text', 'High Pass', 'Value', 1);
    editHighPass = uieditfield(grid1, 'numeric','Value',500);
    chkFiltFilt = uicheckbox(grid1, 'Text', 'FiltFilt', 'Value', 0);

    % line 2 - rectify
    chkRectify = uicheckbox(grid1,'Text', 'Rectify', 'Value',1);

    % line 3 - smooth and downsample
    chkDownSample = uicheckbox(grid1,'Text', 'Down Sample', 'Value',1, ...
        'Layout', matlab.ui.layout.GridLayoutOptions('Row', 3, 'Column', 1));
    editDownRate = uieditfield(grid1, 'numeric', 'Value', 200);

    % line 4 - buttons: preview, save&close, cancel
    uibutton(grid1, 'Text','Preview', 'ButtonPushedFcn', @preview, ...
        'Layout', matlab.ui.layout.GridLayoutOptions('Row', 4, 'Column', 1));
    uibutton(grid1, 'Text','Apply & Close', 'ButtonPushedFcn', @saveClose);
    uibutton(grid1, 'Text','Cancel', 'ButtonPushedFcn', @cancelClose);
    drawnow

    data.emg.hd.datatype.Value = "Raw";
    notify(data, 'DataChanged');

    function [new_data, new_t]=process(old_data)
        t = data.emg.t;
        fs = 1/median(diff(t));
        new_data = old_data;

        progbar = uiprogressdlg(fig,'Title','Processing', ...
            'Message','Filtering', ...
            'Indeterminate','on');
        drawnow

        if chkHighPass.Value
            fcut = editHighPass.Value;
            parameters.filter = designfilt('highpassiir', 'FilterOrder', 4, ...
                           'HalfPowerFrequency', fcut, 'SampleRate', fs);
            if chkFiltFilt.Value
                new_data = filtfilt(parameters.filter, new_data);
            else
                new_data = filter(parameters.filter, new_data); 
            end
        end
        
        if chkRectify.Value
            new_data = abs(new_data);
        end
        
        if chkDownSample.Value
            % smooth
            progbar.Message = 'Smoothing';
            down_fs = editDownRate.Value;
            downsample_factor = round(fs / down_fs);
            parameters.smoothWidth = round(2.5 * downsample_factor);
            new_data = shared.fastsmooth(new_data, parameters.smoothWidth,1,1);

            % truncate and downsample
            progbar.Message = 'Downsampling';
            new_data = downsample(new_data(t>=0,:), downsample_factor);
            new_t = downsample(t(t>=0), downsample_factor);
        else
            % truncate (discard negative time)
            new_data = new_data(t>=0,:);
            new_t = t(t>=0);
        end

        % close the progress bar
        close(progbar)
    end

    function preview(~,~)
        ch = data.emg.hd.chanList.Value(1);

        % only process 1 channel for speed
        [new_data, new_t]=process(data.emg.analog_data(:,ch)); 
        data.emg.temp.data = new_data;
        data.emg.temp.t = new_t;

        notify(data, 'DataChanged');
    end

    function saveClose(~,~)
        % process all channels
        [processed_data, processed_t] = process(data.emg.analog_data);
        data.emg.processed.data = processed_data;
        data.emg.processed.t = processed_t;

        % save parameters
        if chkHighPass.Value
            data.emg.processed.highPassCutOff = editHighPass.Value;
            data.emg.processed.filterOrder = 4;
            data.emg.processed.filterType = 'highpassiir';
            data.emg.processed.filter = parameters.filter;
            data.emg.processed.filtfilt = chkFiltFilt.Value;
        end
        data.emg.processed.rectify = chkRectify.Value;
        if chkDownSample.Value
            data.emg.processed.smoothWidth = parameters.smoothWidth;
            data.emg.processed.downSampleRate = editDownRate.Value;
        end
        
        data.emg.hd.datatype.Items = ["Raw","Processed"];
        data.emg.hd.datatype.Value = "Processed";

        close(fig);
    end

    function cancelClose(~,~)
        close(fig);
    end

    function onClose(src,~)
        if isfield(data.emg, 'temp')
            data.emg = rmfield(data.emg, 'temp');
        end
        notify(data, 'DataChanged');
        delete(src)
    end
end

