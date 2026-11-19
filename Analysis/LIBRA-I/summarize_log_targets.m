function summarize_log_targets()
    %% @brief Batch processes old LIBRA-I app CSV logs to summarize unique
    %         target poses, average position errors, and peak torque feedback.
    
    clear; clc;

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % @file   summarize_log_targets.m
    % @brief  Parses one or more Goto-style LIBRA App log files (CSVs) and
    %         creates a summary of unique user-commanded target poses. For each
    %         pose, it calculates instantaenous average position error across
    %         all joints and identifies which actuator is experiencing the
    %         highest torque.
    %
    % @author brice.c.aa
    % @date   2026/6/9
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Global plot style variables
    global TARGET_FILE_NAME ...
           HORIZ_RULE_W TIME_COL_W POS_ERR_COL_W;
           
    TARGET_FILE_NAME = '*_continuous_log.csv';

    HORIZ_RULE_W = 88;
    TIME_COL_W = 8;
    POS_ERR_COL_W = 15;

    % Resolve pathing to shared utility scripts folder
    script_dir = fileparts(mfilename('fullpath'));
    misc_path = fullfile(script_dir, '..', '..', 'misc');  % helper scripts

    if exist(misc_path, 'dir')
        addpath(misc_path);
    end

    %% SETUP

    % NOTE: Paths can be absolute or relative to this script
    target_dirs = { ...
        'E:\LIBRA Archive\LIBRA-I\2022-07-05 Goto-san Log Data',  ...
        'E:\LIBRA Archive\LIBRA-I\2023-11-13 Full Motion Test (bladder failure)\log',  ...
        'E:\LIBRA Archive\LIBRA-I\2023-11-14 Full Motion Test (arm failure)\log',  ...
        'E:\LIBRA Archive\LIBRA-I\2024-03-12 Takahashi Collab (ultrasonic sensor)\log',  ...
        'E:\LIBRA Archive\LIBRA-I\2024-06-24 Counterweight Measurements (18L)\log',  ...
        'E:\LIBRA Archive\LIBRA-I\2024-11-25 Upgrade Test 1\log',  ...
        'E:\LIBRA Archive\LIBRA-I\2024-11-28 Upgrade Test 2\log',  ...
        'E:\LIBRA Archive\LIBRA-I\2025-04-17 Test after J1 Replacement\log'  ...
    };

    save_to_file = true;
    output_file_name = 'csv_log_summary.txt';

    %% BODY

    % Save command window output to file, if enabled
    if save_to_file
        output_dir = fullfile(script_dir, 'output');
        if ~exist(output_dir, 'dir')
            mkdir(output_dir);
        end
        
        output_file_path = fullfile(output_dir, output_file_name);
        if exist(output_file_path, 'file')
            delete(output_file_path);
        end

        diary(output_file_path);
    end

    % Loop over all log files in all directories
    num_files = count_total_files(target_dirs);  % total number of files
    i_file = 0;  % global file index

    for d = 1:length(target_dirs)
        % Validate directory
        current_dir = target_dirs{d};

        if ~exist(current_dir, 'dir')
            continue;
        end
        
        % Get all files in directory
        log_files = dir(fullfile(current_dir, TARGET_FILE_NAME));
        
        for f = 1:length(log_files)
            i_file = i_file + 1;
            
            % Print section header
            fprintf('\n%s\n', repmat('=', 1, HORIZ_RULE_W));
            fprintf('File %d-%d (%d/%d): %s\n', ...
                    d, f, i_file, num_files, log_files(f).name);
            fprintf('%s\n', repmat('=', 1, HORIZ_RULE_W));
            
            % Validate log data
            try
                log_data = parse_libra_one_log(fullfile(log_files(f).folder, log_files(f).name));
            catch ME
                fprintf(' [SKIPPED] Failed to parse file: %s\n', ME.message);
                fprintf('%s\n\n', repmat('=', 1, HORIZ_RULE_W));
                continue;
            end
            
            if isempty(log_data.time)
                fprintf(' [SKIPPED] Log has no valid timestamp data\n');
                fprintf('%s\n\n', repmat('=', 1, HORIZ_RULE_W));
                continue;
            end
            
            % Get all unique poses in log
            pose_rows = extract_unique_poses(log_data);
            if isempty(pose_rows)
                fprintf(' [SKIPPED] No unique user-input target poses found.\n');
                fprintf('%s\n\n', repmat('=', 1, HORIZ_RULE_W));
                continue;
            end
            
            % Print summary
            joint_headers = sprintf('%7s ', log_data.joint_names{:});
            fprintf('%-*s | %s | %-*s | %s\n', ...
                    TIME_COL_W, 'Time (s)', ...            % timestamp
                    joint_headers, ...                     % joint names
                    POS_ERR_COL_W, 'Avg Error (deg)', ...  % pos error + stddev
                    'Max Torque (Nm)');                    % largest torque + actuator
            fprintf('%s\n', repmat('-', 1, HORIZ_RULE_W));
            
            for p = 1:length(pose_rows)
                print_pose_metrics(log_data, pose_rows(p));
            end

            % Print section footer
            fprintf('%s\n\n', repmat('=', 1, HORIZ_RULE_W));
        end
    end

    % Close output file, if enabled
    if save_to_file
        diary off;
        fprintf('Summary saved to:\n  %s\n', output_file_path);
    end

    fprintf('\nDone!\n');
end

%% FUNCTIONS

%{
    @brief Calculates total number of log files found across all valid directories.

    @param target_dirs  Array of directories to scan

    @return total_files  Total count of files found
%}
function total_files = count_total_files(target_dirs)
    global TARGET_FILE_NAME;

    total_files = 0;
    for d = 1:length(target_dirs)
        if exist(target_dirs{d}, 'dir')
            total_files = total_files + length(dir(fullfile(target_dirs{d}, TARGET_FILE_NAME)));
        end
    end
end

%{
    @brief Evaluates user-input target poses by filtering trajectory intermediates
           (user-input target = row where all target positions are WHOLE numbers).

    @param log_data  Parsed log data struct (see parse_libra_one_log.m)

    @return pose_rows  Indices corresponding to unique target poses
%}
function pose_rows = extract_unique_poses(log_data)
    pose_rows = [];

    last_pose = [];
    for i = 1:length(log_data.time)
        current_pose = log_data.target_pos(i, :);

        % Check if all target positions are whole numbers
        if all(mod(current_pose, 1) == 0)
            % Save only distinct user-input targets
            if isempty(last_pose) || ~all(current_pose == last_pose)
                pose_rows = [pose_rows; i];  %#ok<AGROW>
                last_pose = current_pose;
            end
        else
            % Reset tracking if trajectory intermediate detected
            last_pose = [];
        end
    end
end

%{
    @brief Calculates and prints position error and peak torque metrics for a row.

    @param log_data  Parsed log data struct (see parse_libra_one_log.m)
    @param i       Row index of log data to analyze
    
    @return (none)
%}
function print_pose_metrics(log_data, i)
    global TIME_COL_W POS_ERR_COL_W;

    % Calculate average position error + variance
    position_errors = abs(log_data.pos_error(i, :));
    pos_err_avg = mean(position_errors);
    pos_err_stddev = std(position_errors);
    
    % Find max torque w/ corresponding actuator
    actual_torques = log_data.actual_trq(i, :);

    [~, peak_joint_idx] = max(abs(actual_torques));
    max_trq_val = actual_torques(peak_joint_idx);
    max_trq_joint = log_data.joint_names{peak_joint_idx};
    
    % Convert numeric seconds from log_data.time to "mm:ss.S" format
    % (makes it easier to compare with CSV data loaded into Excel)
    total_sec = log_data.time(i);
    min_val = floor(total_sec / 60);
    sec_val = total_sec - (min_val * 60);    

    % Print metrics
    time_str = sprintf('%02d:%04.1f', min_val, sec_val);
    pose_str = sprintf('%7.1f ', log_data.target_pos(i, :));
    err_str = sprintf('%5.1f \xB1%5.1f', pos_err_avg, pos_err_stddev);
    trq_str = sprintf('%6.1f (%-5s)', max_trq_val, max_trq_joint);
    
    fprintf('%-*s | %s | %-*s | %s\n', ...
            TIME_COL_W, time_str, pose_str, POS_ERR_COL_W, err_str, trq_str);
end
