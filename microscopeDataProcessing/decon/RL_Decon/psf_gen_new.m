function [ psf ] = psf_gen_new(psf, dz_psf, dz_data, medFactor, PSFGenMethod)
%psf_gen resample and crop raw PSF
% 

if nargin < 4
    medFactor = 1.5;
end

if nargin < 5
    PSFGenMethod = 'median';
end


%load TIFF
psf_raw = double(psf);
[ny, nx, nz] = size(psf);

% subtract background estimated from the last Z section
psf_raw_fl = psf_raw(:, :, [1:5, end-5:end]);
% xruan (05/06/2021): check if the first and last slices contain positive values
if any(psf_raw_fl(:) > 0)
    switch PSFGenMethod
        case 'median'
            psf_raw = double(psf_raw) - medFactor * median(double(psf_raw_fl(psf_raw_fl > 0)));
        %     % convert all negative pixels to 0
            psf_raw(psf_raw<0) = 0.0;
        case 'masked'
        %     a = max(sqrt(abs(psf_raw([1:10, end-9:end], :, :) - 100)), [], [1, 3]) * 3  + mean(psf_raw([1:10, end-9:end], :, :), [1, 3]);
        %     a = smooth(a, 0.1, 'rloess');
        %     psf_raw = psf_raw - a';
        %     psf_raw(psf_raw<0) = 0.0;
    
            psf_med = medfilt3(double(psf), [3, 3, 3]);
            a = max(sqrt(abs(psf_med([1:10, end-9:end], :, :) - 100)), [], [1, 3]) * 3  + mean(psf_med([1:10, end-9:end], :, :), [1, 3]);
            psf_med_1 = psf_med - a;
            BW = bwareaopen(psf_med_1 > 0, 300, 26);
            psf_raw = psf_raw .* BW - mean(psf_raw([1:10, end-9:end], :, :), [1, 3]);
            psf_raw(psf_raw<0) = 0.0;
    end
end

% locate the peak pixel
[peak, peakInd] = max(psf_raw(:));
% [peakx,peaky,peakz] = ind2sub(size(psf_raw), peakInd);
% crop x-y around the peak
% psf_cropped = psf_raw(peakx-cropToSize/2:peakx+cropToSize/2, ...
%     peaky-cropToSize/2:peaky+cropToSize/2, :);
% do not crop but pad the image so that the peak is in the center
[peaky,peakx,peakz] = ind2sub(size(psf_raw), peakInd);
psf_cropped=circshift(psf_raw, round(([ny, nx, nz] + 1) / 2 - [peaky,peakx,peakz]));

% center the PSF in z; otherwise RL decon results are shifted in z
% psf_cropped=circshift(psf_cropped, [0, 0, round(nz/2-peakz)]);

[ny,nx,nz]=size(psf_cropped);
% resample PSF to match axial pixel size of raw image
dz_ratio = dz_data / dz_psf;
if dz_ratio > 1
    psf_fft=fftn(psf_cropped);
    new_nz = uint16(round(nz / dz_ratio));
    psf_fft_trunc=complex(zeros(ny,nx,new_nz));
    psf_fft_trunc(:,:,1:new_nz/2)=psf_fft(:,:,1:new_nz/2);
    psf_fft_trunc(:,:,new_nz-new_nz/2+1:new_nz)=psf_fft(:,:,nz-new_nz/2+1:nz);
    psf=real(ifftn(psf_fft_trunc));
else
    psf = psf_cropped;
end

psf(psf<0) = 0.0;
end

