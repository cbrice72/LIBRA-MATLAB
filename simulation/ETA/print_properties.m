clc; clearvars; close all;

%% NOTES

% ETA
% - Physical properties are taken from Yuji Fujitsuka's thesis (pp. 9-10).
% - Mechanical properties with the comment [ESTIMATE] are conservative estimates
%    based on assessments by ChatGPT of ABS and e-glass fiber products. 

%% ETA

% Physical Properties
%   (NOTE: listed from u_16 to u_1)
D = [52.7, 48.9, 46.1, 43.6, 40.9, 38.3, 35.8, 33.2, ...
     30.6, 28.3, 25.6, 23.3, 20.8, 18.3, 16.0, 13.4];  % outer diameter (mm)
d = [50.1, 47.5, 44.5, 42.3, 39.5, 37.0, 34.5, 32.0, ...
     29.5, 27.0, 24.6, 22.0, 19.5, 17.0, 15.0, 12.2];  % inner diameter (mm)
L = [650, 640, 640, 640, 640, 640, 640, 640, ...
     640, 640, 640, 640, 640, 640, 600, 600];  % pipe length (mm)
m = [227.7, 160.8, 155.0, 152.0, 138.9, 130.6, 123.3, 114.7, ...
      99.5,  93.2,  84.7,  75.5,  67.4,  59.2,  45.0,  38.6];  % weight (g)

% Mechanical Properties
% - ABS (u_16)
rho_abs = 1060;  % density (kg/m^3)
E_abs = 2.0e9;   % Young's modulus (Pa) [ESTIMATE]
G_abs = 0.8e9;   % shear modulus (Pa) [ESTIMATE]
% - GFRP (u_1-15)
rho_gfrp = 2370;  % density (kg/m^3)
E_gfrp = 35.0e9;  % Young's modulus (Pa) [ESTIMATE]
G_gfrp = 5.0e9;  % shear modulus (Pa) [ESTIMATE]

%% BODY

% Output data in the same order I have to input it to Simulink
for i = 1:1:length(D)
    % Calculate radius and thickness
    radius = D(i) / 2;
    thickness = (D(i) - d(i)) / 2;
    length = L(i);

    % Retrieve corresponding material properties
    if i == 1  % u_16
        rho = rho_abs;
        E = E_abs;
        G = G_abs;
    else
        rho = rho_gfrp;
        E = E_gfrp;
        G = G_gfrp;
    end

    % Display the output for the current segment
    fprintf("Segment u_%d:\n", 17-i);
    fprintf("  Radius (mm): %.2f\n  Thickness (mm): %.2f\n  Length (mm): %.0f\n\n", ...
            radius, thickness, length);
    fprintf("  Density (kg/m^3): %.0f\n  Young's Modulus (GPa): %.1f\n  Shear Modulus (GPa): %.1f\n\n", ...
            rho_gfrp, E_gfrp / 1e9, G_gfrp / 1e9);

    % Wait for user input to continue to the next segment
    input('Press ENTER to continue...'); 
end

%% FUNCTIONS

% (none)
