clc;
clear;
close all;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% @file   libra_ii_workspace_visualizer_basic.m
% @brief  Using a list of coordinates (X,Y) determined by tracking end effector
%         position in 2D space, extrapolate to 3D space to determine workspace.
%
% @author brice.c.aa
% @date   2025/4/21
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% SETUP

% Working files
in_file = 'E:\LIBRA Archive\LIBRA-II\2024-12-09 Payload Test 1kg (no REVJNT)\profile_unfixed (bottle)_v2.txt';

% Physical properties
%min_length = 1.05; % est. minimum arm length of LIBRA-II, in m
min_length = 1.30;
% (NOTE: Depending on the accuracy of the user-set origin point in Tracker,
%        min_length may have to be adjusted from its factual 1.05 m length.
%        Play around with this number until the convex hull matches the curve
%        formed by the tip when LIBRA-II is rotating at its minimum extension)


%% BODY

% Prompt user to select input file
if isempty(in_file)
    [in_filename, in_filepath] = uigetfile({'*.txt', 'Text File (*.txt)'}, ...
        'Select the LIBRA-II track data file');
    if isequal(in_filename, 0)
        disp('User canceled file selection');
        return;
    end

    in_file = fullfile(in_filepath, in_filename);
end

% Load track data
data = load(in_file);
x = data(:, 1);
y = data(:, 2);

% Filter points used for convex hull using robot context
magnitudes = sqrt(data(:, 1).^2+data(:, 2).^2);
hull_points = data(magnitudes >= min_length, :);
x_hull = hull_points(:, 1);
y_hull = hull_points(:, 2);

% Compute convex hull to get the largest possible polygon w/o intersections
k_hull = convhull(x_hull, y_hull);

% Plot original 2D track and convex hull
figure('Name', 'LIBRA-II Workspace', 'NumberTitle', 'off');
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile
plotTrackAndHull(x, y, x_hull, y_hull, k_hull);

% Generate and plot 3D volume (workspace)
nexttile
%[x_surf, y_surf, z_surf] = generateRevolutionSurface(x_hull, y_hull);
[x_surf, y_surf, z_surf] = generateRevolutionSurface(x_hull(k_hull), y_hull(k_hull));
plotWorkspaceAndStats(x_surf, y_surf, z_surf);

% For poster, uncomment the following
%set(findall(gcf,'-property','FontSize'),'FontSize',24)


%% FUNCTIONS

%{
    @brief Plots the original 2D track data and its convex hull.

    @param x, y Coords of track points (in m)
    @param x_hull, y_hull Coords of convex hull points (in m)
    @param k_hull Indices of convex hull points
%}
function plotTrackAndHull(x, y, x_hull, y_hull, k_hull)
    % Plot original track
    plot(x, y, 'o-', 'MarkerSize', 3, 'LineWidth', 1, 'Color', [0.8, 0.8, 0]);
    hold on;

    % Plot convex hull
    plot(x_hull(k_hull), y_hull(k_hull), 'r-', 'LineWidth', 2);
    grid on;

    title('LIBRA-II Arm Tip Track and 2D Workspace');
    xlabel('X Position (m)');
    ylabel('Z Position (m)');
    axis equal;

    % Limit axes to within a small margin of the data, to avoid blank space
    xlim([0, max(x)+0.2]);
    xticks(0:1:max(x));
    ylim([-2, 2]);
    yticks(-2:1:2);

    % Plot minimum reach circle
    %   (NOTE: this is done after the axis limit since we don't care about most
    %          of the circle, just the part near the plotted points)
    min_length = 1.05;
    theta = linspace(0, 2*pi, 100);
    x = min_length * cos(theta);
    y = min_length * sin(theta);
    plot(x, y, 'b', 'LineWidth', 1.5);

    % For poster, comment the following
    legend('Original Track', 'Calculated Workspace', 'Minimum Reach (1.05 m)');
end

%{
    @brief Generates the surface points necessary for revolving a 2D profile
           around the Y-axis.

    @param x, y Coords of profile points (in m)

    @returns x_surf, y_surf, z_surf 3D surface coordinates
%}
function [x_surf, y_surf, z_surf] = generateRevolutionSurface(x, y)
    theta = linspace(0, 2*pi, 100); % evenly-spaced revolution

    % Generate surface by rotation around Y-axis
    [m, ~] = size(x);
    x_surf = zeros(m, length(theta));
    y_surf = zeros(m, length(theta));
    z_surf = zeros(m, length(theta));

    for i = 1:length(theta)
        x_surf(:, i) = x .* cos(theta(i));
        y_surf(:, i) = x .* sin(theta(i));
        z_surf(:, i) = y;
    end
end

%{
    @brief Plots the 3D workspace volume and displays statistics.

    @param x_surf, y_surf, z_surf 3D surface coordinates
%}
function plotWorkspaceAndStats(x_surf, y_surf, z_surf)
    % Plot 3D volume as orange mesh
    surf(x_surf, y_surf, z_surf, 'FaceColor', [1, 0.5, 0], 'FaceAlpha', 0.3, ...
        'EdgeColor', [1, 0.25, 0], 'LineWidth', 0.5);

    % Add axis labels and title
    title('LIBRA-II 3D Workspace (Estimated)');
    xlabel('X Position (m)');
    ylabel('Y Position (m)');
    zlabel('Z Position (m)');
    axis equal;
    grid on;

    view(-45, 30);

    % Ensure same axes as 2D Workspace graph
    zlim([-2, 2]);
    zticks(-2:1:2);

    % Add LIBRA-II base w/ directional axes for reference
    hold on;
    plotBaseAndDirections();

    % Calculate statistics
    area = polyarea(x_surf(:, 1), z_surf(:, 1));
    vol = calculateWorkspaceVolume(x_surf, y_surf);
    x_min = min(x_surf(:));
    x_max = max(x_surf(:));
    y_min = min(y_surf(:));
    y_max = max(y_surf(:));
    z_min = min(z_surf(:));
    z_max = max(z_surf(:));

    % Display volume and reach statistics
    displayWorkspaceStats(area, vol, x_min, x_max, y_min, y_max, z_min, z_max);
end

%{
    @brief Plots LIBRA-II's base (1-DoF Pitch Joint) and directional axes for reference.
%}
function plotBaseAndDirections()
    base_w = 0.125; % m
    base_h = 0.125; % m
    base_d = 0.092; % m

    vertices = [; ...
        -base_h / 2, -base_w / 2, 0; ... % front, bottom left
        base_h / 2, -base_w / 2, 0; ... % front, bottom right
        base_h / 2, base_w / 2, 0; ... % back, bottom right
        -base_h / 2, base_w / 2, 0; ... % back, bottom left
        -base_h / 2, -base_w / 2, base_d; ... % front, top left
        base_h / 2, -base_w / 2, base_d; ... % front, top right
        base_h / 2, base_w / 2, base_d; ... % back, top right
        -base_h / 2, base_w / 2, base_d; ... % back, top left
        ];

    faces = [; ...
        1, 2, 3, 4; ... % bottom
        5, 6, 7, 8; ... % top
        1, 2, 6, 5; ... % front
        2, 3, 7, 6; ... % right
        3, 4, 8, 7; ... % back
        4, 1, 5, 8; ... % left
        ];

    face_colors = {; ...
        [1, 0, 0]; ... % bottom (X)
        [1, 0, 0]; ... % top (X)
        [0, 1, 0]; ... % front (Z)
        [0, 0, 1]; ... % right (Y)
        [0, 1, 0]; ... % back (Z)
        [0, 0, 1]; ... % left (Y)
        };

    for i = 1:6
        patch('Vertices', vertices, 'Faces', faces(i, :), 'FaceColor', face_colors{i});
    end

    arrow_len = 0.5;
    quiver3(0, 0, 0, 0, 0, arrow_len, 'r', 'LineWidth', 2, 'MaxHeadSize', 0.7); % X
    quiver3(0, 0, 0, 0, arrow_len, 0, 'g', 'LineWidth', 2, 'MaxHeadSize', 0.7); % Y
    quiver3(0, 0, 0, arrow_len, 0, 0, 'b', 'LineWidth', 2, 'MaxHeadSize', 0.7); % Z

    %text(0, 0, arrow_length+0.1, 'Up', 'Color', 'r');
    %text(0, arrow_length+0.1, 0, 'Left', 'Color', 'g');
    %text(arrow_length+0.1, 0, 0, 'Forward', 'Color', 'b');
end

%{
    @brief Calculates the 3D workspace volume by revolving it via the disk
           method: `V = pi * integral(x^2 dy)`.

    @param x, y Coords of profile points (in m)

    @returns vol Workspace volume (in m³)
%}
function vol = calculateWorkspaceVolume(x, y)
    % Ensure X and Y form a closed loop
    if x(1) ~= x(end) || y(1) ~= y(end)
        x = [x; x(1, :)];
        y = [y; y(1, :)];
    end

    % Calculate the volume using numerical integration
    vol = 0;
    for i = 1:(length(x) - 1)
        % Area of polygon (in Y^2 vs X space)
        avg_radius_squared = (y(i)^2 + y(i+1)^2) / 2;
        height = abs(x(i+1)-x(i));

        % Volume of this slice
        slice_vol = pi * avg_radius_squared * height;
        vol = vol + slice_vol;
    end
end

%{
    @brief Displays workspace statistics in an annotation box.

    @param area Calculated workspace area (in m²)
    @param vol Estimated workspace volume (in m³)
    @param x_min, x_max, y_min, y_max, z_min, z_max Workspace reach extremes (in m)
%}
function displayWorkspaceStats(area, vol, x_min, x_max, y_min, y_max, z_min, z_max)
    % "Translate" statistics into human-readable string
    % - For poster, use second line with simpler printout
    info_str = sprintf( ...
        'Workspace Area (2D): %.3f m²\nWorkspace Volume: %.3f m³\nX Reach: +%.3f / %.3f m\nY Reach: +%.3f / %.3f m\nZ Reach: +%.3f / %.3f m', ...
        area, vol, x_max, x_min, y_max, y_min, z_max, z_min);
    %info_str = sprintf( ...
    %    'Workspace Area (2D): %.3f m²\nWorkspace Volume: %.3f m³', ...
    %    area, vol);

    % Determine appropriate background color for annotation
    % - For poster, use: ax_bg = 1 (we want "light mode")
    ax_bg = get(gca, 'Color');
    %ax_bg = 1;
    if mean(ax_bg) < 0.5 % dark mode
        text_color = [1, 1, 1];
        box_color = [0.2, 0.2, 0.2];
        edge_color = [0.4, 0.4, 0.4];
    else % light mode
        text_color = [0, 0, 0];
        box_color = [1, 1, 1];
        edge_color = [0.8, 0.8, 0.8];
    end

    % Add annotation to right of plot
    % - For web, use: [0.76, 0.85, 0.2, 0.1]
    % - For poster, use: [0.75, 0.90, 0.2, 0.1]
    annotation('textbox', [0.76, 0.85, 0.2, 0.1], 'String', info_str, ...
        'FitBoxToText', 'on', 'BackgroundColor', box_color, ...
        'EdgeColor', edge_color, 'Color', text_color, 'FontSize', 10);
end
