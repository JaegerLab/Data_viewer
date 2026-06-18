function data=read_intan(files)
% data = read_intan(filenames)
%
% wrapper function to read_Intan_RHD2000 and read_Intan_RHS2000
% Read multiple files and concatenate data.
%
% files: a cell array of full filenames
% data: a structure with the following fields concatenated: 
%       analog_data, dig_in_data, t

if nargin==0
    [files, path] = uigetfile('*.*', 'Select EMG File(s)', 'MultiSelect', 'on');
    if isequal(files, 0), return; end
    files = fullfile(path, files);
end

if ischar(files), files = {files}; end  % ensure cell
if isstruct(files)
    files = arrayfun(@(x)fullfile(x.folder,x.name), files, 'UniformOutput', false);
end
file_num = length(files);

p = 0; % pointer for the end of data in pre-allocated space.
hd = waitbar(0, 'Please wait...', 'Name', 'Reading files');
ht = findall(hd,'Type','text');
set(ht,'Interpreter','none');

for ii=1:file_num
    fullname = files{ii};

    % disp(filename)
    [~, filename, ext] = fileparts(fullname);

    if ~exist(fullname,"file"), error('File not found'); end
    
    % auto select the corresponding reader for rhd and rhs.
    if isequal(ext,'.rhd')
        waitbar(ii/file_num, hd, sprintf('Reading: %s%s (%d/%d)', filename,ext, ii, file_num));
        data1= EMG.read_Intan_RHD2000(fullname,1);
    elseif isequal(ext,'.rhs')
        waitbar(ii/file_num, hd, sprintf('Reading: %s%s (%d/%d)', filename,ext, ii, file_num));
        data1= EMG.read_Intan_RHS2000(fullname,1);
    else
        waitbar(ii/file_num, hd, sprintf('Skipping: %s%s (%d/%d)', filename,ext, ii, file_num));
        continue
    end
    
    if p==0
        % 1st file
        % pre-allocate space to speed up reading
        data=data1;
        len = length(data1.t);
        all_len = len * file_num;
        % pre-allocated zeros (longer than needed).
        data.t = zeros(all_len, 1);
        data.t(1:len) = data1.t;
        if isfield(data1, 'analog_data')
            data.analog_data = zeros(all_len, size(data1.analog_data, 2));
            data.analog_data(1:len, :) = data1.analog_data;
            % only keep channel names as a cell array of chars
            data.analog_channels = {data1.analog_channels.custom_channel_name};
        end
        if isfield(data1, 'digital_data')
            data.digital_data = zeros(all_len, size(data1.digital_data, 2));
            data.digital_data(1:len, :) = data1.digital_data;
        end
        if isfield(data1, 'dig_in_data')
            data.dig_in_data = zeros(all_len, size(data1.dig_in_data, 2));
            data.dig_in_data(1:len, :) = data1.dig_in_data;
        end
        p = len;
    else
        % the rest of the files
        if abs(data1.t(1)-data.t(p)) > 1.1/data.sample_rate
            warning('Time not continuous');
        end
        len = length(data1.t);
        data.t(p+(1:len)) = data1.t;
        if isfield(data1, 'analog_data')
            data.analog_data(p+(1:len), :) = data1.analog_data;
        end
        if isfield(data1, 'digital_data')
            data.digital_data(p+(1:len),:) = data1.digital_data;
        end
        if isfield(data1, 'dig_in_data')
            data.dig_in_data(p+(1:len), :) = data1.dig_in_data;
        end
        p = p + len;
    end
end
if p < all_len
    % after reading, truncate un-used trailing zeros.
    data.t(p+1:all_len) = [];
    if isfield(data1, 'analog_data')
        data.analog_data(p+1:all_len, :) = [];
    end
    if isfield(data1, 'digital_data')
        data.digital_data(p+1:all_len, :) = [];
    end
    if isfield(data1, 'dig_in_data')
        data.dig_in_data(p+1:all_len, :) = [];
    end
end
data.files = files;
close(hd)