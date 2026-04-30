function fig = emg_prep_GUI(mousePos)
% pre process window

    data = shared.SessionData.instance();
    
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

    function preview(~,~)
        ch = data.emg.hd.chanList.Value(1);

        % only process 1 channel for speed
        parameters = getParameters();
        [new_data, new_t] = ...
            EMG.emg_prep(data.emg.analog_data(:,ch), data.emg.t, parameters); 
        data.emg.temp.data = new_data;
        data.emg.temp.t = new_t;

        notify(data, 'DataChanged');
    end

    function saveClose(~,~)
        % process all channels
        parameters = getParameters();
        [processed_data, processed_t] = ...
            EMG.emg_prep(data.emg.analog_data, data.emg.t, parameters);
        data.emg.processed.data = processed_data;
        data.emg.processed.t = processed_t;
        data.emg.processed.parameters = parameters;

        data.emg.hd.datatype.Items = ["Raw","Processed"];
        data.emg.hd.datatype.Value = "Processed";

        close(fig);
    end

    function parameters = getParameters()
        % save parameters
        parameters = struct();

        if chkHighPass.Value
            parameters.HighPassFreq = editHighPass.Value;
            parameters.FiltFilt = chkFiltFilt.Value;
        end
        parameters.Rectify = chkRectify.Value;
        if chkDownSample.Value
            parameters.DownSampleRate = editDownRate.Value;
        end
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

