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

% Working files
%inputFilePath = 'C:\Users\brice\Desktop\Projects\LIBRA\Archive\2024-11-28 Upgraded LIBRA-I Test (2nd attempt)\log\2024年11月25日_16時27分09秒_continuous_log.csv';
outputFilePath = 'arm_configurations.xlsx';

% Script options
positionTolerance = 1.0; % position tolerance, degrees

% Mechancial properties (HEBI X8-16)
contTorqueLimit = 16.0; % continuous torque limit, Nm
peakTorqueLimit = 38.0; % peak torque limit, Nm


%% BODY

% Initialize statistical variables
total_kept = 0;
total_points = 0;
total_stable = 0;
total_borderline = 0;
total_unstable = 0;

% Get files to process
inputFilePaths = queryUserForInputs();

if ~isempty(inputFilePaths)
    fileCount = length(inputFilePaths);

    % Iterate over selected files
    for i = 1:fileCount
        fprintf('\n--- PROCESSING %d/%d ---\n', i, fileCount);
        % Process a file
        [kept, points, stable, borderline, unstable] = processRobotStabilityData(inputFilePaths{i}, outputFilePath, positionTolerance, contTorqueLimit, peakTorqueLimit);

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
fprintf('  Files Processed:   %d\n', length(inputFilePaths));
fprintf('  Lines Considered:  %d of %d (%.1f%%)\n', total_kept, total_points, 100*total_kept/total_points);
fprintf('  Added to Database: %d stable, %d borderline, %d unstable\n', total_stable, total_borderline, total_unstable)


%% FUNCTIONS

%{
    @brief Prompts the user to select multiple input files for processing.

    @returns inputFilePaths Cell array of all selected files
%}
function inputFilePaths = queryUserForInputs()
    inputFilePaths = {};
    lastDirPath = '';

    % Loop until user cancels selection, allowing user to specify files from
    % multiple directories
    while true
        % Prompt user to select file(s) for processing
        [files, path] = uigetfile({'*.*', 'All Files (*.*)'}, ...
            'Select Files', lastDirPath, ...
            'MultiSelect', 'on');

        % Check if the user canceled the selection
        if isequal(files, 0)
            break;
        end

        % Update loop variables
        inputFilePaths = [inputFilePaths, fullfile(path, files)];
        lastDirPath = path; % store directory path for consistent selection
    end

    % Ensure we get a cell array even if only one file is selected
    if ischar(inputFilePaths)
        inputFilePaths = {inputFilePaths};
    end
end

%{
    @brief Main function to process robot stability data. Reads input file,
           filters data based on position changes, categorizes configurations,
           and saves results.

    @param inputFilePath     Path to the input data file (CSV or Excel)
    @param outputFilePath    Path to save the results (Excel file)
    @param positionTolerance Tolerance for position changes (in degrees)
    @param contTorqueLimit   Continuous torque limit for all actuators (in Nm)
    @param peakTorqueLimit   Peak torque limit for all actuators (in Nm)

    @return keptCount       Number of configurations that passed the filtering process
    @return totalCount      Total number of configurations processed
    @return stableCount     Count of newly categorized stable configurations
    @return borderlineCount Count of newly categorized borderline configurations
    @return unstableCount   Count of newly categorized unstable configurations
%}
function [keptCount, totalCount, stableCount, borderlineCount, unstableCount] = processRobotStabilityData(inputFilePath, outputFilePath, positionTolerance, contTorqueLimit, peakTorqueLimit)
    % Set certain return variables in case of early function exit
    stableCount = 0;
    borderlineCount = 0;
    unstableCount = 0;

    % (1a) Read the input file (valid filetypes: CSV, Excel)
    try
        [~, ~, fileExt] = fileparts(inputFilePath);
        if strcmpi(fileExt, '.csv')
            data = readtable(inputFilePath, 'FileType', 'text', 'Delimiter', ',');
        else
            data = readtable(inputFilePath);
        end
        fprintf('Data loaded successfully from "%s"\n', inputFilePath);
    catch e
        error('Error loading file: "%s"', e.message);
    end

    fprintf('(1) Loaded %d data points from file.\n', height(data));

    % (1b) Find required columns
    requiredPositionCols = {'TP_Roll_deg_', 'TP_Pitch_deg_', 'TP_J1_deg_', 'TP_J2_deg_', 'TP_J3_deg_'};
    requiredTorqueCols = {'PT_Roll_Nm_', 'PT_Pitch_Nm_', 'PT_J1_Nm_', 'PT_J2_Nm_', 'PT_J3_Nm_'};

    positionCols = findMatchingColumns(data, requiredPositionCols);
    torqueCols = findMatchingColumns(data, requiredTorqueCols);

    if length(positionCols) < 5 || length(torqueCols) < 5
        error('Required columns ("TP_*", "PT_*") not found!');
    end

    % (2) Filter for unique configurations
    fprintf('(2) Scanning data for unique entries...\n');
    filteredData = consolidateData(data, positionCols, torqueCols, positionTolerance);

    keptCount = height(filteredData);
    totalCount = height(data);

    fprintf('    ... %d of %d data points remain (%.1f%%).\n', ...
        keptCount, totalCount, 100*keptCount/totalCount);

    if isempty(filteredData)
        fprintf('(~) No data to add after filtering, skipping further processing.\n');
        return;
    end

    % (3) Categorize configurations
    fprintf('(3) Categorizing configurations based on torque limits...\n');
    contLimits = repmat(contTorqueLimit, 1, 5); % Same limit for all actuators
    peakLimits = repmat(peakTorqueLimit, 1, 5); % Same limit for all actuators

    [stableConfig, borderlineConfig, unstableConfig] = categorizeConfigurations(filteredData, ...
        torqueCols, contLimits, peakLimits);

    stableCount = height(stableConfig);
    borderlineCount = height(borderlineConfig);
    unstableCount = height(unstableConfig);

    fprintf('    ... initial stats: %d stable, %d borderline, %d unstable.\n', ...
        stableCount, borderlineCount, unstableCount);

    % (4) Check for existing configuration output file to avoid duplicates
    fprintf('(4) Checking for existing configuration database to avoid duplicates...\n');
    if exist(outputFilePath, 'file')
        existingConfig = readExistingDatabase(outputFilePath);
        [stableConfig, borderlineConfig, unstableConfig] = removeDuplicates(existingConfig, ...
            stableConfig, borderlineConfig, unstableConfig, positionCols);

        stableCount = height(stableConfig);
        borderlineCount = height(borderlineConfig);
        unstableCount = height(unstableConfig);

        fprintf('    ... new entries: %d stable, %d borderline, %d unstable.\n', ...
            stableCount, borderlineCount, unstableCount);
    else
        fprintf('    ... "%s" not found; adding all entries.\n', outputFilePath);
    end

    % Sort configurations and save to file
    stableConfig = sortConfigsByPos(stableConfig, positionCols);
    borderlineConfig = sortConfigsByPos(borderlineConfig, positionCols);
    unstableConfig = sortConfigsByPos(unstableConfig, positionCols);

    saveConfigs(outputFilePath, stableConfig, borderlineConfig, unstableConfig);

    % Apply conditional formatting to torque cells
    applyTorqueCellColoring(outputFilePath, 'All Configurations', ...
        strcat('mean_', requiredTorqueCols), contTorqueLimit, peakTorqueLimit);
end

%{
    @brief Finds exact matching columns in the data table.

    @param data         Table containing the data to be processed
    @param requiredCols Cell array of column names to find in the data table

    @return matchedCols Cell array of column names that were found in the data
%}
function matchedCols = findMatchingColumns(data, requiredCols)
    tableVars = data.Properties.VariableNames;
    matchedCols = cell(1, length(requiredCols));

    for i = 1:length(requiredCols)
        % Look for exact column name match
        exactMatch = strcmp(tableVars, requiredCols{i});

        if any(exactMatch)
            matchedCols{i} = requiredCols{i};
        end
    end

    % Remove empty cells (columns not found)
    matchedCols = matchedCols(~cellfun('isempty', matchedCols));
end

%{
    @brief Processes log data by filtering repeated target position values and
           averaging torque values for similar position configurations.

    @param data              Table containing the robot data
    @param positionCols      Cell array of column names for position values
    @param torqueCols        Cell array of column names for torque values
    @param positionTolerance Minimum difference between consecutive positions

    @return filteredData Table with processed data
%}
function filteredData = consolidateData(data, positionCols, torqueCols, positionTolerance)
    % Round miniscule position values to the nearest integer (basically 0)
    threshold = 7; % 1E7
    data{:, positionCols} = round(data{:, positionCols}, threshold);

    % Remove rows with non-integer position values, as these represent the
    % automatically-calculated trajectory between user-input position commands
    data(any(mod(data{:, positionCols}, 1) ~= 0, 2), :) = [];

    if isempty(data)
        filteredData = table();
        return; % no valid data remaining after filtering, return empty table
    end

    % Compute average torques for each unique position set
    % (this also consolidates the dataset and prepends torque columns with "mean_")
    groupedData = varfun(@mean, data, 'InputVariables', torqueCols, 'GroupingVariables', positionCols);

    % Filter position values based on a specified range (if "1", no change)
    diffs = [true; any(abs(diff(groupedData{:, positionCols})) > positionTolerance, 2)];

    if isempty(data)
        filteredData = table();
        return; % no significant position changes detected, return empty table
    end

    filteredData = groupedData(diffs, :);

    % Sort before returning
    filteredData = sortrows(filteredData, positionCols);
end

%{
    @brief Categorizes robot configurations into stable, borderline, and unstable
           based on torque values compared to continuous and peak limits.

    @param data       Table containing the filtered robot data
    @param torqueCols Cell array of column names for torque values
    @param contLimits Array of continuous torque limits for each joint (in Nm)
    @param peakLimits Array of peak torque limits for each joint (in Nm)

    @return stableConfigs     Table of configurations within torque limits
    @return borderlineConfigs Table of configurations exceeding continuous but not peak limits
    @return unstableConfigs   Table of configurations exceeding peak torque limits
%}
function [stableConfigs, borderlineConfigs, unstableConfigs] = categorizeConfigurations(data, torqueCols, contLimits, peakLimits)
    numRows = height(data);
    category = zeros(numRows, 1); % 0: stable, 1: borderline, 2: unstable

    for i = 1:numRows
        % Check torque values against limits
        for j = 1:length(torqueCols)
            torqueVal = abs(data.(['mean_', torqueCols{j}])(i));

            if torqueVal > peakLimits(j)
                % Exceeds peak limit - unstable
                category(i) = 2;
                break;
            elseif torqueVal > contLimits(j) && category(i) < 1
                % Exceeds continuous limit - borderline
                category(i) = 1;
            end
        end
    end

    % Split data based on category
    stableConfigs = data(category == 0, :);
    borderlineConfigs = data(category == 1, :);
    unstableConfigs = data(category == 2, :);
end

%{
    @brief Sorts configurations by all position columns in ascending order.
           Primary sort is by first column, then secondary sort by second column,
           and so on.

    @param data         Table containing robot configurations to be sorted
    @param positionCols Cell array of column names for position values

    @return data Sorted table with configurations ordered by all position columns
%}
function data = sortConfigsByPos(data, positionCols)
    if ~isempty(data) && height(data) > 1
        % Create sort matrix for all position columns
        sortMatrix = zeros(height(data), length(positionCols));
        for i = 1:length(positionCols)
            sortMatrix(:, i) = data.(positionCols{i});
        end

        % Sort data based on all position columns
        [~, idx] = sortrows(sortMatrix);
        data = data(idx, :);
    end
end

%{
    @brief Reads existing arm configurations from a previously saved Excel file.

    @param configFilePath Path to the Excel file containing existing configurations

    @return existingConfigs Table containing all previously saved configurations
%}
function existingConfigs = readExistingDatabase(configFilePath)
    try
        existingConfigs = readtable(configFilePath, 'Sheet', 'All Configurations');
    catch
        % If file doesn't exist or sheet not found, return empty table
        existingConfigs = table();
    end
end

%{
    @brief Removes duplicate configurations between existing and new data.

    @param existingConfigs   Table containing previously saved configurations
    @param stableConfigs     Table of newly identified stable configurations
    @param borderlineConfigs Table of newly identified borderline configurations
    @param unstableConfigs   Table of newly identified unstable configurations
    @param positionCols      Cell array of column names for position values

    @return stableConfigs     Updated table with duplicates removed
    @return borderlineConfigs Updated table with duplicates removed
    @return unstableConfigs   Updated table with duplicates removed
%}
function [stableConfigs, borderlineConfigs, unstableConfigs] = removeDuplicates(existingConfigs, stableConfigs, borderlineConfigs, unstableConfigs, positionCols)
    if isempty(existingConfigs)
        return;
    end

    % Define helper function to find and remove duplicates
    function newData = removeDupsFromExisting(newData, existingData, posCols)
        if isempty(newData) || isempty(existingData)
            return;
        end

        toRemove = false(height(newData), 1);

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
                    toRemove(ih) = true;
                    break;
                end
            end
        end

        newData = newData(~toRemove, :);
    end

    % Check if position columns exist in existing config
    existingPosCols = positionCols;
    for i = length(positionCols):-1:1
        if ~ismember(positionCols{i}, existingConfigs.Properties.VariableNames)
            existingPosCols(i) = [];
        end
    end

    if isempty(existingPosCols)
        % Try to find equivalent columns
        possiblePosCols = existingConfigs.Properties.VariableNames(contains(existingConfigs.Properties.VariableNames, {'TP_', 'Roll', 'Pitch', 'J1', 'J2', 'J3'}) & ...
            contains(existingConfigs.Properties.VariableNames, {'deg', '[deg]'}, 'IgnoreCase', true));
        if length(possiblePosCols) >= 5
            existingPosCols = possiblePosCols(1:5);
        else
            % Can't find matching columns
            return;
        end
    end

    % Remove duplicates from each category
    stableConfigs = removeDupsFromExisting(stableConfigs, existingConfigs, existingPosCols);
    borderlineConfigs = removeDupsFromExisting(borderlineConfigs, existingConfigs, existingPosCols);
    unstableConfigs = removeDupsFromExisting(unstableConfigs, existingConfigs, existingPosCols);
end

%{
    @brief Saves robot configurations to an Excel file with multiple sheets.

    @param filePath          Path where the Excel file will be saved
    @param stableConfigs     Table of stable configurations
    @param borderlineConfigs Table of borderline configurations
    @param unstableConfigs   Table of unstable configurations
%}
function saveConfigs(filePath, stableConfigs, borderlineConfigs, unstableConfigs)
    if isempty(stableConfigs) && isempty(borderlineConfigs) && isempty(unstableConfigs)
        fprintf('No [new] configurations to save.\n');
        return;
    end

    try
        % Combine all configurations
        allConfig = [stableConfigs; borderlineConfigs; unstableConfigs];

        % Create stability label column
        stability = cell(height(allConfig), 1);
        if ~isempty(stableConfigs)
            stability(1:height(stableConfigs)) = {'Stable (within limits)'};
        end

        if ~isempty(borderlineConfigs)
            stability(height(stableConfigs)+(1:height(borderlineConfigs))) = {'Borderline (exceeds continuous limits)'};
        end

        if ~isempty(unstableConfigs)
            stability(height(stableConfigs)+height(borderlineConfigs)+(1:height(unstableConfigs))) = {'Unstable (exceeds peak limits)'};
        end

        % Add stability labels to data, rewriting GroupCount (we don't need it)
        allConfig.GroupCount = stability;
        allConfig.Properties.VariableNames{'GroupCount'} = 'Stability';

        % Save combined table to primary sheet
        writetable(allConfig, filePath, 'Sheet', 'All Configurations', 'WriteMode', 'append');

        % Save individual tables to separate sheets
        if ~isempty(stableConfigs)
            writetable(stableConfigs, filePath, 'Sheet', 'Stable', 'WriteMode', 'append');
        end

        if ~isempty(borderlineConfigs)
            writetable(borderlineConfigs, filePath, 'Sheet', 'Borderline', 'WriteMode', 'append');
        end

        if ~isempty(unstableConfigs)
            writetable(unstableConfigs, filePath, 'Sheet', 'Unstable', 'WriteMode', 'append');
        end

        fprintf('Configurations saved to "%s"\n', filePath);
    catch e
        error('Error saving configurations: %s', e.message);
    end
end

%{
    @brief Applies color formatting to torque value cells in an Excel sheet 
           based on predefined torque limits.

    @param filePath        String specifying the path to the Excel file
    @param sheetName       String specifying the name of the target sheet
    @param torqueCols      Cell array of column names containing torque values
    @param contTorqueLimit The continuous torque limit
    @param peakTorqueLimit The peak torque limit
%}
function applyTorqueCellColoring(filePath, sheetName, torqueCols, contTorqueLimit, peakTorqueLimit)
    % Open Excel file
    excel = actxserver('Excel.Application');
    excel.Visible = false; % true: visible for debugging | false: silent execution
    try
        filePath = fullfile(pwd, filePath); % excel needs a full filepath
        workbook = excel.Workbooks.Open(filePath);
        sheet = workbook.Sheets.Item(sheetName);
        data = sheet.UsedRange.Value; % read the whole sheet

        if isempty(data)
            error("Sheet data is empty or unreadable!");
        end

        % Find column indices for torque values
        torqueIndices = find(ismember(data(1, :), torqueCols));

        % Define colors (RGB)
        lightGreen = [198, 239, 206]; % stable
        lightYellow = [255, 235, 156]; % borderline
        lightRed = [255, 199, 206]; % unstable

        % Apply coloring to relevant cells
        for row = 2:size(data, 1) % skip header row
            for col = torqueIndices
                torqueVal = abs(data{row, col}); % ensure absolute value

                % Get current cell
                xlCell = strcat(intToExcelCol(col), num2str(row));
                cell = get(sheet, 'Range', xlCell);

                if torqueVal >= peakTorqueLimit
                    cell.Interior.Color = rgbToExcelColor(lightRed);
                elseif torqueVal >= contTorqueLimit
                    cell.Interior.Color = rgbToExcelColor(lightYellow);
                else
                    cell.Interior.Color = rgbToExcelColor(lightGreen);
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

    @param num Matrix column number

    @return Excel column letter
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

    @param rgb Array containing RGB values as [R, G, B], each in the range 0-255.

    @return excelColor Integer representing the closest matching Excel color index.
%}
function excelColor = rgbToExcelColor(rgb)
    excelColor = rgb(1) + 256 * rgb(2) + 65536 * rgb(3);
end
