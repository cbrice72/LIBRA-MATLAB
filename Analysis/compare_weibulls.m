clc; clear; close all;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% @file   compare_weibulls.m
% @brief  Compares the Three-Parameter Weibull PDF for multiple point clouds.
%         Designed to work with CSV files exported from CloudCompute, with the
%         following columns: "Class", "Value", "Class start", and "Class end".
%
% @author brice.c.aa
% @date   2024/10/3
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% SETUP
% Three-Parameter Weibull functions
wbl3pdf = @(x,a,b,c) wblpdf(x-c,a,b);
wbl3cdf = @(x,a,b,c) wblcdf(x-c,a,b);

% Dataset selection
%   Pick any of the following: lighting-experiment, rtabmap-rgbd
dataset_str = "rtabmap-rgbd";

if ~contains(dataset_str, ["lighting-experiment", "rtabmap-rgbd"])
    error("Invalid dataset!")
end

% Parameters (a, b, shift)
if contains(dataset_str, "lighting-experiment", IgnoreCase=true)
    params = [
        0.969855, 0.040749, 0.000118;  % Light-0
        0.817631, 0.035734, 0.000209;  % Light-45
        0.780416, 0.081520, 0.000291   % Light-90
    ];
elseif contains(dataset_str, "rtabmap-rgbd", IgnoreCase=true)
    params = [
        0.972623, 0.040118, 0.000616;  % RTAB-Map using RealSense `infra1/2`
        1.034524, 0.048516, 0.000309;  % SfM (hloc) using RealSense `color`
    ];
end

% Values (x)
if contains(dataset_str, "lighting-experiment", IgnoreCase=true)
    filepaths = {
        'E:\LIBRA Archive\2024-10-01_RealSense-Indirect-Lighting-Experiment\light-0\color\weibull-pdf.csv';
        'E:\LIBRA Archive\2024-10-01_RealSense-Indirect-Lighting-Experiment\light-45\color\weibull-pdf.csv';
        'E:\LIBRA Archive\2024-10-01_RealSense-Indirect-Lighting-Experiment\light-90\color\weibull-pdf.csv'
    };
elseif contains(dataset_str, "rtabmap-rgbd", IgnoreCase=true)
    filepaths = {
        'E:\LIBRA Archive\2025-04-25 LIBRA-I RTAB-Map (RealSense only)\maps\rgbd-only\weibull-pdf_rtabmap.csv';
        'E:\LIBRA Archive\2025-04-25 LIBRA-I RTAB-Map (RealSense only)\maps\rgbd-only\weibull-pdf_sfm.csv'
    };
end

%% BODY
% Prepare plot
fig = figure('Position', [100, 100, 800, 600]);
hist_colors = {'#A2142F', '#77AC30', '#0072BD'};  % muted RGB
wbl_colors = {'r', 'g', 'b'};                     % bright RGB

% Loop variables
max_x = 0;                                % used to determine ylim
ks_results = cell(length(filepaths), 1);  % for KS test

% Calculate Weibull and GoF for every input
for i = 1:length(filepaths)
    fprintf('Processing input %d/%d...\n', i, length(filepaths));

    % Read data
    data = readtable(filepaths{i}, 'Delimiter', ';');
    
    % Get parameters
    x = data.Value;
    a = params(i, 1);
    b = params(i, 2);
    shift = params(i, 3);

    % Plot histogram (raw data)
    midpoint = (data.ClassStart + data.ClassEnd) / 2;
    bar(midpoint, x, "FaceColor", hist_colors{i});
    hold on;

    max_x = max(max_x, max(x));  % update max_count

    % Calculate and plot Three-Parameter Weibull PDF
    % TODO: couldn't get this working like in CloudCompare...
    %y = wbl3pdf(x, a, b, shift);
    %scale_factor = numel(x) * (max(x) - min(x)) / numel(y);
    %plot(midpoint, y * scale_factor, wbl_colors{i}, 'LineWidth', 2);

    % Calculate Kolmogorov-Smirnov test (GoF)
    cdf_vals = wbl3cdf(x, a, b, shift);
    cdf_mat = sortrows([x cdf_vals], 1);
    [h, p, ks_stat] = kstest(x, 'CDF', cdf_mat);
    ks_results{i} = sprintf('KS stat=%.4f, p-value=%.4f', ks_stat, p);
end

fprintf('Finished with calculations!\n');

% Set axis limits and labels
xlim([0 0.3]);
xticks(0:0.1:0.3);
xlabel('C2C absolute distances');

y_max = ceil(max_x ./ 2500) .* 2500;  % round to nearest 5000
ylim([0 y_max]);
yticks(0:2500:y_max);
ylabel('Count');

% Graph labels
if contains(dataset_str, "lighting-experiment", IgnoreCase=true)
    % Add title
    % TODO: couldn't get this working like in CloudCompare, so different title...
    %title({'Three-Parameter Weibull PDF Comparison', 'Light-0, Light-45, Light-90'});
    title({'Cloud-to-Cloud Distance Comparison', 'Light-0, Light-45, Light-90'});

    % Add legend
    % TODO: couldn't get this working like in CloudCompare, so different legend...
    %legend('Light-0 Data', 'Light-0 Weibull', ...
    %       'Light-45 Data', 'Light-45 Weibull', ...
    %       'Light-90 Data', 'Light-90 Weibull', ...
    %       'Location', 'best', 'FontSize', 10);
    legend('Light-0 Data', 'Light-45 Data', 'Light-90 Data', ...
           'Location', 'best', 'FontSize', 10);

    % Labels for print summary
    data_labels = ["Light-0", "Light-45", "Light-90"];

elseif contains(dataset_str, "rtabmap-rgbd", IgnoreCase=true)
    % Add title
    title({'Cloud-to-Cloud Distance Comparison', 'RTAB-Map, SfM ("rgbd-only" dataset)'});
    
    % Add legend
    legend('RTAB-Map Data', 'SfM Data', ...
           'Location', 'best', 'FontSize', 10);

    % Labels for print summary
    data_labels = ["RTAB-Map", "SfM"];
end

% Enhance grid
grid on;
grid minor;

% Save off figure
fig_filename = 'weibull_comparison.png';
saveas(fig, fig_filename);

fprintf('Saved figure as: %s\n', fig_filename);

% Print summary
for i = 1:size(params, 1)
    fprintf('\n%s Summary:\n', data_labels(i))
    % Weibull params
    fprintf('  a=%.6f, b=%.6f, shift=%.6f\n', params(i,:));
    % KS test
    fprintf('  %s\n', ks_results{i});
end

%% FUNCTIONS
