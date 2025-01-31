% Rodrigues' Rotation Formula
%   @brief An efficient algorithm for rotating a matrix in space, given an axis
%          and angle of rotation.
%
%   @param n Rotation axis
%   @param t Rotation angle
%
%   @returns R Rotated matrix
%
function R = getRaxis(n, t)
    R = [    cos(t)+n(1)^2*(1-cos(t))     n(1)*n(2)*(1-cos(t))-n(3)*sin(t) n(1)*n(3)*(1-cos(t))+n(2)*sin(t);
         n(2)*n(1)*(1-cos(t))+n(3)*sin(t)     cos(t)+n(2)^2*(1-cos(t))     n(2)*n(3)*(1-cos(t))-n(1)*sin(t);
         n(3)*n(1)*(1-cos(t))-n(2)*sin(t) n(3)*n(2)*(1-cos(t))+n(1)*sin(t)     cos(t)+n(3)^2*(1-cos(t))    ];
end
