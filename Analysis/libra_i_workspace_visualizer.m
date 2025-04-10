clc;
clear;
close all;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% @file   libra_i_workspace_visualizer.m
% @brief  Employs basic forward kinematics to plot end effector position in 3D
%         space and colorize points based on arm stability (torque feedback).
%
% @author brice.c.aa
% @date   2025/4/10
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% SETUP

% Working files
in_file = 'target_arm_configurations.xlsx';

% Physical properties
link_len = [1.112, 0.989, 1.006, 0.938]; % m, 2DJNT -L1-> J1 -L2-> J2 -L3-> J3 -L4-> End

%% BODY

% Read data from Excel file
data = readtable(in_file);

% Extract relevant data by column name
angle_col_names = {'TP_Roll_deg_', 'TP_Pitch_deg_', 'TP_J1_deg_', 'TP_J2_deg_', 'TP_J3_deg_'};
status_col_name = 'Stability';

joint_angles = table2array(data(:, angle_col_names));  % numeric matrix
torque_status = data.(status_col_name);  % cell array of strings

% Calculate end effector position at every arm configuration
num_positions = size(joint_angles, 1);
end_effector_positions = zeros(num_positions, 3);

for i = 1:num_positions
    % Extract joint angles
    angles_rad = deg2rad(joint_angles(i, :));
    roll = angles_rad(1);
    pitch = angles_rad(2);
    j1 = angles_rad(3);
    j2 = angles_rad(4);
    j3 = angles_rad(5);
    
    % Initialize transformation matrix
    T = eye(4);  % identity matrix
    
    % 2-DoF joint
    T = T * rotx(roll) * roty(pitch);  % roll & pitch in same physical location
    
    % Arm joints (translate along z-axis, then apply joint rotation)
    T = T * [1 0 0 0; 0 1 0 0; 0 0 1 link_len(1); 0 0 0 1] * rotz(j1);  % yaw
    T = T * [1 0 0 0; 0 1 0 0; 0 0 1 link_len(2); 0 0 0 1] * rotz(j2);  % yaw
    T = T * [1 0 0 0; 0 1 0 0; 0 0 1 link_len(3); 0 0 0 1] * roty(j3);  % pitch
    
    % End effector position
    end_pos = T * [0; 0; link_len(4); 1];
    end_effector_positions(i, :) = end_pos(1:3)';
end

% Determine point colors based on torque status
colors = zeros(num_positions, 3);
for i = 1:num_positions
    switch torque_status{i}
        case 'Stable (within limits)'
            colors(i, :) = [0 1 0]; % green
        case 'Borderline (exceeds continuous limits)'
            colors(i, :) = [1 1 0]; % yellow
        case 'Unstable (exceeds peak limits)'
            colors(i, :) = [1 0 0]; % red
        otherwise
            colors(i, :) = [0.5 0.5 0.5]; % gray
    end
end

% Plot end effector positions
figure;
scatter3(end_effector_positions(:, 1), end_effector_positions(:, 2), end_effector_positions(:, 3), 50, colors, 'filled');

title('Robot Arm End Effector Positions');
xlabel('X Position (m)');
ylabel('Y Position (m)');
zlabel('Z Position (m)');

grid on;
axis equal;

% Add a legend
hold on;
h1 = scatter3(NaN, NaN, NaN, 50, [0 1 0], 'filled');
h2 = scatter3(NaN, NaN, NaN, 50, [1 1 0], 'filled');
h3 = scatter3(NaN, NaN, NaN, 50, [1 0 0], 'filled');
legend([h1 h2 h3], {'Stable', 'Borderline', 'Unstable'});

%% Optional: Visualize a specific arm configuration
% Uncomment and modify this section if you want to visualize the arm itself for a specific configuration

% selected_config = 1; % Index of configuration to visualize
% 
% % Extract joint angles for this position (convert to radians)
% angles_rad = joint_angles(selected_config, :) * pi/180;
% 
% % Initialize joint positions
% joint_positions = zeros(5, 3);
% joint_positions(1, :) = [0, 0, 0]; % Base/central joint
% 
% % Calculate joint positions
% T = eye(4);
% 
% % Central joint (roll and pitch)
% T = T * rotx(angles_rad(1)) * roty(angles_rad(2));
% 
% % First joint position after central joint transformation
% T_temp = T * [0; 0; links(1); 1];
% joint_positions(2, :) = T_temp(1:3)';
% 
% % First arm joint (yaw)
% T = T * [1 0 0 0; 0 1 0 0; 0 0 1 links(1); 0 0 0 1] * rotz(angles_rad(3));
% 
% % Second joint position
% T_temp = T * [0; 0; links(2); 1];
% joint_positions(3, :) = T_temp(1:3)';
% 
% % Second arm joint (yaw)
% T = T * [1 0 0 0; 0 1 0 0; 0 0 1 links(2); 0 0 0 1] * rotz(angles_rad(4));
% 
% % Third joint position
% T_temp = T * [0; 0; links(3); 1];
% joint_positions(4, :) = T_temp(1:3)';
% 
% % Third arm joint (pitch)
% T = T * [1 0 0 0; 0 1 0 0; 0 0 1 links(3); 0 0 0 1] * roty(angles_rad(5));
% 
% % End effector position
% T_temp = T * [0; 0; links(4); 1];
% joint_positions(5, :) = T_temp(1:3)';
% 
% % Create a new figure for arm visualization
% figure;
% plot3(joint_positions(:, 1), joint_positions(:, 2), joint_positions(:, 3), 'k-', 'LineWidth', 2);
% hold on;
% scatter3(joint_positions(:, 1), joint_positions(:, 2), joint_positions(:, 3), 100, 'r', 'filled');
% scatter3(joint_positions(5, 1), joint_positions(5, 2), joint_positions(5, 3), 150, 'b', 'filled');
% xlabel('X Position (m)');
% ylabel('Y Position (m)');
% zlabel('Z Position (m)');
% title(['Robot Arm Configuration ', num2str(selected_config)]);
% grid on;
% axis equal;
% legend('Links', 'Joints', 'End Effector');


%% FUNCTIONS

%{
    @brief Creates a homogeneous transformation matrix representating a rotation
           about the X-axis.

    @param angle  Rotation angle in radians

    @return R  Rotation matrix about the X-axis
%}
function R = rotx(angle)
    R = [1 0 0 0; 0 cos(angle) -sin(angle) 0; 0 sin(angle) cos(angle) 0; 0 0 0 1];
end

%{
    @brief Creates a homogeneous transformation matrix representating a rotation
           about the Y-axis.

    @param angle  Rotation angle in radians

    @return R  Rotation matrix about the Y-axis
%}
function R = roty(angle)
    R = [cos(angle) 0 sin(angle) 0; 0 1 0 0; -sin(angle) 0 cos(angle) 0; 0 0 0 1];
end

%{
    @brief Creates a homogeneous transformation matrix representating a rotation
           about the Z-axis.

    @param angle  Rotation angle in radians

    @return R  Rotation matrix about the Z-axis
%}
function R = rotz(angle)
    R = [cos(angle) -sin(angle) 0 0; sin(angle) cos(angle) 0 0; 0 0 1 0; 0 0 0 1];
end
