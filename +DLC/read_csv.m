function tabledlc = read_csv (filename)
% read csv format created by DeepLabCut
% Li Su, 2023/12/18

opts = delimitedTextImportOptions;
opts.DataLines = [1 3];
txt = readmatrix(filename,opts);
headers = genvarname(strcat(txt(2,:), {'_'}, txt(3,:)));

% read data
tabledlc=readtable(filename, 'Headerlines',3);

% remove the first column if it's just indices
if isequal(txt{3,1},'coords')
    tabledlc(:,1)=[];
    headers(1)=[];
    txt(:,1)=[];
end

tabledlc.Properties.VariableNames = headers;
tabledlc.Properties.UserData = unique(txt(2,:),'stable'); %bodyparts
tabledlc.Properties.Description = filename; %scorer
