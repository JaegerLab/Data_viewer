function [data,t] = read(folder, filename, n)
% Syntax:
%  [data,t] = EMG.read(folder, filename, n);
%
% Parameters:
% folder: the base path to the recordings
% filename: the last folder name of the recordings
% n: optional, default is reading all files. 
%    Specifying n only read the first n files for Intan recordings.
%    n is ignored for open ephys recordings.
%
% Example:
% folder = 'Z:\RawData\Indy\MitoPark\Reaching\IM138';
% [data,t]=EMG.read(folder, 'IM138__240705_155108');
% [data,t]=EMG.read(folder, 'IM138__240705_155108', 2);


if length(filename) < 21
    % Intan
    filelist = dir(fullfile(folder,filename,[filename,'.rh?']));
    if isempty(filelist)
        error('file not found')
    else
        fullfilename = filelist(1).name;
        if nargin ==3
            [data,info] = read_intan(fullfilename, n);
        else
            [data,info] = read_intan(fullfilename));
        end
        data = table2array(data);
        t = info.t;
    end
else
    % Open Ephys
    % go to https://github.com/open-ephys/open-ephys-matlab-tools
    % for documentations 
    session = Session(fullfile(folder, filename));
    a=session.recordNodes{1}.recordings{1}.continuous.keys;
    strname = a{1};
    ephys = session.recordNodes{1}.recordings{1}.continuous(strname);
    t = ephys.timestamps;
    data = double(ephys.samples');
end
% 
% %%
% datarange = [1:100000];
% figure;
% plot(t(datarange), data(datarange,:)+[1:24]*1000);