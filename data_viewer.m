function hfig = data_viewer(default_path)

    data = shared.SessionData.instance();
    hd = struct();
    fig = uifigure('Name', 'Mouse Data Viewer', 'Position', [100 100 400 300], ...
            'WindowStyle','alwaysontop', 'CloseRequestFcn', @onClose);
    drawnow
    if nargout ==1
        hfig = fig;
    end
    if nargin == 0
        default_path = 'E:\Openfield\data';
    end
    drawGUI(default_path)

    function drawGUI(default_path)
        grid1 = uigridlayout(fig, [3 3], 'Padding',[20 20 20 20]);
        grid1.RowHeight = {30, '1x', 30};
        grid1.ColumnWidth = {'1x', '1x', '2x'};

        % row 1 - Default folder selector
        hd.path = uieditfield(grid1, 'text', ...
            'Layout', matlab.ui.layout.GridLayoutOptions('Row', 1, 'Column', [1 2])); 
        if nargin>=1
            hd.path.Value = default_path;
        end

        uibutton(grid1, 'Text', 'Select Data Folder', 'ButtonPushedFcn', @selectFolder);

        % row 2 - Data Launcher Buttons
        subgrid1 = uigridlayout(grid1, [2 2], 'Padding', [0 0 0 0]);
        subgrid1.Layout.Column = [1 3];
        uibutton(subgrid1, 'Text', 'Video', 'ButtonPushedFcn', @launchModule);
        uibutton(subgrid1, 'Text', 'EMG', 'ButtonPushedFcn', @launchModule);
        uibutton(subgrid1, 'Text', 'DLC', 'ButtonPushedFcn', @launchModule);
        uibutton(subgrid1, 'Text', 'Gait', 'ButtonPushedFcn', @launchModule);
    
        % row 3 - Export Data
        uibutton(grid1, 'Text', 'Load', 'ButtonPushedFcn', @loadData, ...
            'Tooltip', 'to be implemented');
        uibutton(grid1, 'Text', 'Save As', 'ButtonPushedFcn', @saveAsFile, ...
            'Tooltip', 'to be implemented');
        uibutton(grid1, 'Text', 'Export to Workspace', 'ButtonPushedFcn', @export2base);
        
    end

    function selectFolder(~, ~)
        folder = uigetdir(hd.path.Value);
        if folder ~= 0
            hd.path.Value = folder;
        end
    end

    % load .mat file.
    function loadData(~,~)

    end

    % save data as a .mat file
    function saveAsFile(~,~)
        [filename, path] = uiputfile(fullfile(hd.path.Value, '*.mat'), 'Save As');
        if filename ==0, return; end

        filename = fullfile(path, filename);
        progbar = uiprogressdlg(fig,'Title','Saving', ...
            'Message','Saving', ...
            'Indeterminate','on');

        if ~exist(filename, "file")
            save(filename, "filename", "-v7.3");
        end

        % preparing data
        if data.has('emg')
            progbar.Message = 'Saving EMG';
            emg = rmfield(data.emg, {'hd'});
            save(filename,"emg","-append");
        end
        if data.has('dlc')
            progbar.Message = 'Saving DLC';
            dlc = rmfield(data.dlc, {'hd'});
            save(filename,"dlc","-append");
        end
        if data.has('gait')
            progbar.Message = 'Saving Gait';
            gait = rmfield(data.gait, {'hd'});
            save(filename,"gait","-append");
        end
        close(progbar)
        uialert(fig, ['Data saved in ' filename], 'Success','Icon','success');
        
    end

    % export data to the base workspace
    function export2base(~, ~)
        fig.WindowStyle = 'normal';
        opt.WindowStyle = 'modal';
        varname = inputdlg('Enter variable name:', 'Export Variable', [1 30], {'data'}, opt);
        fig.WindowStyle = 'alwaysontop';
        if ~isempty(varname)
            vars = evalin('base', 'who');
            if ismember(varname, vars)
                uialert(fig, 'Variable already exists.', 'Warning');
            else
                assignin('base', varname{1}, data);
                uialert(fig, ['Data exported as ' varname{1}], 'Success','Icon','success')
            end
        end
    end

    
    % main function --- launch data viewer for different modules
    function launchModule(src, ~)
        module = lower(src.Text);        
        if isfield(data.fig, module) && isgraphics(data.fig.(module), 'figure')
            % if the window's already open, do not create a new window.
            figure(data.fig.(module));
        else
            % create a new window. run the corresponding module.
            data.fig(1).(module) = eval([upper(module) '.' module '_viewer(hd.path.Value)']);
        end
    end

    function onClose(src,~)
        selection = uiconfirm(fig, "Close all windows?","Confirm", "Icon","warning");
        if ~strcmp(selection,'OK'), return; end

        
        % Close all the child viewers;
        handles = fieldnames(data.fig);
        for k=1:length(handles)
            if ishghandle(data.fig.(handles{k}), 'figure')
                try
                    close(data.fig.(handles{k})) 
                catch ME
                    warning(ME.identifier, '%s', ME.message);
                end
                % listeners are deleted in child viewer's onClose()
            end
        end

        delete(src);
    end
end
