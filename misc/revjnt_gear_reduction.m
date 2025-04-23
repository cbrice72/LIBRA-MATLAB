clc; clear; close all;

%% SETUP
% Maxon combined actuator
%   See "Maxon RE 40 Motor.pdf" and "Maxon GP 42 C Planetary Gearhead.pdf"
m_t   = 94.9;  % nominal torque (mNm)
m_rpm = 6380;  % nominal speed (rpm)
m_rr  =   21;  % reduction (unitless)

% Internal gear
%   See https://geargenerator.com/beta/#Jcjh8PNHgCH0ViWeBLm4mlmMb6@fbt8Epb5ZRKXLRtp3OWbYhDKhbGyM76MOJ$He0qB7
ig_rr = 3.31;  % reduction (unitless)

%% BODY
% Maxon actuator calculations
[a_t, a_rpm] = GearReduction(m_t, m_rpm, m_rr);
fprintf("[IN]\n");
fprintf("  Motor torque:              %7.2f mNm\n", m_t);
fprintf("  Motor rpm:                 %7.2f rpm\n", m_rpm);
fprintf("  Gearhead reduction ratio:  %7.2f\n", m_rr);
fprintf("  -------------------------\n");
fprintf("  Combined actuator torque:  %7.2f mNm\n", a_t);
fprintf("  Combined actuator rpm:     %7.2f rpm\n", a_rpm);

% Internal gear calculations
[ig_t, ig_rpm] = GearReduction(a_t, a_rpm, ig_rr);
fprintf("[OUT]\n");
fprintf("  Reduction ratio:           %7.2f\n", ig_rr);
fprintf("  -------------------------\n");
fprintf("  Internal gear torque:      %7.2f mNm\n", ig_t);
fprintf("  Internal gear rpm:         %7.2f rpm\n", ig_rpm);

% Summary
fprintf("[SUMMARY]\n");
per_t = (ig_t / m_t) * 100;
fprintf("  Torque increase:  %9.4f%%\n", per_t);
per_rpm = (ig_rpm / m_rpm) * 100;
fprintf("  RPM decrease:     %9.4f%%\n", per_rpm);

%% FUNCTIONS
function out_torque = GearReductionTorque(in_torque, gear_ratio)
    % GEARREDUCTIONTORQUE  Calculates output torque after gear reduction.
    %
    %   in_torque  (Nm)
    %   gear_ratio (unitless)
    %   out_torque (Nm)
    out_torque = in_torque * gear_ratio;
end

function out_rpm = GearReductionRpm(in_rpm, gear_ratio)
    % GEARREDUCTIONRPM  Calculates output RPM after gear reduction.
    %
    %   in_torque  (rpm)
    %   gear_ratio (unitless)
    %   out_torque (rpm)
    out_rpm = in_rpm / gear_ratio;
end

function [out_torque, out_rpm] = GearReduction(in_torque, in_rpm, gear_ratio)
    % GEARREDUCTION  Calculates output torque after gear reduction.
    %
    %   in_torque  (rpm)
    %   gear_ratio (unitless)
    %   out_torque (rpm)
    out_torque = GearReductionTorque(in_torque, gear_ratio);
    out_rpm = GearReductionRpm(in_rpm, gear_ratio);
end
