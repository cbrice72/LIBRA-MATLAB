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

% Script settings
make_summary_file = false;       % whether to save command-line summary to file
make_figures      = true;        % whether to generate histograms (total: 4)
publication_style = 'springer';  % the journal standard to follow for figures
print_full_width  = false;       % whether to save half- or full-page-width figures

% Plot style settings
style.TITLE_WEIGHT  = 'bold';
style.LABEL_WEIGHT  = 'normal';

style.COLOR_PRIMARY = [0.20, 0.40, 0.60];  % blue
style.TEXT_COLOR    = 'k';  % black
style.BG_COLOR      = 'w';  % white
style.GRID_COLOR    = [0.75, 0.75, 0.75];  % light gray

style.BAR_WIDTH     = 1.0;

if strcmpi(publication_style, 'springer')
    % https://link.springer.com/journal/40648/submission-guidelines#cms-Preparing-illustrations-and-figures
    style.FIG_UNITS        = 'centimeters';
    if print_full_width
        style.FIG_WIDTH    = 17.0;
    else
        style.FIG_WIDTH    = 8.5;
    end
    style.FIG_HEIGHT       = style.FIG_WIDTH * 0.62;  % arbitrary
    
    style.PNG_RESOLUTION   = 300;  % dpi

    style.SHOW_TITLES      = false;
    style.FONT_SIZE_TITLE  = 10;  % pt
    style.FONT_SIZE_AXIS   = 8.5;
    style.FONT_SIZE_LEGEND = 7.5;

    style.LINE_WIDTH       = 1.0;  % must be > 0.25
else
    style.LABEL_WEIGHT     = style.TITLE_WEIGHT;  % improve visibility

    style.FIG_UNITS        = 'auto';
    style.FIG_WIDTH        = 1200;
    style.FIG_HEIGHT       = style.FIG_WIDTH * 0.62;  % arbitrary

    style.PNG_RESOLUTION   = 300;
    
    style.SHOW_TITLES      = true;
    style.FONT_SIZE_TITLE  = 30;
    style.FONT_SIZE_AXIS   = 26;
    style.FONT_SIZE_LEGEND = 26;
    
    style.LINE_WIDTH       = 2.8;
end

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
if isequal(output_dir, 0)
    return;  % user canceled selection
end

[~, default_name, ~] = fileparts(file);  % default to input CSV name
answer = inputdlg('File basename:', 'Enter Output ID', [1 50], {default_name});
if isempty(answer) || isempty(strtrim(answer{1}))
    out_basename = default_name;
else
    out_basename = strtrim(answer{1});
end

% Prepare output log filepath and clear previous log, if any
if make_summary_file
    summary_file = fullfile(output_dir, ['hist-summary_', out_basename, '.txt']);
    if exist(summary_file, 'file')
        delete(summary_file);
    end
end

%% CALCULATIONS

% Counts
total = sum(values);
nonzero_bins = sum(values > 0);
if total <= 0
    error('histogram_stats:noData', 'Sum of histogram values is zero or negative; check the input CSV');
end

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

% Root-mean-square error (quadratic mean distance from zero)
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

if make_summary_file
    diary(summary_file);
end

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

if make_summary_file
    diary off;  % csv-summary_[out_basename].txt
end

% Visualizations
if make_figures
    plot_histograms(output_dir, out_basename, edges, centers, values, ...
                    w_mean, w_std, p25, p50, p75, style);
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
    @param style    Struct containing plot/figure style definitions
%}
function plot_histograms(out_dir, id, edges, centers, values, w_mean, w_std, ...
                         p25, p50, p75, style)
    iqr_val = p75 - p25;

    % NOTE: We cannot assume bins are symmetric about zero, so we must:
    %   1) Reflect each bin about zero (splitting any bin that straddles zero)
    %   2) Redistribute them onto a new zero-based grid based on overlap
    bin_width = mean(diff(edges));
    [abs_edges, abs_values] = fold_to_abs_histogram(edges, values, bin_width);
    abs_centers = abs_edges(1:end-1) + bin_width/2;
    abs_centers = abs_centers(:);
    abs_values = abs_values(:);

    abs_total = sum(abs_values);
    if abs_total <= 0
        error('histogram_stats:noAbsData', 'Absolute-value histogram has no data; check the input CSV');
    end
    abs_mean  = sum(abs_centers .* abs_values) / abs_total;
    abs_var   = sum(abs_values .* (abs_centers - abs_mean).^2) / abs_total;
    abs_std   = sqrt(abs_var);

    abs_cum_frac = cumsum(abs_values) / abs_total;
    abs_p25 = abs_centers(find(abs_cum_frac >= 0.25, 1));
    abs_p50 = abs_centers(find(abs_cum_frac >= 0.50, 1));
    abs_p75 = abs_centers(find(abs_cum_frac >= 0.75, 1));
    abs_iqr = abs_p75 - abs_p25;

    % Generate histograms
    configs = { ...
        {'_signed_mean-stddev', centers, values, ...
            'Mean', w_mean, 'StdDev', w_std, w_mean - w_std, w_mean + w_std, ...
            'Distance', [-1.4, 1.4]}, ...
        {'_signed_median-iqr', centers, values, ...
            'Median', p50, 'IQR', iqr_val/2, p25, p75, ...
            'Distance', [-1.4, 1.4]}, ...
        {'_abs_mean-stddev', abs_centers, abs_values, ...
            'Mean', abs_mean, 'StdDev', abs_std, abs_mean - abs_std, abs_mean + abs_std, ...
            'Absolute Distance', [0, 1.4]}, ...
        {'_abs_median-iqr', abs_centers, abs_values, ...
            'Median', abs_p50, 'IQR', abs_iqr, abs_p25, abs_p75, ...
            'Absolute Distance', [0, 1.4]} ...
    };

    for i = 1:numel(configs)
        c = configs{i};
        plot_histogram(out_dir, [id, c{1}], c{2}, c{3}, c{4}, c{5}, c{6}, c{7}, c{8}, c{9}, c{10}, c{11}, style);
    end
end

%{
    @brief Plots a distance histogram with statistical reference lines

    @param out_dir           Directory in which to place a JPG the histogram
    @param filename          File name for the JPG
    @param hist_centers      Nx1 vector of bin centers
    @param hist_values       Nx1 vector of bin counts
    @param center_lbl        Label for the centerline statistic (e.g. "Mean")
    @param center_val        Value of the centerline statistic
    @param spread_lbl        Label for the spread statistic (e.g. "StdDev")
    @param spread_val        Value of the spread statistic ("+/-" in legend)
    @param spread_lower      X-position of the lower spread reference line
    @param spread_upper      X-position of the upper spread reference line
    @param distribution_lbl  Label for the x-axis (also used as context in figure name)
    @param x_limits          1x2 vector of x-axis limits (e.g. [-1.4, 1.4])
    @param style             Struct containing plot/figure style definitions
%}
function plot_histogram(out_dir, filename, hist_centers, hist_values, center_lbl, center_val, ...
                        spread_lbl, spread_val, spread_lower, spread_upper, distribution_lbl, x_limits, style)
    handle = figure('Name', ['M3C2 ' distribution_lbl ' Distribution - ' center_lbl], ...
                    'Color', style.BG_COLOR, ...
                    'Units', style.FIG_UNITS, ...
                    'Position', [2, 2, style.FIG_WIDTH, style.FIG_HEIGHT]);
    hold on;

    % Create histogram
    %bar(hist_centers, hist_values, style.BAR_WIDTH, ...
    %    'FaceColor', style.COLOR_PRIMARY, ...
    %    'EdgeColor', 'none', ...
    %    'FaceAlpha', 0.7);

    % Create histogram (single patch, avoids bar edge artifacts in vectorized output)
    bin_width = mean(diff(hist_centers)) * style.BAR_WIDTH;
    edges = [hist_centers - bin_width/2; hist_centers(end) + bin_width/2];
    xs = reshape([edges(1:end-1)'; edges(2:end)'], 1, []);
    ys = reshape([hist_values'; hist_values'], 1, []);
    xs = [xs(1), xs, xs(end)];
    ys = [0, ys, 0];
    patch(xs, ys, style.COLOR_PRIMARY, 'EdgeColor', 'none', 'FaceAlpha', 0.7);

    xlim(x_limits);
    y_max_rounded = ceil(max(hist_values) / 500) * 500;
    ylim([0, y_max_rounded]);

    % Add statistical reference lines
    l1 = xline(center_val, '--r', 'LineWidth', style.LINE_WIDTH);
    l2 = xline(max(spread_lower, x_limits(1)), ':g', 'LineWidth', style.LINE_WIDTH);
    l3 = xline(min(spread_upper, x_limits(2)), ':g', 'LineWidth', style.LINE_WIDTH);

    % Format plot
    ax = gca;
    ax.Color = style.BG_COLOR;
    ax.GridColor = style.GRID_COLOR;
    ax.FontSize = style.FONT_SIZE_AXIS;
    ax.XColor = style.TEXT_COLOR;
    ax.YColor = style.TEXT_COLOR;

    if style.SHOW_TITLES
        title(['M3C2 ' distribution_lbl ' Distribution - ' center_lbl], ...
              'FontSize', style.FONT_SIZE_TITLE, 'FontWeight', style.TITLE_WEIGHT, ...
              'Color', style.TEXT_COLOR);
    end

    xlabel([distribution_lbl ' (m)'], ...
           'FontSize', style.FONT_SIZE_AXIS, 'FontWeight', style.LABEL_WEIGHT, ...
           'Color', style.TEXT_COLOR);
    ylabel('Point Count', ...
           'FontSize', style.FONT_SIZE_AXIS, 'FontWeight', style.LABEL_WEIGHT, ...
           'Color', style.TEXT_COLOR);

    % Format legend
    is_asymmetric = spread_lower < x_limits(1) || spread_upper > x_limits(2) || ...
                    (contains(distribution_lbl, 'Absolute') && strcmp(spread_lbl, 'IQR'));
    
    if is_asymmetric
        if strcmp(spread_lbl, 'IQR')
            % Only the absolute IQR is asymmetrical around the median
            lower_lbl = 'Q1'; upper_lbl = 'Q3';
        else
            lower_lbl = 'Lower'; upper_lbl = 'Upper';
        end
        
        l_dummy = plot(NaN, NaN, 'w');  % invisible handle for adding text
        lgd = legend([l1, l_dummy, l2, l3], ...
               {[center_lbl, ': ', num2str(center_val, '%.3f'), ' m'], ...
                [spread_lbl, ': ', num2str(spread_val, '%.3f'), ' m'], ...
                [lower_lbl, ': ', num2str(spread_lower, '%.3f'), ' m'], ...
                [upper_lbl, ': ', num2str(spread_upper, '%.3f'), ' m']});
    else
        lgd = legend([l1, l2], ...
               {[center_lbl, ': ', num2str(center_val, '%.3f'), ' m'], ...
                [spread_lbl, ': ±', num2str(spread_val, '%.3f'), ' m']});
    end
    
    lgd.Location = 'northeast';
    lgd.ItemTokenSize = [12, 18];  % shrink sample line length (default: [30, 18])
    lgd.Color = style.BG_COLOR;
    lgd.FontSize = style.FONT_SIZE_LEGEND;
    lgd.TextColor = style.TEXT_COLOR;

    hold off;

    % Save figure
    exportgraphics(handle, fullfile(out_dir, [filename '.png']), ...
                   'Padding', 'tight', 'Resolution', style.PNG_RESOLUTION);
    exportgraphics(handle, fullfile(out_dir, [filename '.pdf']), ...
                   'Padding', 'tight', 'ContentType', 'vector');

    close(handle);
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
