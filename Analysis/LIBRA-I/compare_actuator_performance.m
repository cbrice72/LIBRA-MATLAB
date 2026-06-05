function compare_actuator_performance()
    %% @brief Batch processes actuator accuracy and stability using data from
    %         multiple directories. This was developed specifically for
    %         comparing pre- and post-variable-gains implementation, so there
    %         are two separate data structures.

    % Resolve pathing to shared utility scripts folder
    script_dir = fileparts(mfilename('fullpath'));
    misc_path = fullfile(script_dir, '..', '..', 'misc');  % helper scripts

    if exist(misc_path, 'dir')
        addpath(misc_path);
    end

    %% SETUP
    
    % NOTE: Paths can be absolute or relative to this script
    before_dirs = { ...
        'E:\LIBRA Archive\2022-07 Goto-san Experimental Log Data',  ...
        'E:\LIBRA Archive\2023-11-13 Full Motion Test (bladder failure)\log',  ...
        'E:\LIBRA Archive\2023-11-14 Full Motion Test (arm failure)\log',  ...
        'E:\LIBRA Archive\2024-03-12_Takahashi-Collab_(ultrasonic-sensor)\log',  ...
        'E:\LIBRA Archive\2024-06-24 Counterweight Measurements (18L)\log',  ...
        'E:\LIBRA Archive\2024-11-25 Upgraded LIBRA-I Test Attempt 1\log',  ...
        'E:\LIBRA Archive\2024-11-28 Upgraded LIBRA-I Test Attempt 2\log',  ...
        'E:\LIBRA Archive\2025-04-17 LIBRA-I Test after J1 Replacement\log',  ...
        'E:\LIBRA Archive\2025-08-14 PID Gains Comparison\log',  ...
        'E:\LIBRA Archive\2025-08-22 SLAM Attempt 3 (motion failure)\log' ...%,  ...
        %'E:\LIBRA Archive\2025-08-29 SLAM Attempt 4 (odom failure)\log' ...
    };

    after_dirs = { ...
        'E:\LIBRA Archive\2025-08-29 SLAM Attempt 4 (odom failure)\log' ...
        %TODO: 'E:\LIBRA Archive\2025-09-26 SLAM Data Collection 1\log'  ...
    };

    %% BODY

    % Initialize master data structs
    before = struct('position_error', [], 'torque_rate', [], 'joint_names', ...
        {{'Roll', 'Pitch', 'J1', 'J2', 'J3'}});
    after  = struct('position_error', [], 'torque_rate', [], 'joint_names', ...
        {{'Roll', 'Pitch', 'J1', 'J2', 'J3'}});

    % Process log files
    [before, before_count] = process_dirs(before_dirs, script_dir, before);
    [after, after_count] = process_dirs(after_dirs, script_dir, after);

    % Check parsed data
    fprintf('\nFound %d "Before" files and %d "After" files\n', before_count, after_count);
    
    if isempty(before.position_error) || isempty(after.position_error)
        error('Data aggregation failed; verify directory paths and file naming conventions');
    end

    % Plot analyses
    fprintf('Generating visualizations...\n');

    plot_absolute_error_boxplots(before, after);
    plot_error_cdfs(before, after);
    plot_torque_jitter(before, after);
    plot_rmse_radar(before, after);

    fprintf('Done!\n');
end

%% FUNCTIONS

%{
    @brief Batch processes data files across listed log directories.

    @param dirs         Array of directories to scan
    @param data_struct  Master struct to populate
    @param script_dir   Absolute path of the executing script

    @return data_struct  Updated master structure
    @return file_count   Number of successfully parsed files
%}
function [data_struct, file_count] = process_dirs(dirs, script_dir, data_struct)
    file_count = 0;
    for d = 1:length(dirs)
        % Ensure absolute path
        dir_path = dirs{d};
        if ~fileparts(dir_path)
            dir_path = fullfile(script_dir, dir_path);
        end
        
        % Skip if path doesn't exist
        if ~exist(dir_path, 'dir')
            warning('Directory not found, skipping: %s', dirs{d});
            continue;
        end
        
        % Check all CSV and MAT files in directory
        dir_files = [dir(fullfile(dir_path, '*.csv')); dir(fullfile(dir_path, '*.mat'))];
        for f = 1:length(dir_files)
            f_name = dir_files(f).name;
            [~, ~, f_ext] = fileparts(f_name);

            % Skip files missing expected keywords
            if (strcmpi(f_ext, '.csv') && ~contains(f_name, '_continuous_log')) || ...
               (strcmpi(f_ext, '.mat') && ~contains(f_name, 'log_file_'))
                continue;
            end
            
            % Retrieve data
            file_data = parse_libra_one_log(fullfile(dir_path, f_name));
            [data_struct, file_count] = update_struct(data_struct, file_data, file_count);
        end
    end
end

%{
    @brief Appends data rows from a file to a master struct.

    @param agg_struct  Master struct to populate
    @param data        Parsed file log data structure to extract from
    @param count       Original number of successfully parsed files

    @return agg_struct  Updated master struct
    @return count       Updated number of successfully parsed files
%}
function [data_struct, file_count] = update_struct(data_struct, data, file_count)
    % Remove NaN entries
    valid_mask = ~isnan(data.pos_error(:, 1));
    data_struct.position_error = [data_struct.position_error; ...
                                 data.pos_error(valid_mask, :)];
    
    % Pre-allocate torque rate array matrix
    dt = diff(data.time);
    valid_dt = dt > 0;
    num_joints = size(data.pos_error, 2);
    file_torque_rate = zeros(sum(valid_dt), num_joints);
    
    % Compute discrete torque derivatives per channel
    for j = 1:num_joints
        dtau = diff(data.actual_trq(:, j));
        file_torque_rate(:, j) = dtau(valid_dt) ./ dt(valid_dt);
    end
    
    % Save metrics
    data_struct.torque_rate = [data_struct.torque_rate; file_torque_rate];
    file_count = file_count + 1;
end

%{
    @brief Generates a graph comparing "Before" and "After" data using simple
           side-by-side boxplots.

    @param before  "Before" data struct
    @param after   "After" data struct

    @return (none)
%}
function plot_absolute_error_boxplots(before, after)
    % Determine layout scaling from params
    num_joints = size(before.position_error, 2);

    joint_group_positions = 1:2.5:(1 + 2.5 * (num_joints - 1));
    box_positions = zeros(1, 2 * num_joints);
    
    % Pre-allocate arrays for speed
    total_b = sum(~isnan(before.position_error), 'all');
    total_a = sum(~isnan(after.position_error), 'all');
    all_data = zeros(total_b + total_a, 1);
    all_groups = zeros(total_b + total_a, 1);
    
    % Build combined data
    write_idx = 1;
    for i = 1:num_joints
        b_err = abs(before.position_error(:, i));
        b_err = b_err(~isnan(b_err));
        len_b = length(b_err);
        all_data(write_idx : write_idx + len_b - 1) = b_err;
        all_groups(write_idx : write_idx + len_b - 1) = (i - 1) * 2 + 1;
        write_idx = write_idx + len_b;
        
        a_err = abs(after.position_error(:, i));
        a_err = a_err(~isnan(a_err));
        len_a = length(a_err);
        all_data(write_idx : write_idx + len_a - 1) = a_err;
        all_groups(write_idx : write_idx + len_a - 1) = (i - 1) * 2 + 2;
        write_idx = write_idx + len_a;
        
        box_positions((i - 1) * 2 + 1) = joint_group_positions(i);
        box_positions((i - 1) * 2 + 2) = joint_group_positions(i) + 0.6;
    end
    
    % Draw plot
    figure('Name', 'Aggregated Absolute Error Boxplots', 'Color', 'w');
    boxplot(all_data, all_groups, ...
            'Positions', box_positions, 'Symbol', 'r.');
    
    % Set properties
    grid on;

    midpoints = joint_group_positions + 0.3;
    set(gca, 'XTick', midpoints, ...
             'XTickLabel', before.joint_names, ...
             'TickLength', [0 0]);

    title('Actuator Error Boundaries', ...
          'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Global Absolute Positioning Error (\circ)', ...
           'FontSize', 11, 'FontWeight', 'bold');
    
    % Modify box colors to differentiate "before" and "after"
    box_handles = findobj(gca, 'Tag', 'Box');
    for k = 1:length(box_handles)
        % Odd ("before") = green, even ("after") = red
        if mod(k, 2) == 1
            set(box_handles(k), 'Color', [0, 0.5, 0.1], 'LineWidth', 1.8);
        else
            set(box_handles(k), 'Color', [0.8, 0.1, 0.1], 'LineWidth', 1.8);
        end
    end
    
    % Customize legend
    hold on;
    h_b = plot(NaN, NaN, 'Color', [0.8, 0.1, 0.1], 'LineWidth', 2);
    h_a = plot(NaN, NaN, 'Color', [0, 0.5, 0.1], 'LineWidth', 2);
    legend([h_b, h_a], {'Before', 'After'}, ...
           'Location', 'best');
end

%{
    @brief Generates a graph comparing "Before" and "After" data using
           joint-by-joint cumulative distribution functions (CDFs).

    @param before  "Before" data struct
    @param after   "After" data struct

    @return (none)
%}
function plot_error_cdfs(before, after)
    % Determine layout scaling from params
    num_joints = size(before.position_error, 2);

    cols = 3;
    rows = ceil(num_joints / cols);

    % Draw plot
    figure('Name', 'Combined Error CDF', 'Color', 'w');
    for i = 1:num_joints
        subplot(rows, cols, i);
        b_err = sort(abs(before.position_error(:, i)));
        b_y = (1:length(b_err)) / length(b_err);
        a_err = sort(abs(after.position_error(:, i)));
        a_y = (1:length(a_err)) / length(a_err);
        
        plot(b_err, b_y * 100, 'r--', 'LineWidth', 1.8); hold on;
        plot(a_err, a_y * 100, 'g-', 'LineWidth', 1.8);

        % Set properties
        grid on;

        title(sprintf('Joint: %s', before.joint_names{i}), ...
              'FontSize', 10, 'FontWeight', 'bold');
        xlabel('Absolute Error (\circ)');
        ylabel('Probability (%)');

        % Customize legend (first plot only)
        if i == 1
            legend('Before', 'After', ...
                   'Location', 'best');
        end
    end

    sgtitle('Tracking Reliability Profile (CDF)', ...
            'FontSize', 12, 'FontWeight', 'bold');
end

%{
    @brief Generates a graph comparing "Before" and "After" data using
           actuator torque jitter as an RMS of dτ/dt.

    @param before  "Before" data struct
    @param after   "After" data struct

    @return (none)
%}
function plot_torque_jitter(before, after)
    % Determine layout scaling from params
    num_joints = size(before.torque_rate, 2);

    % Pre-allocate arrays for speed
    b_jitter = zeros(1, num_joints);
    a_jitter = zeros(1, num_joints);
    
    % Calculate RMS for each dataset
    for i = 1:num_joints
        b_jitter(i) = sqrt(mean(before.torque_rate(:, i).^2, 'omitnan'));
        a_jitter(i) = sqrt(mean(after.torque_rate(:, i).^2, 'omitnan'));
    end
    
    % Draw plot
    figure('Name', 'Torque Jitter Analysis', 'Color', 'w');

    bar_matrix = [b_jitter; a_jitter]';
    h_bar = bar(bar_matrix, 'EdgeColor', 'none');
    h_bar(1).FaceColor = [0.8, 0.1, 0.1];  % red
    h_bar(2).FaceColor = [0, 0.5, 0.1];  % green
    
    % Set properties
    grid on;

    set(gca, 'XTickLabel', before.joint_names(1:num_joints));

    title('Torque Jitter Profile', ...
          'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Torque Derivative RMS (Nm/s)', ...
           'FontSize', 11, 'FontWeight', 'bold');

    % Customize legend
    legend({'Before Variable Gains', 'After Variable Gains'}, ...
           'Location', 'best');
end

%{
    @brief Generates a 2D Cartesian radar chart comparing "Before" and "After"
           data using spatial RMSE footprints.

    @param before  "Before" data struct
    @param after   "After" data struct

    @return (none)
%}
function plot_rmse_radar(before, after)
    % Determine layout scaling from params
    num_joints = size(before.position_error, 2);

    % Pre-allocate arrays for speed
    b_rmse = zeros(1, num_joints);
    a_rmse = zeros(1, num_joints);
    
    % Calculate joint RMSE metrics
    for i = 1:num_joints
        b_rmse(i) = sqrt(mean(before.position_error(:, i).^2, 'omitnan'));
        a_rmse(i) = sqrt(mean(after.position_error(:, i).^2, 'omitnan'));
    end
    
    % Project polar → Cartesian (X/Y)
    angles = linspace(0, 2 * pi, num_joints + 1);
    bx = [b_rmse, b_rmse(1)] .* cos(angles); by = [b_rmse, b_rmse(1)] .* sin(angles);
    ax = [a_rmse, a_rmse(1)] .* cos(angles); ay = [a_rmse, a_rmse(1)] .* sin(angles);
    
    % Draw plot
    figure('Name', 'Tracking RMSE Radar Footprint', 'Color', 'w');
    hold on;
    % 1) Render background rings
    max_scale = max([b_rmse, a_rmse]) * 1.15;
    rings = linspace(0, max_scale, 4);
    for r = rings(2:end)
        plot(r * cos(linspace(0, 2*pi, 100)), r * sin(linspace(0, 2*pi, 100)), ':', ...
            'Color', [0.6 0.6 0.6], 'HandleVisibility', 'off');
        text(r * cos(pi/4), r * sin(pi/4), sprintf(' %.2f^\\circ', r), ...
            'Color', [0.4 0.4 0.4], 'FontSize', 8);
    end
    
    % 2) Draw spokes
    for j = 1:num_joints
        plot([0, max_scale * cos(angles(j))], [0, max_scale * sin(angles(j))], '-', ...
            'Color', [0.8 0.8 0.8], ...
            'HandleVisibility', 'off');
        text(max_scale * 1.1 * cos(angles(j)), max_scale * 1.1 * sin(angles(j)), ...
            before.joint_names{j}, ...
            'HorizontalAlignment', 'center', ...
            'FontWeight', 'bold', 'FontSize', 10);
    end
    
    % 3) Overlay patch boundaries
    patch(bx, by, [1, 0, 0], ...
          'DisplayName', 'Before', ...
          'FaceAlpha', 0.12, ...
          'EdgeColor', [0.8 0.1 0.1], ...
          'LineWidth', 2);
    patch(ax, ay, [0, 0.5, 0], ...
          'DisplayName', 'After', ...
          'FaceAlpha', 0.12, ...
          'EdgeColor', [0 0.5 0.1], ...
          'LineWidth', 2);
    
    % Set properties
    axis equal; axis off;  % remove axis visibility as it's not used here
    title('Global Kinematic Joint Tracking RMSE Area Footprint', ...
          'FontSize', 12, 'FontWeight', 'bold');
    
    % Customize legend
    legend('Show', 'Location', 'southoutside');
end
