clc;
clear;
close all;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% @file   fix_misaligned_joint_angle.m
% @brief  This script fixes LIBRA-I log files made incoherent by actuator
%         misalignment. Specifically, the values in the "TP_x[deg]" and
%         "PP_x[deg]" columns (x: "Roll", "Pitch", "J1", "J2", or "J3") will be
%         adjusted by the user-specified amount.
%
%         Context: in some experiments, the HEBI X8-16 actuator at J1 (which
%         seems to be damaged or otherwise malfunctioning) would slip and begin
%         reporting incorrect target and feedback positions.
%
% @author brice.c.aa
% @date   2025/4/11
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% SETUP

% (none)

%% BODY

% Prompt user to select a log file, then load it
[in_filename, in_filepath] = uigetfile('*.csv', 'Select the log file to be adjusted');
if isequal(in_filename, 0)
    disp('User canceled file selection');
    return;
end

in_file = fullfile(in_filepath, in_filename);
try
    data = readtable(in_file);
    disp(['Successfully loaded file: ' in_file]);
catch
    errordlg('Error loading file! Please check if it is a valid CSV format.', 'File Error');
    return;
end

% Prompt user for an adjustment
prompt = {'Value:', 'Joint (Roll, Pitch, J1, J2, or J3):'};
dlg_title = 'Adjustment Settings';
dimensions = [1 40];
default_ans = {'0', 'J1'};

answer = inputdlg(prompt, dlg_title, dimensions, default_ans);
if isempty(answer)
    disp('User canceled adjustment input');
    return;
end

adj_value = str2double(answer{1});
if isnan(adj_value)
    errordlg('Invalid adjustment value! Please enter a number.', 'Input Error');
    return;
end

adj_joint = answer{2};
if ~ismember(adj_joint, {'Roll', 'Pitch', 'J1', 'J2', 'J3'})
    errordlg('Invalid selection! Please enter one of: Roll, Pitch, J1, J2, or J3.', 'Input Error');
    return;
end

% Check each column and adjust if it matches the patterns
column_names = data.Properties.VariableNames;
col_target = ['TP_' adj_joint '_deg_'];
col_actual = ['PP_' adj_joint '_deg_'];

for i = 1:length(column_names)
    col_current = column_names{i};
    if contains(col_current, col_target) || contains(col_current, col_actual)
        data.(col_current) = data.(col_current) + adj_value;
    end
end

% Save the adjusted data to a new file
[pathstr, name, ext] = fileparts(in_filename);
out_file = fullfile(in_filepath, [name '_fixed' ext]);
writetable(data, out_file);
disp(['Fixed data saved to: ' out_file]);

%% FUNCTIONS

% (none)
