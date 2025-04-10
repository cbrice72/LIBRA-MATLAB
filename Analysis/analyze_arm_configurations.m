clc;
clear;
close all;

warning('off', 'MATLAB:readtable:ModifiedVarnames'); % accounted for in code

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% @file   analyze_arm_configurations.m
% @brief  Determines stable positions for LIBRA-I based on past data.
%         Specifically, this script takes in a LIBRA-I log file (CSV) and sorts
%         arm configurations (i.e., the positions all actuators were commanded)
%         into three bins based on the torque experienced by actuators.
%
% @author brice.c.aa
% @date   2025/4/1
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% SETUP

% Script options
manual_file_selection = false; % true: user searches & selects files
                               % false: user selects directory, script searches
target_positions_only = true; % true: only consider operator target positions
                              % false: also consider interpolated positions
position_tolerance = 1.0; % degrees

% Working files
mkdir('output'); % just in case
if target_positions_only
    out_file = 'output/target_arm_configs.xlsx';
else
    out_file = 'output/all_arm_configs.xlsx';
end

% Mechancial properties (HEBI X8-16)
cont_torque_limit = 16.0; % Nm
peak_torque_limit = 38.0; % Nm


%% BODY

% Initialize statistical variables
total_kept = 0;
total_points = 0;
total_stable = 0;
total_borderline = 0;
total_unstable = 0;

% Get files to process
if ~manual_file_selection
    in_files = findFilesByKeyRecursive('_continuous_log.csv');
else
    in_files = queryUserForInputs();
end

if ~isempty(in_files)
    num_files = length(in_files);

    % Iterate over selected files
    for i = 1:num_files
        fprintf('\n--- PROCESSING %d/%d ---\n', i, num_files);
        % Process a file
        [kept, points, stable, borderline, unstable] = processRobotStabilityData(in_files{i}, out_file, position_tolerance, cont_torque_limit, peak_torque_limit, target_positions_only);

        % Update statistics
        total_kept = total_kept + kept;
        total_points = total_points + points;
        total_stable = total_stable + stable;
        total_borderline = total_borderline + borderline;
        total_unstable = total_unstable + unstable;
    end
else
    fprintf('No files selected!\n');
end

fprintf('\n--- DONE ---\n');
fprintf('  Files Processed:   %d\n', length(in_files));
fprintf('  Lines Considered:  %d of %d (%.1f%%)\n', total_kept, total_points, 100*total_kept/total_points);
fprintf('  Added to Database: %d stable, %d borderline, %d unstable\n', total_stable, total_borderline, total_unstable)


%% FUNCTIONS

%{
    @brief Allows user to select a directory from which to recursively search
           for filenames containing the provided key.

    @param search_key  Filename string/substring to search for

    @return files  Cell array of file paths matching the search key
%}
function files = findFilesByKeyRecursive(search_key)
    % Let user specify top-level search directory
    start_dir = uigetdir(pwd, 'Select a directory to search recursively');

    if start_dir == 0
        disp('Directory selection canceled by user.');
        files = {};
        return;
    end

    % Perform the search (this function calls itself recursively)
    files = findFilesWithKey(start_dir, search_key);

    % Display results
    fprintf('\nSearch complete! Found %d matching files.\n', length(files));
end

%{
    @brief Recursively searches for files containing the provided string.

    @param directory   Path to the directory to search
    @param search_key  String pattern to search for

    @return files  Cell array of file paths matching the search criteria
%}
function files = findFilesWithKey(directory, search_key)
    files = {};

    % Get all items in the directory
    items = dir(directory);

    % Process each item
    for i = 1:length(items)
        % Skip '.' and '..' directories
        if strcmp(items(i).name, '.') || strcmp(items(i).name, '..')
            continue;
        end

        full_path = fullfile(directory, items(i).name);

        % If the item is a directory, recursively search it
        if items(i).isdir
            subfiles = findFilesWithKey(full_path, search_key);
            files = [files; subfiles];
        else
            % If the item is a file, check if it contains the search key
            if contains(items(i).name, search_key)
                files{end+1, 1} = full_path;
            end
        end
    end
end

%{
    @brief Prompts the user to select multiple input files for processing.

    @returns in_files  Cell array of all selected files
%}
function in_files = queryUserForInputs()
    in_files = {};
    last_dir = '';

    % Loop until user cancels selection, allowing user to specify files from
    % multiple directories
    while true
        % Prompt user to select file(s) for processing
        [files, path] = uigetfile({'*.*', 'All Files (*.*)'}, ...
            'Select Files', last_dir, ...
            'MultiSelect', 'on');

        % Check if the user canceled the selection
        if isequal(files, 0)
            break;
        end

        % Update loop variables
        in_files = [in_files, fullfile(path, files)];
        last_dir = path; % store directory path for consistent selection
    end

    % Ensure we get a cell array even if only one file is selected
    if ischar(in_files)
        in_files = {in_files};
    end
end

%{
    @brief Main function to process robot stability data. Reads input file,
           filters data based on position changes, categorizes configurations,
           and saves results.

    @param in_file          Path to the input data file (CSV or Excel)
    @param out_file         Path to save the results (Excel file)
    @param pos_tolerance    Minimum difference between consecutive positions (in deg)
    @param cont_torque_lim  Continuous torque limit for all actuators (in Nm)
    @param peak_torque_lim  Peak torque limit for all actuators (in Nm)
    @param target_pos_only  Whether non-operator-input logged positions should
                            be filtered (i.e., positions interpolated by the app)

    @return num_kept        Number of configurations that passed the filtering process
    @return num_total       Total number of configurations processed
    @return num_stable      Count of newly categorized stable configurations
    @return num_borderline  Count of newly categorized borderline configurations
    @return num_unstable    Count of newly categorized unstable configurations
%}
function [num_kept, num_total, num_stable, num_borderline, num_unstable] = processRobotStabilityData(in_file, out_file, pos_tolerance, cont_torque_lim, peak_torque_lim, target_pos_only)
    % Set certain return variables in case of early function exit
    num_stable = 0;
    num_borderline = 0;
    num_unstable = 0;

    % (1a) Read the input file (valid filetypes: CSV, Excel)
    try
        [~, ~, file_ext] = fileparts(in_file);
        if strcmpi(file_ext, '.csv')
            data = readtable(in_file, 'FileType', 'text', 'Delimiter', ',');
        else
            data = readtable(in_file);
        end
        fprintf('Data loaded successfully from "%s"\n', in_file);
    catch e
        error('Error loading file: "%s"', e.message);
    end

    fprintf('[1/4] Loaded %d data points from file.\n', height(data));

    % (1b) Find required columns
    pos_col_names = {'TP_Roll_deg_', 'TP_Pitch_deg_', 'TP_J1_deg_', 'TP_J2_deg_', 'TP_J3_deg_'};
    torque_col_names = {'PT_Roll_Nm_', 'PT_Pitch_Nm_', 'PT_J1_Nm_', 'PT_J2_Nm_', 'PT_J3_Nm_'};

    pos_cols = findMatchingColumns(data, pos_col_names);
    torque_cols = findMatchingColumns(data, torque_col_names);

    if length(pos_cols) < 5 || length(torque_cols) < 5
        error('Required columns ("TP_*", "PT_*") not found!');
    end

    % (2) Filter for unique configurations
    fprintf('[2/4] Isolating unique entries...    ');
    filtered_data = processData(data, pos_cols, torque_cols, pos_tolerance, target_pos_only);
    
    num_kept = height(filtered_data);
    num_total = height(data);

    if isempty(filtered_data)
        fprintf('\n(!) No data to add after filtering, skipping further processing.\n');
        return;
    end

    fprintf('%d of %d data points remain (%.1f%%).\n', ...
        num_kept, num_total, 100*num_kept/num_total);

    % (3) Categorize configurations
    fprintf('[3/4] Categorizing configurations... ');
    [stable, borderline, unstable] = categorizeConfigurations(filtered_data, ...
        torque_cols, cont_torque_lim, peak_torque_lim);

    num_stable = height(stable);
    num_borderline = height(borderline);
    num_unstable = height(unstable);

    fprintf('count by bin: %d stable, %d borderline, %d unstable.\n', ...
        num_stable, num_borderline, num_unstable);

    % (4) Check for existing configuration output file to avoid duplicates
    fprintf('[4/4] Checking existing database...  ');
    if exist(out_file, 'file')
        existing_db = readExistingDatabase(out_file);
        [stable, borderline, unstable] = removeDuplicates(existing_db, ...
            stable, borderline, unstable, pos_cols);

        num_stable = height(stable);
        num_borderline = height(borderline);
        num_unstable = height(unstable);

        fprintf('new entries:  %d stable, %d borderline, %d unstable.\n', ...
            num_stable, num_borderline, num_unstable);
    else
        fprintf('"%s" not found; adding all entries.\n', out_file);
    end

    % Sort configurations and save to file
    stable = sortConfigsByPos(stable, pos_cols);
    borderline = sortConfigsByPos(borderline, pos_cols);
    unstable = sortConfigsByPos(unstable, pos_cols);

    if saveConfigs(out_file, stable, borderline, unstable)
        % Only do the following if a file was newly generated

        % Apply conditional formatting to torque cells
        applyTorqueCellColoring(out_file, 'All Configurations', ...
            strcat('mean_', torque_col_names), cont_torque_lim, peak_torque_lim);
    end
end

%{
    @brief Finds exact matching columns in the data table.

    @param data           Table containing the data to be processed
    @param required_cols  Cell array of column names to find in the data table

    @return matched_cols  Cell array of column names that were found in the data
%}
function matched_cols = findMatchingColumns(data, required_cols)
    col_titles = data.Properties.VariableNames;
    matched_cols = cell(1, length(required_cols));

    for i = 1:length(required_cols)
        % Look for exact column name match
        match = strcmp(col_titles, required_cols{i});

        if any(match)
            matched_cols{i} = required_cols{i};
        end
    end

    % Remove empty cells (columns not found)
    matched_cols = matched_cols(~cellfun('isempty', matched_cols));
end

%{
    @brief Processes log data by filtering repeated target position values and
           averaging torque values for similar position configurations.

    @param data             Table containing the robot data
    @param pos_cols         Cell array of column names for position values
    @param torque_cols      Cell array of column names for torque values
    @param pos_tolerance    Minimum difference between consecutive positions (in deg)
    @param target_pos_only  Whether non-operator-input logged positions should
                            be filtered (i.e., positions interpolated by the app)

    @return filtered_data  Table with processed data
%}
function filtered_data = processData(data, pos_cols, torque_cols, pos_tolerance, target_pos_only)
    % Remove unnecessary precision
    threshold = 2; % 1e-2
    data{:, pos_cols} = round(data{:, pos_cols}, threshold);

    % Remove rows with non-integer position values, as these represent the
    % interpolated trajectory between user-input position commands
    if target_pos_only
        data(any(mod(data{:, pos_cols}, 1) ~= 0, 2), :) = [];
    end

    if isempty(data)
        filtered_data = table();
        return; % no valid data remaining after filtering, return empty table
    end

    % Compute average torques for each unique position set
    % (this also consolidates the dataset and prepends torque columns with "mean_")
    grouped_data = varfun(@mean, data, 'InputVariables', torque_cols, 'GroupingVariables', pos_cols);

    % Filter position values based on a specified range
    % (note: since we are diff-ing data, the first row will never be counted so
    %        we have to explicitly include it)
    if height(grouped_data) == 1
        diffs = true;
    else
        diffs = [true; any(abs(diff(grouped_data{:, pos_cols})) > pos_tolerance, 2)];
    end

    filtered_data = grouped_data(diffs, :);

    % Sort before returning
    filtered_data = sortrows(filtered_data, pos_cols);
end

%{
    @brief Categorizes robot configurations into stable, borderline, and unstable
           based on torque values compared to continuous and peak limits.

    @param data         Table containing the filtered robot data
    @param torque_cols  Cell array of column names for torque values
    @param cont_lim     Continuous torque limit for all actuators (in Nm)
    @param peak_lim     Peak torque limit for all actuators (in Nm)

    @return stable      Table of configurations within torque limits
    @return borderline  Table of configurations exceeding continuous BUT NOT peak limits
    @return unstable    Table of configurations exceeding peak torque limits
%}
function [stable, borderline, unstable] = categorizeConfigurations(data, torque_cols, cont_lim, peak_lim)
    num_rows = height(data);
    category = zeros(num_rows, 1); % 0: stable, 1: borderline, 2: unstable

    for i = 1:num_rows
        % Check torque values against limits
        for j = 1:length(torque_cols)
            torque = abs(data.(['mean_', torque_cols{j}])(i));

            if torque > peak_lim
                % Exceeds peak limit - unstable
                category(i) = 2;
                break;
            elseif torque > cont_lim && category(i) < 1
                % Exceeds continuous limit - borderline
                category(i) = 1;
            end
        end
    end

    % Split data based on category
    stable = data(category == 0, :);
    borderline = data(category == 1, :);
    unstable = data(category == 2, :);
end

%{
    @brief Sorts configurations by all position columns in ascending order.
           Primary sort is by first column, then secondary sort by second column,
           and so on.

    @param data      Table containing robot configurations to be sorted
    @param pos_cols  Cell array of column names for position values

    @return data  Sorted table with configurations ordered by all position columns
%}
function data = sortConfigsByPos(data, pos_cols)
    if ~isempty(data) && height(data) > 1
        % Create sort matrix for all position columns
        sort_mat = zeros(height(data), length(pos_cols));
        for i = 1:length(pos_cols)
            sort_mat(:, i) = data.(pos_cols{i});
        end

        % Sort data based on all position columns
        [~, idx] = sortrows(sort_mat);
        data = data(idx, :);
    end
end

%{
    @brief Reads existing arm configurations from a previously saved Excel file.

    @param filepath  Path to the Excel file containing existing configurations

    @return data  Table containing all previously saved configurations
%}
function data = readExistingDatabase(filepath)
    try
        data = readtable(filepath, 'Sheet', 'All Configurations');
    catch
        % If file doesn't exist or sheet not found, return empty table
        data = table();
    end
end

%{
    @brief Removes duplicate configurations between existing and new data.

    @param existing_data  Table containing previously saved configurations
    @param stable         Table of newly identified stable configurations
    @param borderline     Table of newly identified borderline configurations
    @param unstable       Table of newly identified unstable configurations
    @param pos_cols       Cell array of column names for position values

    @return stable      Updated table with duplicates removed
    @return borderline  Updated table with duplicates removed
    @return unstable    Updated table with duplicates removed
%}
function [stable, borderline, unstable] = removeDuplicates(existing_data, stable, borderline, unstable, pos_cols)
    if isempty(existing_data)
        return;
    end

    % Define helper function to find and remove duplicates
    function newData = removeDupsFromExisting(newData, existingData, posCols)
        if isempty(newData) || isempty(existingData)
            return;
        end

        to_remove = false(height(newData), 1);

        for ih = 1:height(newData)
            for jh = 1:height(existingData)
                matching = true;

                % Check if all position values match
                for k = 1:length(posCols)
                    if abs(newData.(posCols{k})(ih)-existingData.(posCols{k})(jh)) > 0.01
                        matching = false;
                        break;
                    end
                end

                if matching
                    to_remove(ih) = true;
                    break;
                end
            end
        end

        newData = newData(~to_remove, :);
    end

    % Check if position columns exist in existing config
    existing_pos_cols = pos_cols;
    for i = length(pos_cols):-1:1
        if ~ismember(pos_cols{i}, existing_data.Properties.VariableNames)
            existing_pos_cols(i) = [];
        end
    end

    if isempty(existing_pos_cols)
        % Try to find equivalent columns
        possible_matches = existing_data.Properties.VariableNames(contains(existing_data.Properties.VariableNames, {'TP_', 'Roll', 'Pitch', 'J1', 'J2', 'J3'}) & ...
            contains(existing_data.Properties.VariableNames, {'deg', '[deg]'}, 'IgnoreCase', true));
        if length(possible_matches) >= 5
            existing_pos_cols = possible_matches(1:5);
        else
            % Can't find matching columns
            return;
        end
    end

    % Remove duplicates from each category
    stable = removeDupsFromExisting(stable, existing_data, existing_pos_cols);
    borderline = removeDupsFromExisting(borderline, existing_data, existing_pos_cols);
    unstable = removeDupsFromExisting(unstable, existing_data, existing_pos_cols);
end

%{
    @brief Saves robot configurations to an Excel file with multiple sheets.

    @param filepath    Path where the Excel file will be saved
    @param stable      Table of stable configurations
    @param borderline  Table of borderline configurations
    @param unstable    Table of unstable configurations

    @returns file_write_complete  Whether or not a file was newly created (helps with file post-processing)
%}
function file_write_complete = saveConfigs(filepath, stable, borderline, unstable)
    % Initialize return value
    file_write_complete = false;

    % Check inputs
    if isempty(stable) && isempty(borderline) && isempty(unstable)
        fprintf('No [new] configurations to save.\n');
        return;
    end

    try
        % Combine all configurations
        data_to_write = [stable; borderline; unstable];

        % Create stability label column
        stability = cell(height(data_to_write), 1);
        if ~isempty(stable)
            stability(1:height(stable)) = {'Stable (within limits)'};
        end

        if ~isempty(borderline)
            stability(height(stable)+(1:height(borderline))) = {'Borderline (exceeds continuous limits)'};
        end

        if ~isempty(unstable)
            stability(height(stable)+height(borderline)+(1:height(unstable))) = {'Unstable (exceeds peak limits)'};
        end

        % Add stability labels to data, rewriting GroupCount (we don't need it)
        data_to_write.GroupCount = stability;
        data_to_write.Properties.VariableNames{'GroupCount'} = 'Stability';

        % Save combined table to primary sheet
        writetable(data_to_write, filepath, 'Sheet', 'All Configurations', 'WriteMode', 'append');

        % Save individual tables to separate sheets
        if ~isempty(stable)
            writetable(stable, filepath, 'Sheet', 'Stable', 'WriteMode', 'append');
        end

        if ~isempty(borderline)
            writetable(borderline, filepath, 'Sheet', 'Borderline', 'WriteMode', 'append');
        end

        if ~isempty(unstable)
            writetable(unstable, filepath, 'Sheet', 'Unstable', 'WriteMode', 'append');
        end

        file_write_complete = true; % write is only complete if all writetables succeeded
        fprintf('Configurations saved to "%s"\n', filepath);
    catch e
        error('Error saving configurations: %s', e.message);
    end
end

%{
    @brief Applies color formatting to torque value cells in an Excel sheet 
           based on predefined torque limits.

    @param filepath     String specifying the path to the Excel file
    @param sheet_name   String specifying the name of the target sheet
    @param torque_cols  Cell array of column names containing torque values
    @param cont_lim     Continuous torque limit (in Nm)
    @param peak_lim     Peak torque limit (in Nm)
%}
function applyTorqueCellColoring(filepath, sheet_name, torque_cols, cont_lim, peak_lim)
    % Open Excel file
    excel = actxserver('Excel.Application');
    excel.Visible = false; % true: visible for debugging | false: silent execution
    try
        filepath = fullfile(pwd, filepath); % excel needs a full filepath
        workbook = excel.Workbooks.Open(filepath);
        sheet = workbook.Sheets.Item(sheet_name);
        data = sheet.UsedRange.Value; % read the whole sheet

        if isempty(data)
            error("Sheet data is empty or unreadable!");
        end

        % Find column indices for torque values
        torque_idxs = find(ismember(data(1, :), torque_cols));

        % Define colors (RGB)
        color_g = [198, 239, 206]; % stable
        color_y = [255, 235, 156]; % borderline
        color_r = [255, 199, 206]; % unstable

        % Apply coloring to relevant cells
        for row = 2:size(data, 1) % skip header row
            for col = torque_idxs
                torque = abs(data{row, col}); % ensure absolute value

                % Get current cell
                excel_cell_idx = strcat(intToExcelCol(col), num2str(row));
                cell = get(sheet, 'Range', excel_cell_idx);

                if torque >= peak_lim
                    cell.Interior.Color = rgbToExcelColor(color_r);
                elseif torque >= cont_lim
                    cell.Interior.Color = rgbToExcelColor(color_y);
                else
                    cell.Interior.Color = rgbToExcelColor(color_g);
                end
            end
        end

        % Save and close
        workbook.Save;
        workbook.Close;
        excel.Quit;
        delete(excel);
    catch e
        excel.Quit;
        delete(excel);
        error('Error applying cell coloring: %s', e.message);
    end
end

%{
    @brief Converts matrix column number(s) into equivalend Excel column
           letter(s).

    @param num  Matrix column number

    @return str  Excel column letter
%}
function str = intToExcelCol(num)
    raw = 'A':'Z';
    str = raw(1+rem(num-1, 26));
    tmp = fix((num - 1)/26);
    while any(tmp)
        str = [raw(1+rem(tmp-1, 26)), str]; % #ok<AGROW>
        tmp = fix((tmp - 1)/26);
    end
    str = string(str);
end

%{
    @brief Converts an RGB color value to an Excel-compatible color index.

    @param rgb  Array containing RGB values as [R, G, B], each in the range 0-255

    @return excel_color  Integer representing the closest matching Excel color index
%}
function excel_color = rgbToExcelColor(rgb)
    excel_color = rgb(1) + 256 * rgb(2) + 65536 * rgb(3);
end
