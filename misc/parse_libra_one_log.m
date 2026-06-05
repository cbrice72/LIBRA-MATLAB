function logData = parse_libra_one_log(filename)
    %% @brief Selects the correct parser based on file extension and naming rules.
    
    [~, name, ext] = fileparts(filename);
    
    if strcmpi(ext, '.mat')
        logData = parse_hebilog_mat(filename);
    elseif strcmpi(ext, '.csv') && contains(name, 'continuous_log')
        logData = parse_old_libra_app_csv(filename);
    elseif strcmpi(ext, '.csv') && contains(name, 'shot_log')
        fprintf('Detected "shot_log", skipping redundant data...')
    else
        error('Unsupported file type or invalid naming convention: %s', filename);
    end
end
