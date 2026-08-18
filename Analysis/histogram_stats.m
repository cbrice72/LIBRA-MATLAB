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

% Global plot style variables
global MAKE_PLOTS SHOW_TITLES PNG_RESOLUTION COLOR_PRIMARY ...
       FONT_SIZE_TITLE FONT_SIZE_AXIS FONT_SIZE_LEGEND TITLE_WEIGHT TEXT_COLOR ...
       BG_COLOR GRID_COLOR LINE_WIDTH BAR_WIDTH;

MAKE_PLOTS         = false;  % whether to generate histograms (total: 4)

SHOW_TITLES        = false;
PNG_RESOLUTION     = 300;  % dpi

COLOR_PRIMARY      = [0.20, 0.40, 0.60];  % blue
TEXT_COLOR         = 'k';  % black
BG_COLOR           = 'w';  % white
GRID_COLOR         = [0.75, 0.75, 0.75];  % light gray

FONT_SIZE_TITLE    = 22;
FONT_SIZE_AXIS     = 18;
FONT_SIZE_LEGEND   = 18;
TITLE_WEIGHT       = 'bold';

LINE_WIDTH         = 2.8;
BAR_WIDTH          = 1.0;  % if 1.0, bins will seamlessly align

%% SETUP

% Load data
last_dir = getpref('HistogramStatsApp', 'LastDir', pwd);  % get previously referenced dir

[file, path] = uigetfile(fullfile(last_dir, '*.csv'), 'Select histogram CSV');
if isequal(file, 0)
    return;  % User canceled selection
end
filepath = fullfile(path, file);

setpref('HistogramStatsApp', 'LastDir', path);  % save selected dir for future runs

T = readtable(filepath, 'Delimiter', ';', 'VariableNamingRule', 'preserve');
T = T(:, 1:4);  % just in case CSV was exported with a trailing semicolon (;)
T.Properties.VariableNames = {'Class', 'Value', 'ClassStart', 'ClassEnd'};

% Retrieve necessary data
values = T.Value;
edges = [T.ClassStart; T.ClassEnd(end)];   % (n+1) bin edges, ascending
centers = (T.ClassStart + T.ClassEnd) / 2;

% Prompt user for output directory and base outfile name
output_dir = uigetdir(path, 'Select output folder');

[~, default_name, ~] = fileparts(file);  % default to input CSV name
answer = inputdlg('File basename:', 'Enter Output ID', [1 50], {default_name});
if isempty(answer) || isempty(strtrim(answer{1}))
    out_basename = default_name;
else
    out_basename = strtrim(answer{1});
end

% Prepare output log filepath and clear previous log, if any
summary_file = fullfile(output_dir, ['hist-summary_', out_basename, '.txt']);
if exist(summary_file, 'file')
    delete(summary_file);
end

%% CALCULATIONS

% Counts
total = sum(values);
nonzero_bins = sum(values > 0);

% Basic stats
active_centers = centers(values > 0);
min_val = min(active_centers);
max_val = max(active_centers);
range_val = max_val - min_val;

% Weighted mean
w_mean = sum(centers .* values) / total;

% Standard deviation
variance = sum(values .* (centers - w_mean).^2) / total;
w_std = sqrt(variance);

% Distribution shape
skewness = sum(values .* ((centers - w_mean) ./ w_std).^3) / total;
kurtosis = sum(values .* ((centers - w_mean) ./ w_std).^4) / total;

% Total absolute error
rmse = sqrt(sum(values .* (centers.^2)) / total);

% Percentiles
cum_frac = cumsum(values) / total;
p25 = centers(find(cum_frac >= 0.25, 1));
p50 = centers(find(cum_frac >= 0.50, 1));
p75 = centers(find(cum_frac >= 0.75, 1));

% Drift thresholds (for comparison w/ other CSVs)
drift_10cm = (sum(values(abs(centers) > 0.10)) / total) * 100;
drift_35cm = (sum(values(abs(centers) > 0.35)) / total) * 100;
drift_50cm = (sum(values(abs(centers) > 0.50)) / total) * 100;

%% RESULTS

diary(summary_file);

fprintf('<< NOTE: The following units assume the data has been normalized to 1 meter >>\n\n');

% Metadata
fprintf('         File:  %s\n', file);
fprintf(' Sample count: % d\n', total);
%fprintf('Non-zero bins:  %d / %d\n', nonzero_bins, numel(values));  % indicates how spread out the distribution is
fprintf('\n')

% Bounds & shape
fprintf('          Min: % .3f m\n', min_val);
fprintf('          Max: % .3f m\n', max_val);
fprintf('        Range: % .3f m\n', range_val);
fprintf('     Skewness: % .3f\n', skewness);
fprintf('     Kurtosis: % .3f\n', kurtosis);
fprintf('\n')

% Core stats
fprintf('Weighted mean: % .3f m\n', w_mean);  % near-zero means no systematic global offset
fprintf('      Std dev: % .3f m\n', w_std);  % large values indicate localised distortions
fprintf('         RMSE: % .3f m\n', rmse);
fprintf('\n')

% Quantiles
fprintf('          p25: % .3f m\n', p25);
fprintf(' Median (p50): % .3f m\n', p50);  % more outlier-resistant than mean
fprintf('          p75: % .3f m\n', p75);
fprintf('          IQR: % .3f m (±%.3f m)\n', p75 - p25, (p75 - p25)/2);  % more outlier-resistant than std dev
fprintf('\n')

% Drift thresholds
fprintf(' Drifts >10cm:  %.2f%%\n', drift_10cm);
fprintf(' Drifts >35cm:  %.2f%%\n', drift_35cm);
fprintf(' Drifts >50cm:  %.2f%%\n', drift_50cm);

diary off;  % csv-summary_[out_basename].txt

%% VISUALIZATION
if MAKE_PLOTS
    plot_histograms(output_dir, out_basename, edges, centers, values, ...
                    w_mean, w_std, p25, p50, p75);
end

%% FUNCTIONS

%{
    @brief Generates signed and absolute-value M3C2 distance histograms, with
           "Mean/StdDev" and "Median/IQR" variants for each (4 figures total).

    @param out_dir  Directory in which to place JPGs of all histograms
    @param id       Identifier to be used as base name for output files
    @param edges    (n+1)x1 vector of bin edges, ascending
    @param centers  Nx1 vector of bin centers
    @param values   Nx1 vector of bin counts
    @param w_mean   Weighted mean
    @param w_std    Weighted standard deviation
    @param p25      25th percentile
    @param p50      50th percentile (median)
    @param p75      75th percentile
%}
function plot_histograms(out_dir, id, edges, centers, values, w_mean, w_std, p25, p50, p75)
    iqr_val = p75 - p25;

    % Generate signed distance histograms
    plot_histogram(out_dir, [id, '_signed_mean-stddev'], centers, values, ...
        'Mean', w_mean, 'Std Dev', w_std, w_mean - w_std, w_mean + w_std, ...
        'Distance', [-1.4, 1.4]);
    plot_histogram(out_dir, [id, '_signed_median-iqr'], centers, values, ...
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

    plot_histogram(out_dir, [id, '_abs_mean-stddev'], abs_centers, abs_values, ...
        'Mean', abs_mean, 'Std Dev', abs_std, abs_mean - abs_std, abs_mean + abs_std, ...
        'Absolute Distance', [0, 1.4]);
    plot_histogram(out_dir, [id, '_abs_median-iqr'], abs_centers, abs_values, ...
        'Median', abs_p50, 'IQR', abs_iqr/2, abs_p25, abs_p75, ...
        'Absolute Distance', [0, 1.4]);
end

%{
    @brief Plots a distance histogram with statistical reference lines

    @param out_dir       Directory in which to place a JPG the histogram
    @param filename      File name for the JPG
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
function plot_histogram(out_dir, filename, hist_centers, hist_values, center_lbl, center_val, spread_lbl, spread_val, spread_upper, spread_lower, dist_label, x_limits)
    global SHOW_TITLES PNG_RESOLUTION COLOR_PRIMARY ...
           FONT_SIZE_TITLE FONT_SIZE_AXIS FONT_SIZE_LEGEND TITLE_WEIGHT TEXT_COLOR ...
           BG_COLOR GRID_COLOR LINE_WIDTH BAR_WIDTH;

    handle = figure('Name', ['M3C2 ' dist_label ' Distribution - ' center_lbl], ...
                    'Color', BG_COLOR);
    hold on;

    % Create histogram
    bar(hist_centers, hist_values, BAR_WIDTH, ...
        'FaceColor', COLOR_PRIMARY, ...
        'EdgeColor', 'none', ...
        'FaceAlpha', 0.7);

    xlim(x_limits);
    y_max_rounded = ceil(max(hist_values) / 500) * 500;
    ylim([0, y_max_rounded]);

    % Add statistical reference lines
    l1 = xline(center_val, '--r', 'LineWidth', LINE_WIDTH);
    l2 = xline(spread_upper, ':g', 'LineWidth', LINE_WIDTH);
    xline(spread_lower, ':g', 'LineWidth', LINE_WIDTH);

    % Formatting
    set(gca, 'Color', BG_COLOR, 'GridColor', GRID_COLOR, ...
             'FontSize', FONT_SIZE_AXIS, ...
             'XColor', TEXT_COLOR, 'YColor', TEXT_COLOR);

    if SHOW_TITLES
        title(['M3C2 ' dist_label ' Distribution - ' center_lbl], ...
              'FontSize', FONT_SIZE_TITLE, 'FontWeight', TITLE_WEIGHT, ...
              'Color', TEXT_COLOR);
    end

    xlabel([dist_label ' (m)'], ...
           'FontSize', FONT_SIZE_AXIS, 'FontWeight', TITLE_WEIGHT, ...
           'Color', TEXT_COLOR);
    ylabel('Point Count', ...
           'FontSize', FONT_SIZE_AXIS, 'FontWeight', TITLE_WEIGHT, ...
           'Color', TEXT_COLOR);

    % Legend
    legend([l1, l2], ...
           {[center_lbl, ': ', num2str(center_val, '%.4f'), ' m'], ...
            [spread_lbl, ': \pm', num2str(spread_val, '%.4f'), ' m']}, ...
           'Location', 'northeast', ...
           'Color', BG_COLOR, ...
           'FontSize', FONT_SIZE_LEGEND, 'TextColor', TEXT_COLOR);

    hold off;

    % Save as JPG
    exportgraphics(handle, fullfile(out_dir, [filename '.png']), ...
                   'Resolution', PNG_RESOLUTION);
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
