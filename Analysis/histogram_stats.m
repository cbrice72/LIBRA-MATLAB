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
T = T(:, 1:4);  % just in case CSV was exported with a trailing semicolon (;)
T.Properties.VariableNames = {'Class', 'Value', 'ClassStart', 'ClassEnd'};

% Retrieve necessary data
values = T.Value;
edges = [T.ClassStart; T.ClassEnd(end)];   % (n+1) bin edges, ascending
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

%% RESULTS

fprintf('<< NOTE: The following units assume the data has been normalized to 1 meter >>\n\n');

% Name of the file being summarized
fprintf('         File:  %s\n', file);
% No. of samples used to calculate the histogram data
fprintf(' Sample count: % d\n\n', total);
% Number of occupied bins; indicates how spread out the distribution is
%fprintf('Non-zero bins:  %d / %d\n\n', nonzero_bins, numel(values));

% Signed average distance between clouds; near-zero means no systematic global offset
fprintf('Weighted mean: % .3f m\n', w_mean);
% Spread of distances around the mean; large values indicate localised distortions
fprintf('      Std dev: % .3f m\n\n', w_std);

% 25th percentile
fprintf('          p25: % .3f m\n', p25);
% 50th percentile (more outlier-resistant than mean)
fprintf(' Median (p50): % .3f m\n', p50);
% 75th percentile
fprintf('          p75: % .3f m\n', p75);
% Range of the central 50% of points; (more outlier-resistant than std dev)
fprintf('          IQR: % .3f m (±%.3f m)\n', p75 - p25, (p75 - p25)/2);

%% VISUALIZATION
plot_histograms(edges, centers, values, w_mean, w_std, p25, p50, p75);

%% FUNCTIONS

%{
    @brief Generates signed and absolute-value M3C2 distance histograms, with
           "Mean/StdDev" and "Median/IQR" variants for each (4 figures total).

    @param edges    (n+1)x1 vector of bin edges, ascending
    @param centers  Nx1 vector of bin centers
    @param values   Nx1 vector of bin counts
    @param w_mean   Weighted mean
    @param w_std    Weighted standard deviation
    @param p25      25th percentile
    @param p50      50th percentile (median)
    @param p75      75th percentile
%}
function plot_histograms(edges, centers, values, w_mean, w_std, p25, p50, p75)
    iqr_val = p75 - p25;

    % Generate signed distance histograms
    plot_histogram(centers, values, ...
        'Mean', w_mean, 'Std Dev', w_std, w_mean - w_std, w_mean + w_std, ...
        'Distance', [-1.4, 1.4]);
    plot_histogram(centers, values, ...
        'Median', p50, 'IQR', iqr_val/2, p25, p75, ...
        'Distance', [-1.4, 1.4]);

    % Generate absolute distance histograms
    % NOTE: We cannot assume bins are symmetric about zero, so we must:
    %   1) Reflect each bin about zero (splitting any bin that straddles zero)
    %   2) Redistribute them onto a new zero-based grid based on overlap
    bin_width = mean(diff(edges));
    [abs_edges, abs_values] = fold_to_abs_histogram(edges, values, bin_width);
    abs_centers = abs_edges(1:end-1) + bin_width/2;
    abs_centers = abs_centers(:);
    abs_values = abs_values(:);

    abs_total = sum(abs_values);
    abs_mean  = sum(abs_centers .* abs_values) / abs_total;
    abs_var   = sum(abs_values .* (abs_centers - abs_mean).^2) / abs_total;
    abs_std   = sqrt(abs_var);

    abs_cum_frac = cumsum(abs_values) / abs_total;
    abs_p25 = abs_centers(find(abs_cum_frac >= 0.25, 1));
    abs_p50 = abs_centers(find(abs_cum_frac >= 0.50, 1));
    abs_p75 = abs_centers(find(abs_cum_frac >= 0.75, 1));
    abs_iqr = abs_p75 - abs_p25;

    plot_histogram(abs_centers, abs_values, ...
        'Mean', abs_mean, 'Std Dev', abs_std, abs_mean - abs_std, abs_mean + abs_std, ...
        'Absolute Distance', [0, 1.4]);
    plot_histogram(abs_centers, abs_values, ...
        'Median', abs_p50, 'IQR', abs_iqr/2, abs_p25, abs_p75, ...
        'Absolute Distance', [0, 1.4]);
end

%{
    @brief Re-bin a signed histogram onto an absolute-value (>0) histogram. If a
           bin in the original data straddles zero, it is proportionally split
           into positive/negative based on its interval width. Similarly, each
           bin in the negative half of the histogram is reflected onto the
           positive axis and apportioned into existing bins based on overlap.

    @note This function assumes counts are spread uniformly within a bin.

    @param edges        (n+1)x1 vector of original bin edges, ascending
    @param values       Nx1 vector of original bin counts
    @param bin_width    Width of the new abs. value histogram

    @return abs_edges   1x(M+1) vector of new histogram bin edges
    @return abs_values  Mx1 vector of redistributed bin counts
%}
function [abs_edges, abs_values] = fold_to_abs_histogram(edges, values, bin_width)
    max_abs = max(abs(edges));
    n_abs_bins = ceil(max_abs / bin_width);
    abs_edges = (0:n_abs_bins) * bin_width;
    abs_values = zeros(n_abs_bins, 1);

    n = numel(values);
    for i = 1:n
        v = values(i);
        if v == 0
            continue;
        end
        
        local_min = edges(i);
        local_max = edges(i+1);

        if local_max <= 0
            % Left side of histogram: reflect across x=0
            add_interval(-local_max, -local_min, v);
        elseif local_min >= 0
            % Right side of histogram: leave as-is
            add_interval(local_min, local_max, v);
        else
            % Straddles x=0: split based on width, reflect negative part
            w_total = local_max - local_min;
            w_neg = -local_min;
            w_pos = local_max;
            add_interval(0, w_neg, v * w_neg / w_total);
            add_interval(0, w_pos, v * w_pos / w_total);
        end
    end

    %{
        @brief Distributes a bin count value across an abs. values histogram in
               proportion to how much the interval `[a, b)` overlaps each bin.

        @note Nested functions (such as this one) share the parent's local vars.

        @param a    Lower bound of the interval to distribute
        @param b    Upper bound of the interval to distribute
        @param val  Count value to distribute
    %}
    function add_interval(a, b, val)
        if b <= a || val == 0
            return;
        end

        width = b - a;
        k_lo = floor(a / bin_width) + 1;
        k_hi = ceil(b / bin_width);

        for k = k_lo:k_hi
            bin_lo = (k - 1) * bin_width;
            bin_hi = k * bin_width;
            ov = min(b, bin_hi) - max(a, bin_lo);
            if ov > 0
                abs_values(k) = abs_values(k) + val * (ov / width);
            end
        end
    end
end

%{
    @brief Plots a distance histogram with statistical reference lines

    @param hist_centers  Nx1 vector of bin centers
    @param hist_values   Nx1 vector of bin counts
    @param center_lbl    Label for the centerline statistic (e.g. "Mean")
    @param center_val    Value of the centerline statistic
    @param spread_lbl    Label for the spread statistic (e.g. "StdDev")
    @param spread_val    Value of the spread statistic ("+/-" in legend)
    @param spread_upper  X-position of the upper spread reference line
    @param spread_lower  X-position of the lower spread reference line
    @param dist_label    Label for the x-axis (also used as context in figure name)
    @param x_limits      1x2 vector of x-axis limits (e.g. [-1.4, 1.4])
%}
function plot_histogram(hist_centers, hist_values, center_lbl, center_val, spread_lbl, spread_val, spread_upper, spread_lower, dist_label, x_limits)
    font_size = 16;

    figure('Name', ['M3C2 ' dist_label ' Distribution - ' center_lbl], ...
           'Color', 'w');
    hold on;

    % Create histogram
    bar(hist_centers, hist_values, 1, ...
        'FaceColor', [0.2 0.4 0.6], ...
        'EdgeColor', 'none', ...
        'FaceAlpha', 0.7);

    xlim(x_limits);
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

    xlabel([dist_label ' (m)'], ...
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
