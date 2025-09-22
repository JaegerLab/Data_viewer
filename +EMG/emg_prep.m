function [emg_processed, t_processed] = emg_prep(emg, t, target_fs)
% pre-process EMG data, high-pass, rectify, smooth then downsample
% Syntax
%  [emg_processed, t_processed] = prep(emg, t, target_fs)
%
% Parameters:
%  emg: 2-D array, each channel is vertical vector
%  t: 1-D array, time axis.
%  target_fs: optional, the target sampling rate after down-sampling.
%      if omited, the function do not smooth or downsample.
% 
% Li Su. 6/27/2025

%%
fs = 1/mean(diff(t));

%%
fcut = 500;
d = designfilt('highpassiir', 'FilterOrder', 4, ...
               'HalfPowerFrequency', fcut, 'SampleRate', fs);
emg = filter(d, emg); 


% rectify
emg = abs(emg);


%%
if nargin == 2
    % truncate (discard negative time)
    emg_processed = emg(t>=0,:);
    t_processed = t(t>=0);
else 
    % smooth
    downsample_factor = round(fs / target_fs);
    win_width = round(2.5 * downsample_factor);
    emg = shared.fastsmooth(emg, win_width,1,1);

    % truncate and downsample
    emg_processed = downsample(emg(t>=0,:), downsample_factor);
    t_processed = downsample(t(t>=0), downsample_factor);
end