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
l_cog = l_len ./ 2;                               % center of gravity (m)

% Measured as a single HEBI x8-16 actuator plus the two connected end joints
%   1: Ground
%   2: M1 (roll, 2-Dof Joint)
%   3: M2 (pitch, 2-Dof Joint)
%   4: J1 (yaw)
%   5: J2 (yaw)
%   6: J3 (pitch)
% Assumptions:
%   - Since the ground and 2-DoF Joint are static, assume extreme mass
j_rotation = [3 1 2 3 3 2];                   % 1=Roll, 2=Pitch, 3=Yaw
j_mass = [1000 1000 1000 0.851 0.851 0.851];  % kg
j_theta = deg2rad([0 10 0 45 0 0]);           % deg
j_count = size(l_vec,2);                      % number of joints

% Constants
payload = 0.000;    % kg
g = [0; 0; -9.81];  % m/s^2

%% CALCULATIONS

% Generate j_config (joint rotation axis)
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

% Calculate forward kinematics and torque
[j_pos,l_vec_rel,l_vec_abs,rot_mat] = calcForwardKinematics(j_theta,l_vec,j_config);
torque = calcGravitationalTorque(l_mass,l_cog,j_mass,payload,g,l_vec_rel,rot_mat,j_config);

% Plot joint moments due to gravity
fig1 = figure(1);
fig1.Units = 'centimeters';
fig1.Position = [10 8 10 10];  % left, bottom, width, height

bar(torque(2:end,:),0.5);
box on;

title('Joint Moments due to Gravity');
xticklabels(["M1" "M2" "J1" "J2" "J3"]);
xlabel('Joint');
ylabel('Gravitational Torque (Nm)');
ylim([-100 100]);
legend({'Gravitational Torque'},'Location','northeast');

set(gca,'FontSize',10);

% Plot joint and link positions
fig2 = figure(2);
fig2.Units = 'centimeters';
fig2.Position = [21 8 15 15];  % left, bottom, width, height

%plot3(j_pos(1,:),j_pos(2,:),j_pos(3,:),'-ob');  % joints
patch([j_pos(1,:) nan],[j_pos(2,:) nan],[j_pos(3,:) nan],[0 torque.' nan], ...
      'Marker','o', ...
      'MarkerFaceColor','flat', ...
      'EdgeColor','interp', ...
      'FaceColor','none')
view(3)  % 3D
hold on
fill3([0.5;-0.5;-0.5;0.5],[0.5;0.5;-0.5;-0.5],[0;0;0;0],[0.1 0.1 0.1]);  % show "ground" square
%plot3(0,0,0,'ro');  % origin
box on
grid on

title('LIBRA Configuration w/ Joint Moments');
xlabel('x (m)');
xlim([-1 5]);
ylabel('y (m)');
ylim([-5 5]);
zlabel('z (m)');
zlim([-5,1]);
c = colorbar;
title(c,'Nm');

set(gca,'FontSize',10);
set(gca,'DataAspectRatio',[1 1 1]);

%% Wsolution.m

%{
fig3=figure(3);
J1=0;J2=0;J3=-170;

for j1=0:2:170
    for j2=-170:2:0
        for j3=0:2:170
            thetaDeg=[0 0 90 j1 j2 j3];
            theta=thetaDeg./180.*pi;
            
            %順運動学計算(関節位置x）
            [j_pos,l_vec_rel,l_vec_abs,rot_mat]=calcForwardKinematics(theta,LinkVector,j_config);
            if(j_pos(3,NumJoint+1) > -2-1.112-0.989-0.989) 
                [torque]=calcGravitationalTorque(l_mass,l_cog,j_mass,payload,g,l_vec_rel,rot_mat,j_config);
                if(abs(torque(4))<16 && abs(torque(5))<16 && abs(torque(6))<16)
                    J1=[J1 j1];
                    J2=[J2 j2];
                    J3=[J3 j3];                   
                end
            end
        end
    end
end

S_J1=[0,   60, 120, 170, 170];
S_J2=[0, -130,-170,-170,-170];
S_J3=[170, 90,  45, 45,  170];
p=plot3(S_J1,S_J2,S_J3,'r');
p.LineWidth = 3;
hold on

x1 = J1(:);
y1 = J2(:);
z1 = J3(:);
P = [x1 y1 z1];

% 詳細は > doc alphaShape
shp = alphaShape(P,2);
% アルファ形状の境界だけ取り出す
% 詳細は > doc boundaryFacets
[tri, xyz] = boundaryFacets(shp);
% プロット
trisurf(tri,xyz(:,1),xyz(:,2),xyz(:,3),...
    'FaceColor','cyan','FaceAlpha',0.3)
% stlWrite 関数で STL に出力
stlwrite('test.stl', tri, xyz);
set(gca,'DataAspectRatio',[1 1 1])
%}

%% LOCAL FUNCTIONS

% Tension from Torque
%   @param R      ...
%   @param delta  ...
%   @param torque Gravitational torque
%
%   @returns req_tor Required torque
%   @returns req_ten Required tension
%
%   @note This function does not consider the wires' self-weight-compensation
%
function [req_tor, req_ten] = TensionFromTorque(R, delta, torque)
    num_j = size(R,1);
    for i = num_j:-1:1
        % Calculation of torque by joint control wires fixed to corresponding joint
        if i == num_j
            req_tor(i,1) = -1 .* torque(i,1);  % minus???
        else
            req_tor(i,1) = -1 .* torque(i,1) - R(i,2*i+1:2*num_j) * req_ten(2*i+1:2*num_j,1);
        end
        
        % Wire tension calculation
        if req_tor(i,1) >= 0
            req_ten(2*i,1) = req_tor(i,1) / R(i,2*i) + delta;
            req_ten(2*i-1,1) = delta;
        else
            req_ten(2*i,1) = delta;
            req_ten(2*i-1,1) = req_tor(i,1) / R(i,2*i-1) + delta;
        end
    end
end

% Motor displacement calculation θ_A
%   @brief ...
%
%   @param R     ...
%   @param rA    ...
%   @param theta ...
%
%   @returns thetaMotorDeg ... (in degrees)
%
function theta_motor = MotorDisplace(R,rA,theta)
    j_num = size(R,1);
    
    s = zeros(1,j_num*2);
    for i = 1:j_num*2
        s(1,i) = theta*R(:,i);
    end
    
    thetaA = zeros(1,j_num*2);
    for i = 1:j_num
        thetaA(i) = s(i)/rA(1,i);
    end
    
    theta_motor = rad2deg(thetaA);
end
