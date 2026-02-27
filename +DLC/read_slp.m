function tabledlc = read_slp(filename)

tabledlc = readtable(filename);
% remove the first column if it's just indices
tabledlc = removevars(tabledlc, {'track','frame_idx','instance_score'});

vars = tabledlc.Properties.VariableNames;
vars = replace(vars, '_score', '_likelihood');

bodyparts = replace(vars(1:3:end), '_x', '');

tabledlc.Properties.VariableNames = vars;
tabledlc.Properties.UserData = bodyparts; %bodyparts
tabledlc.Properties.Description = filename; %scorer
