function [bodyparts, scorer, coords]=DLC_read_h5_bodyparts(filename)
% extract the bodyparts labels from a DeepLabCut h5 file
% syntax: 
%    bodyparts = read_dlc_h5_bodyparts(filename)
%    [bodyparts, scorer, coords] = read_dlc_h5_bodyparts(filename)
% INPUT arguments:
%   filename: a string
% OUTPUT arguments:
%   bodyparts: a cell array of strings
%   scorer: optional, a string, the name of the DLC model used.
%   coords: optional, always returns {'x','y','likelihood'}
% -----------------------------
% Li Su, 2023-12-18

% get the header string
attribute = h5readatt(filename,'/df_with_missing','non_index_axes');

% parse the string===============
% Get the strings between 'V' and '\n'
parsed_strings = regexp(attribute, '(?<=V)[^\n]+(?=\n)', 'match'); 

bodyparts = parsed_strings([2 6:end]);
scorer = parsed_strings{1};
coords = parsed_strings(3:5);

