enter the name of the file we want to move, copy, unzip, and link
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# - - - MODIFY THE VARIABLES BELOW!!!!
user_id="kahwang" # hawk id of whoever is running the script
zip_filename="2026_02_03.zip" # will be date of MRI session
cur_sub_id="HYPEREPI2"
RPACS_num="E101552" # you will have to log into XNAT to get this for each subject!!! 
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# should be consistent across users
#cd scripts/quantum7T/mri_scripts/
project_name="VAM_DEV" #or HWANG_NET
if [ -d /Volumes ]; then
    echo using Volumes as root folder
    rdss_root="/Volumes/rdss_kahwang/"
    lss_root="/Volumes/lss_kahwang_hpc/"
else
    echo using mnt as root folder
    rdss_root="/mnt/cifs/rdss/rdss_kahwang/"
    lss_root="/data/backed_up/shared/Kai_WM/" #"/mnt/nfs/lss/lss_kahwang_hpc/"
fi
#argon_lss_root="/Shared/lss_kahwang_hpc/"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

#if [ -d $rdss_root ]; then
echo working on ${zip_filename}
#echo enter your uiowa password below to connect to the rdss
#/usr/bin/kinit

# check if file has already been downloaded
#if [ -f ~/${zip_filename} ]; then
#    echo file already downloaded so moving on to copying and moving
#if [ -f ${rdss_root}Kai_WM/Data_MRI/Raw_dicoms/${zip_filename} ]; then
#    echo file already downloaded and moved so continuing on to other checks
#else
echo downloading file from XNAT
cd ~
wget -O ${zip_filename} --user=${user_id} --ask-password https://rpacs.iibi.uiowa.edu/xnat/data/projects/${project_name}/subjects/${cur_sub_id}/experiments/RPACS_${RPACS_num}/scans/ALL/files?format=zip
#fi

#  File will have been downloaded to your downloads folder on Thalamege
#  From the user home folder, move the file to the "originals" folder on rdss
if [ -f ${rdss_root}Kai_WM/Data_MRI/Raw_dicoms/${zip_filename} ]; then
    echo already copied .zip to rdss
else
    echo copying .zip to rdss
    cd ~
    mv ${zip_filename} ${rdss_root}Kai_WM/Data_MRI/Raw_dicoms/
    echo file moved to Raw_dicoms folder on rdss
    #  if permission denied, run the following line, enter thalamege/rdss password, and then re-run the script
    #  /usr/bin/kinit
fi

if [ -f ${lss_root}Raw/${zip_filename} ]; then
    echo already copied .zip to argon
else
    echo copying .zip to argon
    #  go to "originals" folder and copy the file to the MRI folder on thalamege
    cd ${rdss_root}Kai_WM/Data_MRI/Raw_dicoms/
    cp ${zip_filename} ${lss_root}Raw/
    echo file copied to Raw folder on argon
fi
# if compgen -G "${lss_root}data/Quantum7T/CSVs/sub-${cur_sub_id}_*.csv" > /dev/null; then
#     echo CSVs already copied to argon
# else
#     # also copy behvaioral outputs to argon
#     cd ${rdss_root}Kai_WM/Data_MRI/
#     cp sub-${cur_sub_id}_*.csv ${lss_root}data/Quantum7T/CSVs/
# fi

session_date=$(echo ${zip_filename}| cut -d'.' -f 1) # pulls out 8 string session date (unzipped file name) without .zip
if [ -d ${lss_root}Raw/${session_date} ]; then
    echo file unzipped already so we can move on to linking
else
    cd ${lss_root}Raw/
    unzip ${zip_filename}
fi

echo Only one scan that day
echo ln -s ${session_date} ${cur_sub_id}
ln -s ${session_date} ${cur_sub_id}

echo link created for ${cur_sub_id}
echo listing out Raw folder files to double check it was created
ls
#fi