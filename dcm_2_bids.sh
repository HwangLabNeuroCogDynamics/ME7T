#!/usr/bin/env bash

# note, pluma is the gedit alternative on samsara

####################################################################################################################################
#### first, run dcm2niix directly on dicom folders because we have had lots of trouble getting heudiconv to work.
#### This should allow us to check dicom info and scan parameters necessary for later conversion
####################################################################################################################################
SCANS_DIR="/data/backed_up/shared/ME_7T_Pilot/20260406/scans"
OUT_DIR="/data/backed_up/shared/ME_7T_Pilot/20260406/nii_output"

mkdir -p "$OUT_DIR"

for run in "$SCANS_DIR"/*; do
    [ -d "$run" ] || continue

    dicom_dir="$run/resources/DICOM/files"

    if [ -d "$dicom_dir" ]; then
        run_name=$(basename "$run")
        run_out="$OUT_DIR/$run_name"

        mkdir -p "$run_out"
        echo "Converting $run_name ..."
        dcm2niix -o "$run_out" "$dicom_dir"
    else
        echo "Skipping $run (no DICOM folder found)"
    fi
done


###############################################################################################################################################
#### First do the BIDS conversion. We are no longer using heudiconv, it has trouble dealing with real/phase/magnitude plus multi echo data.
#### Intead we now use dcm2bids. 
#############################################################################################################################################
SUBJECT="20260406"
PROJECT=/data/backed_up/shared/ME_7T_Pilot/
mkdir -p $PROJECT/BIDS
mkdir -p $PROJECT/code

# in terminal, do pluma $PROJECT/code/dcm2bids_config.json
#".*MP-RAGE.*"

CONTAINER=/data/backed_up/shared/software/containers/dcm2bids.sif
#CONFIG=$PROJECT/code/dcm2bids_config.json
HOST_DCM2NIIX=/data/backed_up/shared/software/dcm2niix
#mkdir -p /data/backed_up/shared/ME_7T_Pilot/BIDS
# note, the dcm2niix binary in dcm2bids's container is old so we need to bind our own

apptainer exec \
  --bind "$HOST_DCM2NIIX":/usr/bin/dcm2niix \
  --bind /data/backed_up/shared:/data/backed_up/shared \
  --bind /home:/home \
  /data/backed_up/shared/software/containers/dcm2bids.sif \
  dcm2bids \
    -d /data/backed_up/shared/ME_7T_Pilot/${SUBJECT}/scans/* \
    -p ${SUBJECT}nordic \
    -c /home/kahwang/bin/ME7T/me7T0604_NORDIC_config.json \
    -o /data/backed_up/shared/ME_7T_Pilot/BIDS \
    --clobber --force_dcm2bids

# so we get a copy of the config
cp /home/kahwang/bin/ME7T/me7T0604_NORDIC_config.json $PROJECT/code/

# looks like after this part bval bvec have to be deleted or fMRIPREP will complain


####################################################################################################################################
### Then we need to deal with the real/imag data, rename them according the MX's script, and process them throguh nordic
####################################################################################################################################
SUBJECT="20260406nordic"
RUN_DIR="/data/backed_up/shared/ME_7T_Pilot/BIDS/sub-${SUBJECT}/func/"
OUT_DIR="/data/backed_up/shared/ME_7T_Pilot/BIDS_NORDIC/sub-${SUBJECT}/func/"
NORDIC_PATH="/data/backed_up/shared/software/NORDIC_Raw"
mkdir -p "$OUT_DIR"

# if you never use matlab, you need to create a startup.m file in your matlab folder.
# edit(fullfile(userpath,'startup.m'))
# Then, add this maxNumCompThreads(24); to the startup.m file to prevent overthreading. 

# Base filename
BASE_rest="sub-${SUBJECT}_task-rest"
BASE_noise="sub-${SUBJECT}_task-noise"
for run in 01 02
do
  echo "=== Processing run $run ==="
  for echo in 1 2 3
  do
      echo "=== Processing echo $echo ==="

      # NOTE (Vince bug): ph = real, real = imaginary. It will be fixed in the future so real is real imag is ph
      # fixed for 0406
      input_real="${RUN_DIR}/${BASE_rest}_run-${run}_echo-${echo}_part-real_bold.nii.gz"
      input_imag="${RUN_DIR}/${BASE_rest}_run-${run}_echo-${echo}_part-ph_bold.nii.gz"
      output_cpx="${OUT_DIR}/${BASE_rest}_run-${run}_e${echo}_complex.nii"
      output_phase="${OUT_DIR}/${BASE_rest}_run-${run}_e${echo}_phase.nii"
      output_abs="${OUT_DIR}/${BASE_rest}_run-${run}_e${echo}_mag.nii"

      # 1. Create complex image
      3dTwotoComplex -prefix "${output_cpx}" -RI "${input_real}" "${input_imag}" -overwrite
      # 2. Extract phase
      3dcalc -prefix "${output_phase}" -cx2r PHASE -a "${output_cpx}" -expr 'a' -overwrite
      # 3. Extract magnitude
      3dcalc -prefix "${output_abs}" -cx2r ABS -a "${output_cpx}" -expr 'a' -overwrite

      #now do for noise    
      input_real="${RUN_DIR}/${BASE_noise}_run-${run}_echo-${echo}_part-real_bold.nii.gz"
      input_imag="${RUN_DIR}/${BASE_noise}_run-${run}_echo-${echo}_part-ph_bold.nii.gz"
      output_cpx="${OUT_DIR}/${BASE_noise}_run-${run}_e${echo}_complex.nii"
      output_phase="${OUT_DIR}/${BASE_noise}_run-${run}_e${echo}_phase.nii"
      output_abs="${OUT_DIR}/${BASE_noise}_run-${run}_e${echo}_mag.nii"

      # 1. Create complex image
      3dTwotoComplex -prefix "${output_cpx}" -RI "${input_real}" "${input_imag}" -overwrite
      # 2. Extract phase
      3dcalc -prefix "${output_phase}" -cx2r PHASE -a "${output_cpx}" -expr 'a' -overwrite
      # 3. Extract magnitude
      3dcalc -prefix "${output_abs}" -cx2r ABS -a "${output_cpx}" -expr 'a' -overwrite
  done
done

####################################################################################################################################
# now we attach the noise images to the end of the mag and phase data, and set noise-volume numbers in the matlab call.
# this will get empirical measured noise, otherwise nordic will default to 1
####################################################################################################################################
for run in 01 02
do
  echo "=== Processing run $run ==="
  for echo in 1 2 3
  do
      echo "=== Processing echo $echo ==="
      #output_cpx="${OUT_DIR}/${BASE_rest}_run-${run}_e${echo}_complex.nii"
      output_phase="${OUT_DIR}/${BASE_rest}_run-${run}_e${echo}_phase.nii"
      output_abs="${OUT_DIR}/${BASE_rest}_run-${run}_e${echo}_mag.nii"
      #noise_cpx="${OUT_DIR}/${BASE_noise}_run-${run}_e${echo}_complex.nii"
      noise_phase="${OUT_DIR}/${BASE_noise}_run-${run}_e${echo}_phase.nii"
      noise_abs="${OUT_DIR}/${BASE_noise}_run-${run}_e${echo}_mag.nii"
      #combined_cpx=="${OUT_DIR}/${BASE_rest}_run-${run}_e${echo}_combined_complex.nii"
      combined_phase="${OUT_DIR}/${BASE_rest}_run-${run}_e${echo}_combined_phase.nii" 
      combined_abs="${OUT_DIR}/${BASE_rest}_run-${run}_e${echo}_combined_mag.nii"             
      3dTcat -prefix "${combined_abs}" "${output_abs}" "${noise_abs}" 
      3dTcat -prefix "${combined_phase}" "${output_phase}" "${noise_phase}" 
  done
done

####################################################################################################################################
# Now Run NORDIC
# see https://github.com/SteenMoeller/NORDIC_Raw/blob/main/NIFTI_NORDIC.m
####################################################################################################################################
for run in 01 02
do
  echo "=== Processing run $run ==="
  for echo in 1 2 3
  do
      echo "=== Processing echo $echo ==="
      # sub-HYPEREPI2b_task-rest_run-02_echo-3_part-mag_bold.nii.gz
      combined_phase="${OUT_DIR}/${BASE_rest}_run-${run}_e${echo}_combined_phase.nii" 
      combined_abs="${OUT_DIR}/${BASE_rest}_run-${run}_e${echo}_combined_mag.nii"         
      output_nordic="${BASE_rest}_run-${run}_echo-${echo}_part-mag_bold"

      matlab -batch "addpath('${NORDIC_PATH}'); ARG.DIROUT='${OUT_DIR}'; ARG.noise_volume_last=6 ; NIFTI_NORDIC('${combined_abs}','${combined_phase}','${output_nordic}', ARG); exit"

      # Copy JSON from original magnitude echo
      # sub-HYPEREPI2b_task-rest_run-02_echo-3_part-mag_bold.json
      cp "${RUN_DIR}/${BASE_rest}_run-${run}_echo-${echo}_part-mag_bold.json" "${OUT_DIR}/${BASE_rest}_run-${run}_echo-${echo}_part-mag_bold.json"

      # Compress NORDIC output
      gzip -f "${OUT_DIR}/${output_nordic}.nii"

      echo "Echo $echo complete."
      
  done
done

# then copy anat folder to nordic folder
cp -r /data/backed_up/shared/ME_7T_Pilot/BIDS/sub-${SUBJECT}/anat/ /data/backed_up/shared/ME_7T_Pilot/BIDS_NORDIC/sub-${SUBJECT}/anat/
cp -r /data/backed_up/shared/ME_7T_Pilot/BIDS/sub-${SUBJECT}/fmap/ /data/backed_up/shared/ME_7T_Pilot/BIDS_NORDIC/sub-${SUBJECT}/fmap/

####################################################################################################################################
# the new BIDS_NORDIC folder should now be ready for fmriprep.
# https://fmriprep.org/en/stable/usage.html
####################################################################################################################################
rm ${OUT_DIR}/*.nii #only outputs we want are in .nii.gz

SUBJECT="20260406nordic"
fmriprep_container=/data/backed_up/shared/software/containers/fmriprep_latest.sif
apptainer exec \
--bind /data/backed_up/shared:/data/backed_up/shared \
--bind /opt/freesurfer/license.txt:/opt/freesurfer/license.txt \
${fmriprep_container} \
fmriprep /data/backed_up/shared/ME_7T_Pilot/BIDS_NORDIC \
/data/backed_up/shared/ME_7T_Pilot/fmriprep \
participant --participant_label ${SUBJECT} \
-w /data/backed_up/shared/ME_7T_Pilot/work \
--nprocs 24 \
--omp-nthreads 8 \
--force bbr \
--bold2anat-dof 12 \
--me-output-echos \
--fs-license-file /opt/freesurfer/license.txt

#--ignore slicetiming \

########################################
#### To DO's
'''
The above will only do multiple echoes combination, but will not do ME-ICA.
Looks like we need to look into doing ME-ICA outside of fMRIprep, using tedana.
https://tedana.readthedocs.io/en/stable/usage.html

'''