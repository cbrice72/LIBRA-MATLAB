clc; clear; close all;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% @file   histogram_stats.m
% @brief  Provides statistics on user-specified histogram data.
%         Designed to work with CSV files exported from CloudCompare, with the
%         following columns: "Class", "Value", "Class start", and "Class end".
%
% @author brice.c.aa
% @date   2026/3/11
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% SETUP

% Load data
[file, path] = uigetfile('*.csv', 'Select histogram CSV');
filepath = fullfile(path, file);
T = readtable(filepath, 'Delimiter', ';', 'VariableNamingRule', 'preserve');
T.Properties.VariableNames = {'Class', 'Value', 'ClassStart', 'ClassEnd'};

% Retrieve necessary data
values = T.Value;
centers = (T.ClassStart + T.ClassEnd) / 2;

%% CALCULATIONS

% Counts
total = sum(values);
nonzero_bins = sum(values > 0);

% Weighted mean
w_mean = sum(centers .* values) / total;

% Standard deviation
variance = sum(values .* (centers - w_mean).^2) / total;
w_std = sqrt(variance);

% Percentiles
cum_frac = cumsum(values) / total;
p25 = centers(find(cum_frac >= 0.25, 1));
p50 = centers(find(cum_frac >= 0.50, 1));
p75 = centers(find(cum_frac >= 0.75, 1));
iqr_val = p75 - p25;

%% RESULTS

fprintf('<< NOTE: The following units assume the data has been normalized to 1 meter >>\n\n');

% No. of samples used to calculate the histogram data
fprintf(' Sample count:  % d\n', total);
% Number of occupied bins; indicates how spread out the distribution is
%fprintf('Non-zero bins:  %d / %d\n\n', nonzero_bins, numel(values));

% Signed average distance between clouds; near-zero means no systematic global offset
fprintf('Weighted mean:  % .4f m\n', w_mean);
% Spread of distances around the mean; large values indicate localised distortions
fprintf('      Std dev:  % .4f m\n\n', w_std);

% 50th percentile (more outlier-resistant than mean)
fprintf(' Median (p50):  % .4f m\n', p50);
% Range of the central 50% of points; (more outlier-resistant than std dev)
fprintf('          IQR:  % .4f m (±%.4f m)\n\n', iqr_val, iqr_val/2);

% 25th percentile
fprintf('          p25:  % .4f m\n', p25);
% 75th percentile
fprintf('          p75:  % .4f m\n', p75);

%% VISUALIZATION
plot_histogram(centers, values, ...
    'Mean', w_mean, 'SD', w_std, w_mean - w_std, w_mean + w_std);
plot_histogram(centers, values, ...
    'Median',  p50, 'IQR', iqr_val/2, p25, p75);

%% FUNCTIONS
function plot_histogram(hist_centers, hist_values, center_lbl, center_val, spread_lbl, spread_val, spread_upper, spread_lower)
    font_size = 16;

    figure('Name', ['M3C2 Distance Distribution - ' center_lbl], 'Color', 'w');
    hold on;
    
    % Create histogram
    bar(hist_centers, hist_values, 1, ...
        'FaceColor', [0.2 0.4 0.6], ...
        'EdgeColor', 'none', ...
        'FaceAlpha', 0.7);
    
    %xlim([center_val - 3*spread_val, center_val + 3*spread_val]);
    xlim([-1.4, 1.4]);
    y_max_rounded = ceil(max(hist_values) / 500) * 500;
    ylim([0, y_max_rounded]);
    
    % Add statistical reference lines
    l1 = xline(center_val, '--r', 'LineWidth', 2);
    l2 = xline(spread_upper, ':g', 'LineWidth', 2);
    xline(spread_lower, ':g', 'LineWidth', 2);
    
    % Formatting
    grid on;
    ax = gca;
    ax.Color = 'w';
    ax.XColor = 'k';
    ax.YColor = 'k';
    ax.GridAlpha = 0.2;
    ax.FontSize = font_size;  % for axis ticks
    
    %title(['M3C2 Distance Distribution (n = ', num2str(total), ')'], ...
    %    'Color', 'k', ...
    %    'FontSize', f_size + 2);
    xlabel('Distance (m)', ...
        'Color', 'k', ...
        'FontSize', font_size);
    ylabel('Point Count', ...
        'Color', 'k', ...
        'FontSize', font_size);
    
    % Legend
    lgd = legend([l1, l2], ...
        {[center_lbl, ': ', num2str(center_val, '%.4f'), ' m'], ...
         [spread_lbl, ': \pm', num2str(spread_val, '%.4f'), ' m']}, ...
        'Location', 'northeast', ...
        'FontSize', font_size);
    lgd.Color = 'w';
    lgd.TextColor = 'k';
    
    hold off;
end
