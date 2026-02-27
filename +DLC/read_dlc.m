function tabledlc = read_dlc(filename)
% tabledlc = read_dlc(filename)
% wrapper function to read different data formats
% calls other functions

% the data format of tabledlc
% a matlab table, 
% time in the first dimension (height)
% bodyparts in the second dimension (width)
% variable names follows this order
%
% Head_x    Head_y    Head_likelihood    Neck_x    Neck_y    Neck_likelihood
% ______    ______    _______________    ______    ______    _______________
% 
% 1101.5    448.58           1           633.45    231.88           1       
% 1106.8    449.09           1           633.45    231.89           1       
% 1106.4    448.58           1           633.46    231.94           1       
% 1105.9    443.16           1           633.14    231.64           1       
% 1106.7    437.19           1            633.3    231.81           1       
% 1107.2    433.88           1           633.57    231.79           1       
% 1111.7    429.81           1           633.39    231.76           1       
% 1114.4    425.22           1           633.59    232.05           1       
%
% variable names in a cell string array 
% like {'Head_x', 'Head_y', 'Head_likelihood', 'Neck_x', 'Neck_y', ...}
% stored in tabledlc.Properties.VariableNames
%
% bodyparts are the names without _x,y,likelihood suffix and without
% repetition. it's a cell array like {'Head', 'Neck', 'Ear_L' ... }
% stored in tabledlc.Properties.UserData
%
% Only use letters, numbers and underscore for bodypart names.
%
% scorer is the name of the DLC model
% stored in tabledlc.Properties.Description


% use the file extention to decide which data format it is
[~,~,ext]=fileparts(filename);
switch ext
    % ########## to do: handle different type of data formats ###
    case '.csv'
        if contains(filename, '.analysis')
            % csv by SLEAP
            tabledlc = DLC.read_slp(filename);
        else
            % csv by DeepLabCut
            tabledlc = DLC.read_csv(filename);
        end
    case '.h5'
        % Indy's data format
        tabledlc = DLC.read_h5(filename);
    case '.mat'
        tabledlc = DLC.read_mat(filename); 
    % === todo: add your own case and reader function here =====
    % case '.ext'
    %     tabledlc = DLC_read_ext(filename);
end

