clc; clear; close all

%% INITIALIZATION

% Variables:
%   - l_vec*   Initial link vectors (*optional; can be left constant)
%   - j_theta  Initial joint angles
%   - payload  Located at end effector

% Note about Coordinate System
%   X: forward/backward  (parallel to ground + arm)
%   Y: left/right        (parallel to ground, perpendicular to arm)
%   Z: up/down           (perpendicular to ground)

% Measured from the center of one end joint hole to another
%   1: Base link
%   2: 2-Dof Joint
%   3: Arm link #1 (roll, pitch)
%   4: Arm link #2 (yaw)
%   5: Arm link #3 (yaw)
%   6: Arm link #4 (pitch)
l_len =  [ 2.000 0.000 1.112 0.990 0.990 0.943];  % m
l_mass = [10.000 0.000 0.410 0.410 0.410 0.410];  % kg
l_vec = transpose([0 0 -1; 1 0 0; 1 0 0; 1 0 0; 1 0 0; 1 0 0]) .* l_len;
l_cog = l_len ./2 ;                               % center of gravity (m)

% Measured as a single HEBI x8-16 actuator plus the two connected end joints
%   1: Ground
%   2: J1 (roll, 2-Dof Joint)
%   3: J2 (pitch, 2-Dof Joint)
%   4: J3 (yaw)
%   5: J4 (yaw)
%   6: J5 (pitch)
% Assumptions:
%   - Since the ground and 2-DoF Joint are static, assume extreme mass
j_rotation = [3 1 2 3 3 2];                   % 1=Roll, 2=Pitch, 3=Yaw
j_mass = [1000 1000 1000 0.851 0.851 0.851];  % kg
j_count = size(l_vec,2);                      % number of joints

% Constants
payload = 0.000;    % kg (TODO)
g = [0; 0; -9.81];  % m/s^2

%% CALCULATIONS

% Generate j_config matrix (joint rotation axis)
j_config = zeros(3,j_count);
for i = 1:j_count
    if j_rotation(1,i) == 1
        j_config(1,i) = 1;
    elseif j_rotation(1,i) == 2
        j_config(2,i) = 1;
    else
        j_config(3,i) = 1;
    end
end

% Set up loop variables
lim_roll = [-10 10];    % 2-DoF roll limits (deg)
lim_pitch = [-10 90];   % 2-DoF pitch limits (deg)
lim_arm = [-170 170];   % horizontal arm actuators rotation limits (deg)
N = 1000;               % number of points to plot
i = 1;                  % number of points saved
peak_xy = zeros(N, 2);  % points within peak torque limit
cont_xy = zeros(N, 2);  % points within continuous torque limit

% Loop until N valid joint configurations are found
while i <= N
    % Generate random numbers in the interval (a,b)
    %   r = a + (b-a) .* rand
    rand_j1 = lim_roll(1) + (lim_roll(2)-lim_roll(1)) .* rand;
    rand_j2 = lim_pitch(1) + (lim_pitch(2)-lim_pitch(1)) .* rand;
    rand_j3 = lim_arm(1) + (lim_arm(2)-lim_arm(1)) .* rand;
    rand_j4 = lim_arm(1) + (lim_arm(2)-lim_arm(1)) .* rand;
    rand_j5 = lim_arm(1) + (lim_arm(2)-lim_arm(1)) .* rand;

    % Only j_theta (actuator angles) changes; l_vec and j_config can remain constant
    j_theta = deg2rad([0 rand_j1 rand_j2 rand_j3 rand_j4 rand_j5]);

    % Calculate forward kinematics and torque
    [j_pos,l_vec_rel,l_vec_abs,rot_mat] = calcForwardKinematics(j_theta,l_vec,j_config);
    torque = calcGravitationalTorque(l_mass,l_cog,j_mass,payload,g,l_vec_rel,rot_mat,j_config);

    % Peak torque check
    if torque <= 38
        % Continuous torque check
        peak_xy(i,:) = [j_pos(1,7) j_pos(2,7)];
        if torque <= 16
            cont_xy(i,:) = [j_pos(1,7) j_pos(2,7)];
        end

        % Increment
        i = i + 1;
    end
end

% Only keep non-zero and non-intersecting data
peak_xy_filtered = peak_xy(all(peak_xy ~= cont_xy, 2), :);
cont_xy_filtered = cont_xy(all(cont_xy ~= 0, 2), :);

% Plot data
scatter(peak_xy_filtered(:,1), peak_xy_filtered(:,2));
view(3)  % 3D

hold on
fill3([0.5;-0.5;-0.5;0.5],[0.5;0.5;-0.5;-0.5],[0;0;0;0],[0.1 0.1 0.1]);  % show "ground" square
box on
grid on

title('LIBRA Horizontal Arm Workspace @ Continuous Torque Limit (16 Nm)');
xlabel('x (m)');
xlim([-1 5]);
ylabel('y (m)');
ylim([-5 5]);

set(gca,'FontSize', 10);
set(gca,'DataAspectRatio', [1 1 1]);
