% calcForwardKinematics
%   @brief Computes the position of an end effector using joint values for a serially-linked arm.
%
%   @param theta    Rotation angle
%   @param l_len    Length of each link
%   @param j_config Configuration of each joint
%
%   @returns j_pos     Joint positions
%   @returns l_vec_rel Link vector (relative)
%   @returns l_vec_abs Link vector (absolute)
%   @returns rot_mat   Rotational matrix
%
function [j_pos, l_vec_rel, l_vec_abs, rot_mat] = calcForwardKinematics(theta, l_len, j_config)
    % Determine number of joints
    num_j = size(theta,2);

    % Generate rotation transformation matrix
    theta_rot_mat = zeros(3,3,num_j);
    for i = 1:num_j
        theta_rot_mat(:,:,i) = getRaxis(j_config(:,i),theta(1,i));
    end

    % Calculate angles
    rot_mat = zeros(3,3,num_j);
    for i = 1:num_j
        if i == 1
            rot_mat(:,:,i) = theta_rot_mat(:,:,i);
        else
            rot_mat(:,:,i) = rot_mat(:,:,i-1) * theta_rot_mat(:,:,i);
        end
    end
    
    % Calculate link vectors
    l_vec_rel = zeros(3,num_j);
    for i = 1:num_j
        l_vec_rel(:,i) = rot_mat(:,:,i) * l_len(:,i);
    end
    
    l_vec_abs = zeros(3,num_j);
    for i = 1:num_j
        if i == 1
            l_vec_abs(:,i) = l_vec_rel(:,i);
        else
            l_vec_abs(:,i) = l_vec_abs(:,i-1) + l_vec_rel(:,i);
        end
    end
    
    % Calculate each joint coordinate (tip is last)
    j_pos = zeros(3,num_j+1);
    for i = 1:num_j
        j_pos(:,i+1) = j_pos(:,i) + l_vec_rel(:,i);
    end
end
