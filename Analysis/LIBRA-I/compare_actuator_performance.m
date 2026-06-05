function compare_actuator_performance()
    %% @brief Batch processes actuator accuracy and stability using data from
    %         multiple directories. This was developed specifically for
    %         comparing pre- and post-variable-gains implementation, so there
    %         are two separate data structures.

    close all;

    % Global plot style variables
    global COLOR_BEFORE COLOR_AFTER SHOW_TITLES ...
           FONT_SIZE_TITLE FONT_SIZE_AXIS FONT_SIZE_LEGEND TITLE_WEIGHT TEXT_COLOR ...
           BG_COLOR GRID_COLOR ...
           BOX_SPACING BAR_WIDTH Y_LIMIT_PERCENTILE;
           
    COLOR_BEFORE       = [0.29, 0.29, 0.29];  % dark gray
    COLOR_AFTER        = [0.85, 0.37, 0.01];  % orange
    SHOW_TITLES        = true;

    FONT_SIZE_TITLE    = 22;
    FONT_SIZE_AXIS     = 18;
    FONT_SIZE_LEGEND   = 16;
    TITLE_WEIGHT       = 'bold';
    TEXT_COLOR         = 'k';

    BG_COLOR           = 'w';
    GRID_COLOR         = [0.75 0.75 0.75];  % light gray

    BOX_SPACING        = 1.0;
    BAR_WIDTH          = 0.95;
    Y_LIMIT_PERCENTILE = 98.0;

    % Resolve pathing to shared utility scripts folder
    script_dir = fileparts(mfilename('fullpath'));
    misc_path = fullfile(script_dir, '..', '..', 'misc');  % helper scripts

    if exist(misc_path, 'dir')
        addpath(misc_path);
    end

    %% SETUP

    joints = {'Roll', 'Pitch', 'J1', 'J2', 'J3'};
    
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
    before = struct('position_error', [], 'torque_jitter', [], 'rmse', []);
    after  = struct('position_error', [], 'torque_jitter', [], 'rmse', []);

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

    plot_absolute_error_boxplots(joints, before, after);
    plot_error_cdfs(joints, before, after);
    plot_torque_jitter(joints, before, after);
    plot_rmse_radar(joints, before, after);

    fprintf('Printing summary...\n');

    fprintf('\n====================================================================\n');
    fprintf('                    ACTUATOR PERFORMANCE SUMMARY                    \n');
    fprintf('====================================================================\n');
    fprintf('%-12s %-15s %-15s\n', 'Dataset', 'Total Files', 'Total Samples');
    fprintf('--------------------------------------------------------------------\n');
    fprintf('%-12s %-15d %-15d\n', 'Before', before_count, size(before.position_error, 1));
    fprintf('%-12s %-15d %-15d\n', 'After', after_count, size(after.position_error, 1));
    fprintf('--------------------------------------------------------------------\n\n');

    % Calculate metrics (basically same data as the plots
    b_mae = mean(abs(before.position_error), 1, 'omitnan');  % mean abs error
    a_mae = mean(abs(after.position_error), 1, 'omitnan');
    b_rmse_avg = mean(before.rmse, 1, 'omitnan');  % tracking rmse
    a_rmse_avg = mean(after.rmse, 1, 'omitnan');
    b_jitter_avg = mean(before.torque_jitter, 1, 'omitnan');  % torque jitter
    a_jitter_avg = mean(after.torque_jitter, 1, 'omitnan');

    deg_sym = char(176);  % cross-platform degree symbol
    for i = 1:length(joints)
        fprintf('Joint: %s\n', joints{i});
        fprintf('  - Mean Abs Error: Before = %6.3f%s, After = %6.3f%s\n', b_mae(i), deg_sym, a_mae(i), deg_sym);
        fprintf('  - Tracking RMSE:  Before = %6.3f%s, After = %6.3f%s\n', b_rmse_avg(i), deg_sym, a_rmse_avg(i), deg_sym);
        fprintf('  - Torque Jitter:  Before = %6.2f Nm/s, After = %6.2f Nm/s\n', b_jitter_avg(i), a_jitter_avg(i));
        fprintf('\n');
    end
    fprintf('====================================================================\n');

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
        dir_files = [dir(fullfile(dir_path, '*.csv'));
                     dir(fullfile(dir_path, '*.mat'))];
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
    file_pos_error = data.pos_error(valid_mask, :);
    
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
    data_struct.position_error = [data_struct.position_error; file_pos_error];
    data_struct.rmse = [data_struct.rmse;
                        sqrt(mean(file_pos_error.^2, 1, 'omitnan'))];
    data_struct.torque_jitter = [data_struct.torque_jitter;
                                 sqrt(mean(file_torque_rate.^2, 1, 'omitnan'))];

    file_count = file_count + 1;
end

%{
    @brief Generates a graph comparing "Before" and "After" data using simple
           side-by-side boxplots.

    @param before  "Before" data struct
    @param after   "After" data struct

    @return (none)
%}
function plot_absolute_error_boxplots(joints, before, after)
    global COLOR_BEFORE COLOR_AFTER SHOW_TITLES FONT_SIZE_TITLE FONT_SIZE_AXIS ...
           FONT_SIZE_LEGEND TITLE_WEIGHT TEXT_COLOR BG_COLOR GRID_COLOR ...
           BOX_SPACING Y_LIMIT_PERCENTILE;

    % Determine layout scaling from params
    num_joints = size(before.position_error, 2);

    joint_group_positions = 1:BOX_SPACING:(1 + BOX_SPACING * (num_joints - 1));
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
        box_positions((i - 1) * 2 + 2) = joint_group_positions(i) + 0.32;
    end
    
    % Draw plot
    figure('Name', 'Aggregated Absolute Error Boxplots', 'Color', BG_COLOR);
    boxplot(all_data, all_groups, ...
            'Positions', box_positions, 'Symbol', '');
    ylim([0, prctile(all_data, Y_LIMIT_PERCENTILE) * 1.05]);
    
    % Set properties
    grid on;

    midpoints = joint_group_positions + 0.16;
    set(gca, 'Color', BG_COLOR, 'GridColor', GRID_COLOR, ...
             'FontSize', FONT_SIZE_AXIS, ...
             'XColor', TEXT_COLOR, 'YColor', TEXT_COLOR, ...
             'XTick', midpoints, 'XTickLabel', joints, ...
             'TickLength', [0 0]);

    if SHOW_TITLES
        title('Actuator Error Boundaries', ...
              'FontSize', FONT_SIZE_TITLE, 'FontWeight', TITLE_WEIGHT, ...
              'Color', TEXT_COLOR);
    end
    ylabel('Global Absolute Positioning Error (\circ)', ...
           'FontSize', FONT_SIZE_AXIS, 'FontWeight', TITLE_WEIGHT, ...
           'Color', TEXT_COLOR);
    
    % Modify box colors to differentiate "before" and "after"
    box_handles = findobj(gca, 'Tag', 'Box');

    for k = 1:length(box_handles)
        % Odd = "before", even = "after"
        if mod(k, 2) == 1
            set(box_handles(k), 'Color', COLOR_AFTER, 'LineWidth', 1.8);
        else
            set(box_handles(k), 'Color', COLOR_BEFORE, 'LineWidth', 1.8);
        end
    end
    
    % Customize legend
    hold on;
    h_b = plot(NaN, NaN, 'Color', COLOR_BEFORE, 'LineWidth', 2);
    h_a = plot(NaN, NaN, 'Color', COLOR_AFTER, 'LineWidth', 2);
    legend([h_b, h_a], {'Before', 'After'}, ...
           'Location', 'best', ...
           'Color', BG_COLOR, ...
           'FontSize', FONT_SIZE_LEGEND, 'TextColor', TEXT_COLOR);
end

%{
    @brief Generates a graph comparing "Before" and "After" data using
           joint-by-joint cumulative distribution functions (CDFs).

    @param before  "Before" data struct
    @param after   "After" data struct

    @return (none)
%}
function plot_error_cdfs(joints, before, after)
    global COLOR_BEFORE COLOR_AFTER SHOW_TITLES FONT_SIZE_TITLE FONT_SIZE_AXIS ...
           FONT_SIZE_LEGEND TITLE_WEIGHT TEXT_COLOR BG_COLOR GRID_COLOR;

    % Determine layout scaling from params
    num_joints = size(before.position_error, 2);

    cols = 3;
    rows = ceil(num_joints / cols);

    % Draw plot
    figure('Name', 'Combined Error CDF', 'Color', 'w');
    global_max_x = max([prctile(abs(before.position_error(:)), 98), ...
                        prctile(abs(after.position_error(:)), 98), ...
                        0.1]);

    for i = 1:num_joints
        subplot(rows, cols, i);

        b_err = sort(abs(before.position_error(:, i)));
        b_err = b_err(~isnan(b_err));
        b_y = (1:length(b_err)) / length(b_err);

        a_err = sort(abs(after.position_error(:, i)));
        a_err = a_err(~isnan(a_err));
        a_y = (1:length(a_err)) / length(a_err);
        
        plot(b_err, b_y * 100, '--', 'LineWidth', 1.8,...
             'Color', COLOR_BEFORE);
        hold on;
        plot(a_err, a_y * 100, '-', 'LineWidth', 1.8, ...
             'Color', COLOR_AFTER);

        xlim([0, global_max_x]);

        % Set properties
        grid on;

        set(gca, 'Color', BG_COLOR, 'GridColor', GRID_COLOR, ...
                 'FontSize', FONT_SIZE_AXIS - 1, ...
                 'XColor', TEXT_COLOR, 'YColor', TEXT_COLOR);
        
        if SHOW_TITLES
            title(sprintf('Joint: %s', joints{i}), ...
                          'FontSize', FONT_SIZE_TITLE, 'FontWeight', TITLE_WEIGHT, ...
                          'Color', TEXT_COLOR);
        end
        xlabel('Absolute Error (\circ)', ...
               'FontSize', FONT_SIZE_AXIS, ...
               'Color', TEXT_COLOR);
        ylabel('Probability (%)', ...
               'FontSize', FONT_SIZE_AXIS, ...
               'Color', TEXT_COLOR);
    end

    % Customize legend (in empty 6th subplot)
    subplot(rows, cols, 6);

    % NOTE: these invisible dummy lines match the style of the other plots,
    %       so there will be a legend in the empty space without an extra plot
    h1 = plot(NaN, NaN, '--', 'LineWidth', 1.8, 'Color', COLOR_BEFORE);
    hold on;
    h2 = plot(NaN, NaN, '-', 'LineWidth', 1.8, 'Color', COLOR_AFTER);

    legend([h1, h2], {'Before', 'After'}, ...
           'Location', 'northwest', ...
           'Color', BG_COLOR, ...
           'FontSize', FONT_SIZE_LEGEND, 'TextColor', TEXT_COLOR);

    axis off;

    % Overall plot title
    sgtitle('Tracking Reliability Profile (CDF)', ...
            'FontSize', FONT_SIZE_TITLE, 'FontWeight', TITLE_WEIGHT, 'Color', TEXT_COLOR);
end

%{
    @brief Generates a graph comparing "Before" and "After" data using
           actuator torque jitter as an RMS of dτ/dt.

    @param before  "Before" data struct
    @param after   "After" data struct

    @return (none)
%}
function plot_torque_jitter(joints, before, after)
    global COLOR_BEFORE COLOR_AFTER SHOW_TITLES FONT_SIZE_TITLE FONT_SIZE_AXIS ...
           FONT_SIZE_LEGEND TITLE_WEIGHT TEXT_COLOR BG_COLOR GRID_COLOR BAR_WIDTH;

    % Determine layout scaling from params
    num_joints = size(joints, 2);
    
    % Calculate RMS for each dataset
    b_jitter = mean(before.torque_jitter, 1, 'omitnan');
    a_jitter = mean(after.torque_jitter, 1, 'omitnan');
    
    % Draw plot
    figure('Name', 'Torque Jitter Analysis', 'Color', BG_COLOR);

    bar_matrix = [b_jitter; a_jitter]';
    h_bar = bar(bar_matrix, BAR_WIDTH, 'EdgeColor', 'none');
    h_bar(1).FaceColor = COLOR_BEFORE;
    h_bar(2).FaceColor = COLOR_AFTER;
    
    % Set properties
    grid on;

    set(gca, 'Color', BG_COLOR, 'GridColor', GRID_COLOR, ...
             'FontSize', FONT_SIZE_AXIS, ...
             'XColor', TEXT_COLOR, 'YColor', TEXT_COLOR, ...
             'XTickLabel', joints(1:num_joints));
    
    if SHOW_TITLES
        title('Torque Jitter Profile', ...
              'FontSize', FONT_SIZE_TITLE, 'FontWeight', TITLE_WEIGHT, ...
              'Color', TEXT_COLOR);
    end
    ylabel('Torque Derivative RMS (Nm/s)', ...
           'FontSize', FONT_SIZE_AXIS, 'FontWeight', TITLE_WEIGHT, ...
           'Color', TEXT_COLOR);

    % Customize legend
    legend({'Before Variable Gains', 'After Variable Gains'}, ...
           'Location', 'best', ...
           'Color', BG_COLOR, ...
           'FontSize', FONT_SIZE_LEGEND, 'TextColor', TEXT_COLOR);
end

%{
    @brief Generates a 2D Cartesian radar chart comparing "Before" and "After"
           data using spatial RMSE footprints.

    @param before  "Before" data struct
    @param after   "After" data struct

    @return (none)
%}
function plot_rmse_radar(joints, before, after)
    global COLOR_BEFORE COLOR_AFTER SHOW_TITLES FONT_SIZE_TITLE FONT_SIZE_AXIS ...
           FONT_SIZE_LEGEND TITLE_WEIGHT TEXT_COLOR BG_COLOR GRID_COLOR;

    % Determine layout scaling from params
    num_joints = size(before.position_error, 2);
    
    % Calculate joint RMSE metrics
    b_rmse = mean(before.rmse, 1, 'omitnan');
    a_rmse = mean(after.rmse, 1, 'omitnan');
    
    % Project polar → Cartesian (X/Y)
    angular_offset = -pi/10;  % rotate graph so title and tick label(s) don't overlap
    angles = linspace(0, 2 * pi, num_joints + 1) + angular_offset;

    bx = [b_rmse, b_rmse(1)] .* cos(angles);
    by = [b_rmse, b_rmse(1)] .* sin(angles);
    ax = [a_rmse, a_rmse(1)] .* cos(angles);
    ay = [a_rmse, a_rmse(1)] .* sin(angles);
    
    % Draw plot
    figure('Name', 'Tracking RMSE Radar Footprint', 'Color', 'w');
    hold on;

    % 1) Draw background rings
    absolute_max = max([b_rmse, a_rmse]);
    step_val = 1.0;

    if absolute_max <= 2
        step_val = 0.5;
    elseif absolute_max > 5
        step_val = 5.0;
    end

    max_scale = ceil(absolute_max / step_val) * step_val;
    rings = 0:step_val:max_scale;
    ring_color = min(GRID_COLOR * 1.15, 1.0);

    for r = rings(2:end)
        plot(r * cos(linspace(0, 2*pi, 100)), r * sin(linspace(0, 2*pi, 100)), ':', ...
            'Color', ring_color, 'HandleVisibility', 'off');
        text(r * cos(pi/3 + angular_offset), r * sin(pi/3 + angular_offset), sprintf(' %.1f^\\circ', r), ...
            'Color', [0.4 0.4 0.4], 'FontSize', FONT_SIZE_AXIS - 3);
    end
    
    % 2) Draw spokes
    spoke_color = max(GRID_COLOR * 0.85, 0.0);

    for j = 1:num_joints
        plot([0, max_scale * cos(angles(j))], [0, max_scale * sin(angles(j))], '-', ...
            'Color', spoke_color, ...
            'HandleVisibility', 'off');
        text(max_scale * 1.18 * cos(angles(j)), max_scale * 1.18 * sin(angles(j)), ...
            joints{j}, ...
            'HorizontalAlignment', 'center', ...
            'FontSize', FONT_SIZE_AXIS, 'FontWeight', TITLE_WEIGHT, 'Color', TEXT_COLOR);
    end
    
    % 3) Overlay patch boundaries
    patch(bx, by, COLOR_BEFORE, ...
          'DisplayName', 'Before', ...
          'FaceAlpha', 0.12, ...
          'EdgeColor', COLOR_BEFORE, ...
          'LineWidth', 2);
    patch(ax, ay, COLOR_AFTER, ...
          'DisplayName', 'After', ...
          'FaceAlpha', 0.12, ...
          'EdgeColor', COLOR_AFTER, ...
          'LineWidth', 2);
    
    % Set properties
    axis equal; axis off;  % remove axis visibility as it's not used here

    if SHOW_TITLES
        title('Global Kinematic Joint Tracking RMSE Area Footprint', ...
              'FontSize', FONT_SIZE_TITLE, 'FontWeight', TITLE_WEIGHT, ...
              'Color', TEXT_COLOR);
    end
    
    % Customize legend
    legend('Show', ...
           'Location', 'northeast', ...
           'Color', BG_COLOR, ...
           'FontSize', FONT_SIZE_LEGEND, 'TextColor', TEXT_COLOR);
end
