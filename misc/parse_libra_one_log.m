function log_data = parse_libra_one_log(filename)
    %% @brief Selects the correct parser based on file extension and naming rules.
    
    [~, name, ext] = fileparts(filename);
    
    if isfolder(filename)
        % ROS2 rosbags
        if exist(fullfile(filename, 'metadata.yaml'), 'file')
            log_data = log_parsers.parse_rosbag2_dir(filename);
        else
            error('Path is directory but not a valid rosbag2 folder: %s', filename);
        end
    elseif strcmpi(ext, '.mat')
        % HEBI API-generated logs (.hebilog => .mat via Scope app)
        log_data = log_parsers.parse_hebilog_mat(filename);
    elseif strcmpi(ext, '.csv') && contains(name, 'continuous_log')
        % Goto-era LIBRA-I App CSV
        log_data = log_parsers.parse_old_libra_app_csv(filename);
    elseif strcmpi(ext, '.csv') && contains(name, 'shot_log')
        % Goto-era LIBRA-I App CSV (skipped; mirrors data in continuous log)
        fprintf('Detected "shot_log", skipping redundant data...')
    else
        error('Unsupported file type or invalid naming convention: %s', filename);
    end
end
