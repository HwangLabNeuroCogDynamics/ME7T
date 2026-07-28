# #!/bin/bash

EXP="RPACS_E109440"
BASE="https://rpacs.iibi.uiowa.edu/xnat"

SUB=11075
DEST="/data/backed_up/shared/ME_7T_Pilot/Raw/${SUB}"

# USE this to select which scan folder to download, check on xnat and can skip the not important ones (localizers)
#SCANS=( 2 4 5 6 7 8 9 10 11 12 13 14 1000 1100 1200 1300 1400)

SCANS=(1000 1100 1200 1300 1400)
for SCAN in "${SCANS[@]}"
do
    SCANDIR="${DEST}/scans/${SCAN}/"
    mkdir -p "${SCANDIR}"

    ZIPFILE="${SCANDIR}/DICOM.zip"

    echo "Downloading scan ${SCAN}"

    wget \
        --netrc \
        -c \
        -O "${ZIPFILE}" \
        "${BASE}/data/experiments/${EXP}/scans/${SCAN}/resources/DICOM/files?format=zip"

    unzip -q "${ZIPFILE}" -d "${SCANDIR}"

done

    # Uncomment if you don't want to keep the zip
    # rm "${ZIPFILE}"



# OLD WAY
# EXP=RPACS_E107776
# BASE=https://rpacs.iibi.uiowa.edu/xnat
# OUTDIR=${EXP}

# mkdir -p ${OUTDIR}

# for SCAN in 600 700 800 900
# do

#     echo "=========================="
#     echo "Downloading scan ${SCAN}"
#     echo "=========================="

#     SCAN_DIR=${OUTDIR}/scan_${SCAN}
#     mkdir -p ${SCAN_DIR}

#     curl --netrc -s \
#     "${BASE}/data/experiments/${EXP}/scans/${SCAN}/resources/DICOM/files?format=json" \
#     | jq -r '.ResultSet.Result[].URI' \
#     | while read FILEURI
#     do

#         FNAME=$(basename "${FILEURI}")

#         echo "Downloading ${FNAME}"

#         wget --netrc -q \
#         -c \
#         -O "${SCAN_DIR}/${FNAME}" \
#         "${BASE}${FILEURI}"

#     done

# done
