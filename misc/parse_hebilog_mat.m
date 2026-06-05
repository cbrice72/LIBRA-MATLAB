function log_data = parse_hebilog_mat(filename)
    %% @brief Parses a HEBI API log file (.mat) into a standard structure for analysis.
    
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
end
