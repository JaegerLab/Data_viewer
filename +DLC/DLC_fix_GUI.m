function fig = DLC_fix_GUI(mousePos)
% GUI for auto fix DLC errors

    data = shared.SessionData.instance();
    
    %% draw GUI
    % grid 4x3
    mousePos(2)=mousePos(2)-120;
    fig = uifigure('Name', 'DLC auto fix', 'Position', [mousePos 280 220], ...
        'CloseRequestFcn', @onClose);
    grid1 = uigridlayout(fig, [4 2], "RowHeight",{30,30,30,'1x'});

    % line 1 - high pass filter
    jumpthresh = uieditfield(grid1,'numeric','Value',20, ...
                'ValueDisplayFormat','Jump thresh: %d px');
    winwidth = uieditfield(grid1, 'numeric','Value', 60, ...
                'ValueDisplayFormat','Win width: %d frame');

    % line 2 - jump search buttons
    uibutton(grid1,'Text','Last Jump', 'ButtonPushedFcn', @searchJump);
    uibutton(grid1,'Text','Next Jump', 'ButtonPushedFcn', @searchJump);

    % line 3 - buttons: preview, save as
    uibutton(grid1, 'Text','Preview', 'ButtonPushedFcn', @(~,~)preview);
    uibutton(grid1, 'Text','Save As', 'ButtonPushedFcn', @(~,~)saveAs);

    % line 4 - user instruction
    txt = sprintf(['After Preview\n' ...
        'DLC  :\t Ctrl-click: toggle mask at a data point.\n' ...
        '\t\t Shift-click toggle mask for a section.\n' ...
        'Video:\t Click and drag: Refine label position.']);
    uilabel(grid1, 'Text', txt , ...
        'Layout', matlab.ui.layout.GridLayoutOptions('Row', 4, 'Column', [1 2]));
    drawnow

    function searchJump(src, ~)
        field = data.dlc.hd.list_bodyparts.Value;
        xdata = data.dlc.table.([field '_x']);
        ydata = data.dlc.table.([field '_y']);

        indices = (abs(diff(xdata)) >= jumpthresh.Value) | ...
                  (abs(diff(ydata)) >= jumpthresh.Value);
        
        t = data.dlc.t(indices);
        if strcmp(src.Text, 'Last Jump')
            newT = t(find(t<data.currentTime, 1, "last"));
        else
            newT = t(find(t>data.currentTime, 1, "first"));
        end
        if ~isempty(newT)
            data.setTime(newT);
        end
    end

    function preview()
        if ~data.has('dlc'), return; end
        field = data.dlc.hd.list_bodyparts.Value;
        xdata = data.dlc.table.([field '_x']);
        ydata = data.dlc.table.([field '_y']);
        
        [tempX, tempY, mask] = DLC.dlc_fix_predict(xdata,ydata, ...
            jumpthresh.Value, winwidth.Value);

        data.dlc.table.temp_x = tempX;
        data.dlc.table.temp_y = tempY;
        % use likelihood as mask. good=1, bad=0;
        data.dlc.table.temp_likelihood = mask;
        
        % plot comparison
        notify(data, 'DataChanged');
    end

    function saveAs()
        if ~data.has('dlc'), return; end

        if ~ismember('temp_x', data.dlc.table.Properties.VariableNames)
            preview;
        end

        % get new body part name to save
        opt.WindowStyle = 'modal';
        opt.Interpreter = 'none';
        newName = sprintf('%s_FixJ%dW%d', ...
                data.dlc.hd.list_bodyparts.Value, jumpthresh.Value, winwidth.Value);
        newName = inputdlg('Enter new name:', 'Save As', [1 30], {newName}, opt);
        if isempty(newName), return; end
        newName = newName{1};

        % overwrite?
        overwrite = false;
        if ismember([newName '_x'], data.dlc.table.Properties.VariableNames)
            selection = questdlg('Variable exists. Overwrite?','Warning', 'Yes','No','No');
            if ~strcmp(selection,'Yes'), return; end % if no, abort
            data.dlc.table = removevars(data.dlc.table, ...
                {[newName '_x'],[newName '_y'],[newName '_likelihood']});
            % flag overwritten so the name won't be added repeatedly
            overwrite = true;
        end

        % rename temp to new name
        data.dlc.table = renamevars(data.dlc.table, ...
            {'temp_x', 'temp_y', 'temp_likelihood'}, ...
            {[newName '_x'],[newName '_y'],[newName '_likelihood']});

        removeTempPlots()

        % update list and plot
        if ~overwrite
            data.dlc.hd.list_bodyparts.Items{end+1} = newName;
        end
        data.dlc.hd.list_bodyparts.Value = newName;
        notify(data, 'DataChanged');
    end

    function removeTempPlots()
        % remove temp plots in dlc viewer
        if isfield(data.dlc.hd, 'tempXplot')
            delete(data.dlc.hd.tempXplot);
            delete(data.dlc.hd.tempYplot);
            delete(data.dlc.hd.tempXmask);
            delete(data.dlc.hd.tempYmask);
            data.dlc.hd = rmfield(data.dlc.hd, ...
                {'tempXplot','tempYplot', 'tempXmask', 'tempYmask'});
        end

        % remove temp marker drawn in video viewer
        if isfield(data.dlc.hd, 'videoTempMarker')
            delete(data.dlc.hd.videoTempMarker)
            data.dlc.hd = rmfield(data.dlc.hd, 'videoTempMarker');
        end
    end

    function onClose(src, ~)
        if data.has('dlc')
            if ismember('temp_x', data.dlc.table.Properties.VariableNames)
                data.dlc.table = removevars(data.dlc.table, {'temp_x', 'temp_y', 'temp_likelihood'});
            end
            removeTempPlots();
            notify(data, 'DataChanged');
        end
        
        data.dlc.hd = rmfield(data.dlc.hd, 'fixGUI');
        delete(src)
    end
end