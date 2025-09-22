function data=read_intan(files)
% data = read_intan(filenames)
%
% wrapper function to read_Intan_RHD2000
% Read multiple files and conbine data.


if ischar(files), files = {files}; end  % ensure cell
if isstruct(files)
    files = arrayfun(@(x)fullfile(x.folder,x.name), files, 'UniformOutput', false);
end
file_num = length(files);

p = 0; % pointer for the end of data in pre-allocated space.
for ii=1:file_num
    tic
    filename = files{ii};
    disp(filename)
    if ~exist(filename,"file"), error('File not found'); end
    
    [~,~,ext] = fileparts(filename);
    if isequal(ext,'.rhd')
        data1= EMG.read_Intan_RHD2000(filename,1);
    elseif isequal(ext,'.rhs')
        data1= EMG.read_Intan_RHS2000(filename,1);
    else
        error('Unrecognized file type.')
    end
    
    if ii==1
        % 1st file
        % pre-allocate space for speed up reading
        data=data1;
        len = length(data1.t);
        all_len = len * file_num;
        % pre-allocated zeros (longer than needed).
        data.t = zeros(all_len, 1);
        data.t(1:len) = data1.t;
        if isfield(data1, 'analog_data')
            data.analog_data = zeros(all_len, size(data1.analog_data, 2));
            data.analog_data(1:len, :) = data1.analog_data;
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
    if ii == file_num
        % last file, truncate un-used trailing zeros.
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
    
end
