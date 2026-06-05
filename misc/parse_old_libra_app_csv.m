function log_data = parse_old_libra_app_csv(filename)
    %% @brief Parses the older Goto-style LIBRA-I App CSV log file.
    
    if ~exist(filename, 'file')
        error('File %s does not exist.', filename);
    end
    
    % Import table, explicitly reading time column as string (easier conversion)
    opts = detectImportOptions(filename);
    opts.VariableNamingRule = 'preserve';
    if any(strcmp(opts.VariableNames, 'Time'))
        opts = setvaropts(opts, 'Time', 'Type', 'string');
    end
    data = readtable(filename, opts);

    % Filter out invalid rows, just in case
    valid_rows = ~ismissing(data.Time) & (strtrim(string(data.Time)) ~= "");
    data = data(valid_rows, :);
    time_str = erase(strtrim(string(data.Time)), char(13));  % carriage return
    
    % Parse timestamps and normalize to start of log
    if contains(time_str(1), '/')
        % Full format
        t = datetime(time_str, 'InputFormat', 'yyyy/MM/dd HH:mm:ss.SSS');
        time_sec = seconds(t - t(1));
    else
        % Short format, with hour rollover correction
        t = datetime(time_str, 'InputFormat', 'mm:ss.S');
        dt = diff(t);
        dt(dt < 0) = dt(dt < 0) + hours(1);
        time_sec = [0; cumsum(seconds(dt))];
    end
    
    vars = data.Properties.VariableNames;
    joints = {'Roll', 'Pitch', 'J1', 'J2', 'J3'};  % assume LIBRA-I joint order & names
    
    N = height(data);
    target_pos = zeros(N, 5);
    actual_pos = zeros(N, 5);
    actual_trq = zeros(N, 5);
    
    % Extract columns
    for i = 1:length(joints)
        % TP = Target Position
        idx_tp = find(contains(vars, 'TP_') & contains(vars, joints{i}) & ~contains(vars, 'Cam'));
        if isempty(idx_tp)
            error('Could not locate Target Position column for joint: %s', joints{i});
        end
        target_pos(:, i) = data{:, idx_tp(1)};
        
        % PP = Present Position
        idx_pp = find(contains(vars, 'PP_') & contains(vars, joints{i}));
        if isempty(idx_pp)
            error('Could not locate Present Position column for joint: %s', joints{i});
        end
        actual_pos(:, i) = data{:, idx_pp(1)};
        
        % PT = Present Torque
        idx_pt = find(contains(vars, 'PT_') & contains(vars, joints{i}));
        if isempty(idx_pt)
            error('Could not locate Present Torque column for joint: %s', joints{i});
        end
        actual_trq(:, i) = data{:, idx_pt(1)};
    end
    
    % Populate return struct (should match that in other parse scripts)
    log_data = struct();
    log_data.joint_names = joints;

    log_data.time = time_sec;
    log_data.target_pos = target_pos;
    log_data.actual_pos = actual_pos;
    log_data.pos_error = target_pos - actual_pos;
    log_data.actual_trq = actual_trq;
end
