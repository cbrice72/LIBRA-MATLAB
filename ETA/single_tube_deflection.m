clc; clearvars; close all;

%% NOTES

%% INITIAL CONDITIONS

% Constants
g = 9.81;  % gravity (m/s^2)

% GFRP Tube
% - Geometry
L = 0.64;            % len (m)
D = 0.0489;          % outer dia (m)
d = 0.0475;          % inner dia (m)
alpha = deg2rad(0);  % rotation (rad)
% - Material Properties
rho = 2370;  % density (kg/m^3)
G = 5.0e9;   % shear modulus (Pa) [ESTIMATE]

% Payload
% - Geometry
com_pay = L;   % center of mass, or distance from origin (m)
% - Material Properties
m_pay = 1.000;  % mass (kg)

% Calculated
com_tube = L/2;    % center of mass (m)
V = getVolumeTube(D,d,L);
m_tube = rho * V;  % mass (kg)

J = getPolarMomentTube(D,d);

%% BODY

% Calculate torque from gravity
%   (NOTE: assumes horizontal orientation)
T = getTotalTorque(m_tube, com_tube, m_pay, com_pay, g);

% Calculate total deflection
theta_total = getDeflection(T,L,G,J);

% Create points along tube length
t = linspace(0,L,50);
theta_vec = (t / L) * theta_total;  % linear distribution

% Create 3D visualization
plotTubeDeflection(t, alpha, theta_vec, D, d, L, m_pay > 0);

% Display stats
fprintf('<< CONDITIONS >>\n');
fprintf('  Tube mass: %.2f kg\n', m_tube);
fprintf('  Payload mass: %.2f kg\n', m_pay);
fprintf('<< RESULTS >>\n');
fprintf('  Total torque: %.2f N-m\n', T);
fprintf('  Total deflection: %.4f rad (%.2f deg)\n', ...
        theta_total, rad2deg(theta_total));

%% FUNCTIONS

%{
    @brief Calculates the volume of a tube (m^3).

    @param D Outer diameter (m)
    @param d Inner diameter (m)
    @param L Length (m)
%}
function V = getVolumeTube(D, d, L)
    V = (pi/4) * (D^2 - d^2) * L;
end

%{
    @brief Calculates the polar moment of inertia of a tube (m^4).

    @param D Outer diameter (m)
    @param d Inner diameter (m)
%}
function J = getPolarMomentTube(D, d)
    J = (pi/32) * (D^4 - d^4);
end

%{
    @brief Calculates total torque at origin (N-m).

    @param m_tube Tube mass (kg)
    @param com_tube Tube center of mass (m)
    @param m_pay Payload mass (kg)
    @param com_pay Payload center of mass, relative to origin (m)
    @param g Gravitational acceleration (m/s^2)
%}
function T = getTotalTorque(m_tube, com_tube, m_pay, com_pay, g)
    T_tube = m_tube * g * com_tube;
    T_pay = m_pay * g * com_pay;
    
    T = T_tube + T_pay;
end

%{
    @brief Calculates torsional deflection (rad).

    @param T Applied torque (N-m)
    @param L Length (m)
    @param G Shear modulus/Modulus of rigidity (Pa)
    @param J Polar moment of inertia (unitless)
%}
function theta = getDeflection(T, L, G, J)
    theta = (T * L) / (G * J);
end

%{
    @brief Creates 3D visualization of tube under torque (in new window).

    @param t Vector of points along tube length
    @param alpha Tube angle (rad)
    @param theta_vec Vector of deflection angles along tube length
    @param D Tube outer diameter (m)
    @param d Tube inner diameter (m)
    @param L Tube length (m)
    @param show_pay Boolean flag to show payload indicator
    
%}
function plotTubeDeflection(t, alpha, theta_vec, D, d, L, show_pay)
    % Define points around tube circumference
    n_circle = 36;
    phi = linspace(0, 2*pi, n_circle);

    % Adjust tube coordinates based on relative angle
    x = t * cos(alpha);
    z = t * sin(alpha);
    
    % Create figure
    figure;
    hold on;
    
    % Plot surfaces
    plotTubeSurface(phi, x, z, theta_vec, D/2);  % outer
    plotTubeSurface(phi, x, z, theta_vec, d/2);  % inner
    
    plotEndSurface(D/2, d/2, phi, theta_vec(1), x(1), z(1));
    plotEndSurface(D/2, d/2, phi, theta_vec(end), x(end), z(end));
    
    % Add gravity vector
    i_mid = round(length(x) / 2);
    quiver3(x(i_mid), 0, z(i_mid), 0, -0.2, 0, 'r', 'LineWidth', 2);
    text(x(i_mid), - 0.3, z(i_mid) , 'g', 'Color', 'r', 'FontSize', 12);
    
    % Add payload, if present
    if show_pay
        % Calculate payload position
        x_pay = L * cos(alpha);
        y_pay = 0;  % assuming 2D deflection (in X-Z plane)
        z_pay = L * sin(alpha);
        
        % Plot payload as a red sphere
        size_pay = 0.03;  % (m)
        [Xs,Ys,Zs] = sphere(20);
        
        surf(Xs*size_pay + x_pay, ...
             Ys*size_pay + y_pay, ...
             Zs*size_pay + z_pay, ...
             'FaceColor', 'r', 'EdgeColor', 'none');
        text(x_pay, y_pay, z_pay + size_pay*1.5, ...
             'Payload', 'Color', 'r', 'FontSize', 10);
    end

    % Set up plot
    axis equal;
    grid on;
    xlabel('X (m)');
    ylabel('Y (m)');
    zlabel('Z (m)');
    title('Torsional Deflection of Tube under Gravity');
    colormap('turbo');
    view(30, 20);
end

%{
    @todo THIS IS BROKEN!

    @brief Plots a cylinder surface.

    @param phi Vector of points around tube circumference
    @param x Vector of deflected x-values
    @param z Vector of deflected z-values
    @param theta Vector of deflection angles along cylinder length
    @param r Radius of cylinder (m)
%}
function plotTubeSurface(phi, x, z, theta, r)
    % Create mesh grids for initial position and relative deflection
    [PHI, T] = meshgrid(phi, linspace(0, 1, length(x)));
    [THETA, ~] = meshgrid(theta, phi);
    
    % Calculate surface coordinates
    X = r * cos(PHI + THETA') + (1 - T') .* x(:)';
    Y = r * sin(PHI + THETA');
    Z = T' .* z(:)';

    % Plot surface
    surf(X, Y, Z, 'FaceAlpha', 0.7, 'EdgeAlpha', 0.3);
end

%{
    @brief Plots a tube end surface (i.e., ring).

    @param r_o Outer radius (m)
    @param r_i Inner radius (m)
    @param phi Vector of points around tube circumference
    @param theta Deflection angle at end cap position
    @param x X-coordinate for ring
    @param z Z-coordinate for ring
%}
function plotEndSurface(r_o, r_i, phi, theta, x, z)
    % Calculate surface coordinates
    r = linspace(r_i, r_o, 5);
    [R, PHI] = meshgrid(r, phi);
    
    X = R .* cos(PHI + theta) + x;
    Y = R .* sin(PHI + theta);
    Z = ones(size(X)) * z;

    % Plot surface
    surf(X, Y, Z, 'FaceAlpha', 0.7, 'EdgeAlpha', 0.3);
end
