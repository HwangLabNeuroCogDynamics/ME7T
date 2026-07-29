# #!/bin/bash

set -e
EXP="RPACS_E111394"
BASE="https://rpacs.iibi.uiowa.edu/xnat"

SUB=11074
DEST="/data/backed_up/shared/ME_7T_Pilot/Raw/${SUB}"
# where to save tmp zip files
TMPROOT="/data/backed_up/shared/ME_7T_Pilot/tmp"
mkdir -p "${TMPROOT}"

# you can go onto XNAT to see what runs you want to download, to skip things we dont need (localizer, etc)
SCANS=(2 19 20 800 900 1000 1100 1200 1300 1400 1500 1600 1700 1800 2100)


for SCAN in "${SCANS[@]}"; do
    echo "Downloading scan ${SCAN}"

    RUNDIR="${DEST}/run-${SCAN}"
    mkdir -p "${RUNDIR}"

    TMPDIR="$(mktemp -d "${TMPROOT}/xnat_${SUB}_${SCAN}_XXXXXX")"
    ZIPFILE="${TMPDIR}/DICOM.zip"

    wget \
        --netrc \
        -c \
        -O "${ZIPFILE}" \
        "${BASE}/data/experiments/${EXP}/scans/${SCAN}/resources/DICOM/files?format=zip"

    # Look at the ZIP contents and find one file under the DICOM files directory
    ENTRY="$(unzip -Z1 "${ZIPFILE}" | grep '/resources/DICOM/files/' | head -n 1 || true)"

    if [[ -z "${ENTRY}" ]]; then
        echo "ERROR: Could not find DICOM files path in scan ${SCAN}"
        rm -rf "${TMPDIR}"
        exit 1
    fi

    # ENTRY example:
    # scans/19/resources/DICOM/files/IM-0001-0001.dcm
    # SERIESDIR becomes:
    # scans/19
    SERIESDIR="${ENTRY%/resources/DICOM/files/*}"
    SERIESNAME="${SERIESDIR##*/}"

    unzip -q "${ZIPFILE}" -d "${TMPDIR}"

    if [[ ! -d "${TMPDIR}/${SERIESDIR}/resources/DICOM/files" ]]; then
        echo "ERROR: Missing DICOM files directory for scan ${SCAN}"
        echo "Expected: ${TMPDIR}/${SERIESDIR}/resources/DICOM/files"
        rm -rf "${TMPDIR}"
        exit 1
    fi

    mv "${TMPDIR}/${SERIESDIR}/resources/DICOM/files" "${RUNDIR}/${SERIESNAME}"

    rm -rf "${TMPDIR}"
done




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
