function log_data = parse_rosbag2_dir(bag_directory)
    %% @brief Parses a ROS2 `rosbag2` log directory into a standard analysis
    %         structure.
    %
    % @note Data is already in joint space (e.g., Roll & Pitch not MA & MB)
    %       with the correct signs, so no further conversion/correction necessary.
    
    if ~exist(bag_directory, 'dir')
        error('Rosbag2 directory %s does not exist.', bag_directory);
    end
    
    % Open bag using ROS Toolbox database reader
    bag = ros2bag(bag_directory);
    
    % Target joint states topic
    topic_name = '/robot_state'; 
    topic_select = select(bag, 'Topic', topic_name);
    
    if topic_select.NumMessages == 0
        error('Could not find "%s" messages in bag: %s', topic_name, bag_directory);
    end
    
    % Parse bag
    msgs = readMessages(topic_select);
    N = length(msgs);
    
    joints = {'Roll', 'Pitch', 'J1', 'J2', 'J3'};  % assume LIBRA-I joint order & names
    
    time_sec   = zeros(N, 1);
    target_pos = zeros(N, 5);
    actual_pos = zeros(N, 5);
    actual_trq = zeros(N, 5);
    
    for i = 1:N
        % Convert ROS 2 header timestamp to total elapsed seconds
        sec = double(msgs{i}.header.stamp.sec);
        nsec = double(msgs{i}.header.stamp.nanosec);
        time_sec(i) = sec + (nsec * 1e-9);
        
        % Extract vectors (limit to first 5 actuators to ignore static joint)
        raw_target_pos = zeros(1, 5);  % TODO: hebi_thread doesn't publish this yet
        raw_actual_pos = double(msgs{i}.position(1:5))';
        raw_actual_trq = double(msgs{i}.effort(1:5))';
        
        target_pos(i, :) = rad2deg(raw_target_pos);  % published in rad
        actual_pos(i, :) = rad2deg(raw_actual_pos);
        actual_trq(i, :) = raw_actual_trq;
    end
    
    % Normalize timestamps to start of log
    if N > 0
        time_sec = time_sec - time_sec(1);
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
