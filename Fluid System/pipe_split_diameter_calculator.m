clc; clear; close all;

%% SETUP
D = 10;  % diameter of input pipe (mm)

%% BODY
% A pipe of diameter `D` carries water at flow rate `v_D`.
% The pipe splits into two smaller pipes of diameter `d` and flow rate `v_d`.
%     v_d = (D^2 / 2*d^2) * v_D
% If we want to keep the same flow rate, we can simplify this equation.
%     D^2 = 2*d^2
% Given the diameter of the input pipe, what diameter should the output pipe be?

% 2*d^2 = D^2
% d^2 = D^2 / 2
% d = sqrt( D^2 / 2 )
d = sqrt( D^2 / 2 );
fprintf("For D = %3.1f  ->  d = %3.1f\n", D, d);

%% FUNCTIONS
