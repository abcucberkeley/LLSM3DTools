% demo to analysis data from scratch for each step separately

%% Step 1: load data
% add the software to the path
addpath(genpath('../'));

%  rt is the root directory of data, you may provide root directory. If it
%  is not provided, the load condition data function will prompt out to
%  choose the root directory interactively. 

rt = '/clusterfs/fiona/xruan/Images/test_images_detection_software/2015-04-7_p505_p6_sumCLTArfp_shiga/Ex1_2minAfter_560_50mW_20p_647_150mW_20p_40ms_z0p5';

% follow the below when asking for inputs (They may be different for your own experiments):
% Enter the number of channels: 2
% click folder name 'ch1' when it first prompts out. 
% click folder name 'ch2' when it prompts out again. 
% Enter the fluorescent marker for channel 1: gfp
% Enter the fluorescent marker for channel 2: rfp
data = XR_loadConditionData3D(rt);


%% Step 2: Estimate psf sigmas if there are calibration files and they are not available (optional)
% The sigmas of psfs are estimated separately. The filename is provided as 
% input for the estimation. 
ch1_psf_filename = '/clusterfs/fiona/xruan/Images/test_images_detection_software/2015-04-7_p505_p6_sumCLTArfp_shiga/560totalPSF.tif';
[sigmaXY_ch1, sigmaZ_ch1] = GU_estimateSigma3D(ch1_psf_filename, []);
ch2_psf_filename = '/clusterfs/fiona/xruan/Images/test_images_detection_software/2015-04-7_p505_p6_sumCLTArfp_shiga/642totalPSF.tif';
[sigmaXY_ch2, sigmaZ_ch2] = GU_estimateSigma3D(ch2_psf_filename, []);

% Because in calibration (of this data), the calibration image is
% approximately isotropic, which is is not true for the data. We need to
% divide the sigma in z-axis by the Anisotropic factor in this axis. 
sigma_mat = [sigmaXY_ch1, sigmaZ_ch1 ./ data(1).zAniso; 
             sigmaXY_ch2, sigmaZ_ch2 ./ data(1).zAniso];


%% Step 3: deskew, and correct XZ offsets between channels
% name of directory that stores the results (under the primary channel directory). 
aname = 'Analysis_update_3';

% deskew movies to place z-slices in their correct relative
% physical poisitions. The results are stored in 'DS' directory under the
% channel directory. 
data = deskewData(data, 'Overwrite', true, 'SkewAngle', 31.5, 'aname', aname, ...
    'Rotate', false,'sCMOSCameraFlip', false, 'Crop', false);

% In some cases, there are some offsets between different channels, due to
% camera/microscope, especially in x and z. Here we use maximum
% cross-correlation to correct them. If there is correction, the DS results
% are overwritten. 
XR_correctXZoffsetData3D(data, 'Overwrite', true);


%% Step 4: Detection
% Detect diffraction-limited points using deskewed data.
apath = arrayfun(@(i) [i.source filesep aname filesep], data, 'unif', 0);
tic
XR_runDetection3D(data, 'Sigma', sigma_mat, 'Overwrite', true,...
    'WindowSize', [], 'ResultsPath', apath,'Mode', 'xyzAc',...
    'FitMixtures', false, 'MaxMixtures', 1, ...
    'DetectionMethod', 'lowSNR', 'BackgroundCorrection', true);
toc


%% Step 5: Tracking
% step 5.1 tracking
% Link detected points. 
data = data(~([data.movieLength]==1));
XR_runTracking3D(data, loadTrackSettings('Radius', [3, 6], 'MaxGapLength', 2), ...
    'FileName', 'trackedFeatures.mat', 'Overwrite', true, 'ResultsPath', apath);

% step 5.2 Tracking processing
% processes the track structure generated by runTracking(). It will fill
% gaps, group tracks based on whether they have gaps, merges or branching. 
XR_runTrackProcessing3D(data, 'Overwrite', true,...
    'TrackerOutput', 'trackedFeatures.mat', 'FileName', 'ProcessedTracks.mat',...
    'Buffer', [3, 3], 'BufferAll', false,...
    'FitMixtures', false, 'WindowSize', [], 'ResultsPath', apath);

% step 5.3 Rotate tracking
% rotates processed tracks to the same frame of reference as rotated stacks, with the coverslip horizontal
rotateTracks3D(data, 'Overwrite', true, 'Crop', false, 'ResultsPath', apath);


