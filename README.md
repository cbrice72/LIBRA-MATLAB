# LIBRA_MATLAB

Collection of MATLAB scripts, apps, and Simulink models for use in the LIBRA project.

- [Analysis](#analysis)
- [ETA](#eta)
- [Fluid System](#fluid-system)
- [Forward Kinematics](#forward-kinematics)
- [Revolute Joint](#revolute-joint)
- [Other Info](#other-info)
    - [*Formatting*](#formatting)

## Analysis

Analysis scripts for handling output files from other applications (e.g., LIBRA-app, CloudCompute).

## ETA

Simulink models and scripts defining the Elastic Telescopic Arm, or ETA, used as the arm/manipulator on `LIBRA-II`.

## Fluid System

Helper scripts related to the fluid-based counterweight system used by both `LIBRA-I` and `LIBRA-II`.

## Forward Kinematics

Apps and scripts defining forward kinematics calculations and visualizations of `LIBRA-I`; loosely based on Yuto Goto's forward kinematics script.

## Revolute Joint

Helper scripts related to the revolute joint on `LIBRA-II` (sometimes called `REVJNT`).

---

## Other Info

### *Formatting*

You can use the included M-script [MBeautifier](https://github.com/davidvarga/MBeautifier) to format your code.
To add `format-code` as a MATLAB command to edit your active file, edit/create the following files in your MATLAB user path (if you're not sure where that is, type `userpath` into your Command window).

#### **startup.m**

Make sure to replace `<PATH-TO-THIS-REPO>` with the full path to this repository.

```matlab
% MBeautifier - MATLAB Code Formatting
addpath("<PATH-TO-THIS-REPO>\thirdparty\MBeautifier")
```

#### **format_code.m**

```matlab
function format_code()
    MBeautify.formatCurrentEditorPage();
end
```
