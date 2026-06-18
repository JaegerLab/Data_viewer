function data = emg_read(folder)
% Syntax:
%  data = EMG.emg_read(filename);
%

if nargin==0
    folder = uigetdir('*.*', 'Select directory containing EMG data');
    if isequal(folder, 0), return; end
end

files = dir(folder); % structure of files

if any(contains({files.name},'.rh'))
    % Intan
    data = EMG.read_intan(files);
elseif any(contains({files.name},'Record Node')) 
    % Open Ephys
    % go to https://github.com/open-ephys/open-ephys-matlab-tools
    % for documentations 
    data = EMG.read_ephys(folder);
else
    error('EMG data not found in selected folder');
end
