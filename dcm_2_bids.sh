#!/usr/bin/env bash

# note, pluma is the gedit alternative on samsara

# the new data are in /data/backed_up/shared/ME_7T_Pilot/Raw/11075/

####################################################################################################################################
#### Run dcm2niix directly on each series folder to inspect sidecar JSON files
#### This should allow us to check dicom info and scan parameters necessary for later conversion
#### if you are confident your config files are correct, you can skip this part. 
####################################################################################################################################
SUBJECT="11074"
PROJECT="/data/backed_up/shared/ME_7T_Pilot"
RAW_DIR="${PROJECT}/Raw/${SUBJECT}"
OUT_DIR="${RAW_DIR}/nii_output" #where dicoms are expanded into

mkdir -p "${OUT_DIR}"

for series_dir in "${RAW_DIR}"/run-*/*; do
    [ -d "${series_dir}" ] || continue

    run_name="$(basename "$(dirname "${series_dir}")")"
    series_name="$(basename "${series_dir}")"
    run_out="${OUT_DIR}/${run_name}_${series_name}"

    mkdir -p "${run_out}"

    echo "Converting ${run_name}/${series_name} ..."
    dcm2niix -o "${run_out}" "${series_dir}"
done
### after this step, you need to examine the nii sidecar json files to properly construct a config file to be used in the enxt step

###############################################################################################################################################
#### First do the BIDS conversion. We are no longer using heudiconv, it has trouble dealing with real/phase/magnitude plus multi echo data.
#### Intead we now use dcm2bids. 
#############################################################################################################################################

mkdir -p $PROJECT/BIDS
mkdir -p $PROJECT/code

CONTAINER="/data/backed_up/shared/software/containers/dcm2bids.sif"
HOST_DCM2NIIX="/data/backed_up/shared/software/dcm2niix"
CONFIG="${PROJECT}/code/me7T_11075_config.json"
# note, the dcm2niix binary in dcm2bids's container is old so we need to bind our own

apptainer exec \
  --bind "${HOST_DCM2NIIX}":/usr/bin/dcm2niix \
  --bind /data/backed_up/shared:/data/backed_up/shared \
  --bind /home:/home \
  "${CONTAINER}" \
  dcm2bids \
    -d "${RAW_DIR}"/run-*/* \
    -p "${SUBJECT}" \
    -c "${CONFIG}" \
    -o "${PROJECT}/BIDS" \
    --clobber --force_dcm2bids

# so we get a copy of the config
cp /home/kahwang/bin/ME7T/me7T_11075_config.json $PROJECT/code/


### 
# looks like after this part bval bvec have to be deleted or fMRIPREP will complain
# but given we are recreating BIDS after NORDIC, should be ok?

####################################################################################################################################
### Then we need to deal with the real/imag data, rename them according the MX's script, and process them throguh nordic
####################################################################################################################################
SUBJECT="11075"
RUN_DIR="/data/backed_up/shared/ME_7T_Pilot/BIDS/sub-${SUBJECT}/func/"

# We are creating a separat BIDS folder that has real/imag data for NORDIC
OUT_DIR="/data/backed_up/shared/ME_7T_Pilot/BIDS_NORDIC/sub-${SUBJECT}/func/"
NORDIC_PATH="/data/backed_up/shared/software/NORDIC_Raw"
mkdir -p "$OUT_DIR"

# if you never use matlab, you need to create a startup.m file in your matlab folder.
# edit(fullfile(userpath,'startup.m'))
# Then, add this maxNumCompThreads(24); to the startup.m file to prevent overthreading. 

# Base filename
BASE_rest="sub-${SUBJECT}_task-HCC"
BASE_noise="sub-${SUBJECT}_task-noise"
for run in 01 02 03 04 05; 
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
      #input_real_noise="${RUN_DIR}/${BASE_noise}_run-${run}_echo-${echo}_part-real_bold.nii.gz"
      #input_imag_noise="${RUN_DIR}/${BASE_noise}_run-${run}_echo-${echo}_part-ph_bold.nii.gz"
      #output_cpx_noise="${OUT_DIR}/${BASE_noise}_run-${run}_e${echo}_complex.nii"
      #output_phase_noise="${OUT_DIR}/${BASE_noise}_run-${run}_e${echo}_phase.nii"
      #output_abs_noise="${OUT_DIR}/${BASE_noise}_run-${run}_e${echo}_mag.nii"

      # 1. Create complex image
      #3dTwotoComplex -prefix "${output_cpx_noise}" -RI "${input_real_noise}" "${input_imag_noise}" -overwrite
      # 2. Extract phase
      #3dcalc -prefix "${output_phase_noise}" -cx2r PHASE -a "${output_cpx_noise}" -expr 'a' -overwrite
      # 3. Extract magnitude
      #3dcalc -prefix "${output_abs_noise}" -cx2r ABS -a "${output_cpx_noise}" -expr 'a' -overwrite
  done
done

####################################################################################################################################
# now we attach the noise images to the end of the mag and phase data, and set noise-volume numbers in the matlab call.
# this will get empirical measured noise, otherwise nordic will default to 1
####################################################################################################################################
# for run in 01 02
# do
#   echo "=== Processing run $run ==="
#   for echo in 1 2 3
#   do
#       echo "=== Processing echo $echo ==="
#       #output_cpx="${OUT_DIR}/${BASE_rest}_run-${run}_e${echo}_complex.nii"
#       output_phase="${OUT_DIR}/${BASE_rest}_run-${run}_e${echo}_phase.nii"
#       output_abs="${OUT_DIR}/${BASE_rest}_run-${run}_e${echo}_mag.nii"
#       #noise_cpx="${OUT_DIR}/${BASE_noise}_run-${run}_e${echo}_complex.nii"
#       noise_phase="${OUT_DIR}/${BASE_noise}_run-${run}_e${echo}_phase.nii"
#       noise_abs="${OUT_DIR}/${BASE_noise}_run-${run}_e${echo}_mag.nii"
#       #combined_cpx=="${OUT_DIR}/${BASE_rest}_run-${run}_e${echo}_combined_complex.nii"
#       combined_phase="${OUT_DIR}/${BASE_rest}_run-${run}_e${echo}_combined_phase.nii" 
#       combined_abs="${OUT_DIR}/${BASE_rest}_run-${run}_e${echo}_combined_mag.nii"             
#       3dTcat -prefix "${combined_abs}" "${output_abs}" "${noise_abs}" 
#       3dTcat -prefix "${combined_phase}" "${output_phase}" "${noise_phase}" 
#   done
# done

####################################################################################################################################
# Now Run NORDIC
# see https://github.com/SteenMoeller/NORDIC_Raw/blob/main/NIFTI_NORDIC.m
####################################################################################################################################
for run in 01 02 03 04 05
do
  echo "=== Processing run $run ==="
  for echo in 1 2 3
  do
      echo "=== Processing echo $echo ==="
      # sub-HYPEREPI2b_task-rest_run-02_echo-3_part-mag_bold.nii.gz
      
      # if you have noise data, use these
      #combined_phase="${OUT_DIR}/${BASE_rest}_run-${run}_e${echo}_combined_phase.nii" 
      #combined_abs="${OUT_DIR}/${BASE_rest}_run-${run}_e${echo}_combined_mag.nii"         
      
      # if you don't have noise data, use theses
      combined_phase="${OUT_DIR}/${BASE_rest}_run-${run}_e${echo}_phase.nii" 
      combined_abs="${OUT_DIR}/${BASE_rest}_run-${run}_e${echo}_mag.nii"  

      output_nordic="${BASE_rest}_run-${run}_echo-${echo}_part-mag_bold"

      ##################### Important!! ###################################################################
      ### for subjects with no noise scan, use  ARG.noise_volume_last=0, otherwise ARG.noise_volume_last=6
      ###################################################################################################
      matlab -batch "addpath('${NORDIC_PATH}'); ARG.DIROUT='${OUT_DIR}'; ARG.noise_volume_last=0 ; NIFTI_NORDIC('${combined_abs}','${combined_phase}','${output_nordic}', ARG); exit"

      # Copy JSON from original magnitude echo
      # sub-HYPEREPI2b_task-rest_run-02_echo-3_part-mag_bold.json
      cp "${RUN_DIR}/${BASE_rest}_run-${run}_echo-${echo}_part-mag_bold.json" "${OUT_DIR}/${BASE_rest}_run-${run}_echo-${echo}_part-mag_bold.json"

      # Compress NORDIC output
      gzip -f "${OUT_DIR}/${output_nordic}.nii"

      echo "Echo $echo complete."
      
  done
done
rm ${OUT_DIR}/*.nii #only outputs we want are in .nii.gz

# then copy anat folder to nordic BIDS folder
cp -r /data/backed_up/shared/ME_7T_Pilot/BIDS/sub-${SUBJECT}/anat/ /data/backed_up/shared/ME_7T_Pilot/BIDS_NORDIC/sub-${SUBJECT}/anat/
cp -r /data/backed_up/shared/ME_7T_Pilot/BIDS/sub-${SUBJECT}/fmap/ /data/backed_up/shared/ME_7T_Pilot/BIDS_NORDIC/sub-${SUBJECT}/fmap/


###### IMPORTANT!! ##################################################################################################################
### important, remember to add "IntendedFor" fields to the fmap json files before running fmriprep.
##########################################################################################################################################
SUBJECT=11075
BIDS_DIR="/data/backed_up/shared/ME_7T_Pilot/BIDS_NORDIC/sub-${SUBJECT}"
FMAP_DIR="${BIDS_DIR}/fmap"

# Build the list of functional targets relative to the subject directory
mapfile -t INTENDED_FOR < <(
    cd "${BIDS_DIR}" && \
    find func -maxdepth 1 -type f -name '*_bold.nii.gz' | sort
)

# Convert list to JSON array
INTENDED_JSON=$(printf '%s\n' "${INTENDED_FOR[@]}" | jq -R . | jq -s .)

# Update every fmap JSON in place
for json in "${FMAP_DIR}"/*.json; do
    tmp="${json}.tmp"
    jq --argjson intended "$INTENDED_JSON" \
       '.IntendedFor = $intended' \
       "${json}" > "${tmp}" && mv "${tmp}" "${json}"
    echo "Updated ${json}"
done

####################################################################################################################################
# the new BIDS_NORDIC folder should now be ready for fmriprep.
# https://fmriprep.org/en/stable/usage.html
# https://mriqc.readthedocs.io/en/latest/
####################################################################################################################################


SUBJECT="11075"
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
--omp-nthreads 10 \
--force bbr \
--bold2anat-dof 12 \
--me-output-echos \
--fs-license-file /opt/freesurfer/license.txt

#--ignore slicetiming \


# MRIQC
SUBJECT="11075"
mriqc_container=/data/backed_up/shared/software/containers/mriqc_latest.sif
apptainer exec \
--bind /data/backed_up/shared:/data/backed_up/shared \
${mriqc_container} \
mriqc /data/backed_up/shared/ME_7T_Pilot/BIDS_NORDIC /data/backed_up/shared/ME_7T_Pilot/MRIQC participant \
-w /data/backed_up/shared/ME_7T_Pilot/work \
--participant-label ${SUBJECT} --nprocs 10 --omp-nthreads 10


########################################
#### To DO's
'''
The above will only do multiple echoes combination, but will not do ME-ICA.
Looks like we need to look into doing ME-ICA outside of fMRIprep, using tedana.
https://tedana.readthedocs.io/en/stable/usage.html

'''