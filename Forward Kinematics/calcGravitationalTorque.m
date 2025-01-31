% calcGravitationalTorque
%   @brief Computes the gravitational torque on each free body in a serially-linked arm.
%
%   @param l_mass    Mass of each link
%   @param l_cog     Center of gravity of each link
%   @param j_mass    Mass of each joint
%   @param payload   Arm payload
%   @param g         Gravitational acceleration
%   @param l_vec_rel Link vector (relative)
%   @param rot_mat   Rotational matrix
%   @param j_config  Configuration of each joint
%
%   @returns torque Gravitational torque
%
function torque = calcGravitationalTorque(l_mass, l_cog, j_mass, payload, g, l_vec_rel, rot_mat, j_config)
    % Determine number of joints
    num_j = size(l_mass,2);

    % Calculate relative position of center of gravity for each free body
    lg = zeros(3,num_j);
    for i = 1:num_j
        lg(:,i) = l_mass(i) / (l_mass(i)+j_mass(i)) .* l_cog(i) .* l_vec_rel(:,i);
    end
    
    % Determine mass of each free body (don't forget to include the payload!)
    M = l_mass + j_mass;
    M(num_j+1) = payload;
    
    % Calculate axial unit vector for each free body
    vec_unitaxis = zeros(3,num_j);
    for i = 1:num_j
        vec_unitaxis(:,i) = rot_mat(:,:,i) * j_config(:,i);
    end

    M_sum = M(num_j+1);  % initialize mass summation to payload mass
    for i = num_j:-1:1
        if i == num_j
            vec_torque(:,i) = M(i) .* cross(lg(:,i),g) + M_sum .* cross(l_vec_rel(:,i),g);
        else
            vec_torque(:,i) = vec_torque(:,i+1) + M(i) .* cross(lg(:,i),g) + M_sum .* cross(l_vec_rel(:,i),g);
        end
        torque(i,1) = transpose(vec_torque(:,i)) * vec_unitaxis(:,i);
        M_sum = M_sum + M(i);
    end
end
