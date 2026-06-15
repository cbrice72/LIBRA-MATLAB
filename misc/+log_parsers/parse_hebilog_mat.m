function log_data = parse_hebilog_mat(filename)
    %% @brief Parses a HEBI API log file (.mat) into a standard structure for
    %         analysis. The `.hebilog` format can be converted to `.mat` via
    %         the official Scope app.
    %         (these logs range from 2025/8/14 onwards)
    %
    % @note Data is NOT in joint space (e.g., Roll & Pitch), but in actuator
    %       space (e.g., MA & MB), so it must be converted before returning.
    
    if ~exist(filename, 'file')
        error('File %s does not exist.', filename);
    end
    
    % Load data
    mat_data = load(filename);
    
    % Populate return struct (should match that in other parse scripts)
    log_data = struct();
    log_data.joint_names = {'Roll', 'Pitch', 'J1', 'J2', 'J3'};  % assume LIBRA-I joint order & names

    log_data.time = mat_data.time(:);
    log_data.target_pos = rad2deg(mat_data.positionCmd);
    log_data.actual_pos = rad2deg(mat_data.position);
    log_data.pos_error = log_data.target_pos - log_data.actual_pos;
    log_data.actual_trq = mat_data.effort;

    % Convert actuator space to joint space
    to_convert = {'target_pos', 'actual_pos', 'pos_error', 'actual_trq'};
    
    for i = 1:length(to_convert)
        field = to_convert{i};

        act_data = log_data.(field);
        jnt_data = zeros(size(act_data));
        
        % Differential 2-DoF joint
        jnt_data(:, 1) = (-act_data(:, 1) - act_data(:, 2)) / 2;  % roll
        jnt_data(:, 2) = (act_data(:, 1) - act_data(:, 2)) / 2;   % pitch
        
        % Simple joints
        jnt_data(:, 3) = act_data(:, 3);   % J1 is 1:1
        jnt_data(:, 4) = -act_data(:, 4);  % J2 is inverted physically
        jnt_data(:, 5) = -act_data(:, 5);  % J3 is inverted physically
        
        % Reassign converted data
        log_data.(field) = jnt_data;
    end
end
