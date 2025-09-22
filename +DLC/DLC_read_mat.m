function tabledlc=DLC_read_mat(filename)
% read .mat files
% Li Su, 2023/12/20

x=load(filename); %put the variable under x to avoid conflict

if isfield(x,'markerpos')
    % Aureli's data format
    bodyparts = fieldnames(x.markerpos)';
    marker_num = length(bodyparts);
    coords = fieldnames(x.markerpos.(bodyparts{1}))';
    row_num = length(x.markerpos.(bodyparts{1}).(coords{1}));
    varnames = strcat(repelem(bodyparts,1,3), {'_'}, repmat(coords,1,marker_num));
    arraydlc = zeros(row_num, marker_num*3);
    scorer = ''; % to do: add later if scorer is available
    for ii = 1:marker_num
        coords = fieldnames(x.markerpos.(bodyparts{ii}))';
        for jj = 1:length(coords)
            arraydlc(:,(ii-1)*3+jj)=x.markerpos.(bodyparts{ii}).(coords{jj})';
        end
    end
    tabledlc = array2table(arraydlc);
    tabledlc.Properties.VariableNames = varnames;
    tabledlc.Properties.UserData = bodyparts;
    tabledlc.Properties.Description = scorer;
else
    warndlg('File format not recognized');
    error('File format not recognized');
end



