function [new_data, new_t] = emg_prep(data, t, options)
% pre-process EMG data, high-pass, rectify, smooth then downsample
% Syntax
%  [new_data, new_t] = emg_prep(data, t, options)
%
% Parameters:
%  emg: 2-D array, each channel is vertical vector
%  t: 1-D array, time axis.
%  options: a structure with the following optional field
%       HighPassFreq: a number. frequency to high pass filter
%       FiltFilt: boolean. true uses filtfilt, false (default) uses filter
%       Rectify: boolean. true or false(default)
%       DownSampleRate: a number. frequency to down sample to
% Outputs:
%  new_data: processed data. data at negative time are truncated.
%  new_t: down sampled t. negative time are truncated.
% 
% Li Su. 2/27/2026

%%
fs = 1/mean(diff(t));
new_data = data;
progbar = uiprogressdlg(fig,'Title','Processing', ...
    'Message','Filtering', ...
    'Indeterminate','on');
drawnow

if isfield(options, 'HighPassFreq')
    fcut = options.HighPassFreq;
    parameters.filter = designfilt('highpassiir', 'FilterOrder', 4, ...
                   'HalfPowerFrequency', fcut, 'SampleRate', fs);
    if isfield(options, 'FiltFilt') && options.filtfilt
        new_data = filtfilt(parameters.filter, new_data);
    else
        new_data = filter(parameters.filter, new_data); 
    end
end

if isfield(options, 'Rectify') && options.Rectify
    new_data = abs(new_data);
end

if isfield(options, 'DownSampleRate')
    % smooth
    progbar.Message = 'Smoothing';
    down_fs = options.DownSampleRate;
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

