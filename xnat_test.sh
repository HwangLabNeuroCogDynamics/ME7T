#!/bin/bash
# an alternate way of downloading dicoms instead of zip files.

EXP=RPACS_E107776
BASE=https://rpacs.iibi.uiowa.edu/xnat
OUTDIR=${EXP}

mkdir -p ${OUTDIR}

for SCAN in 600 700 800 900
do

    echo "=========================="
    echo "Downloading scan ${SCAN}"
    echo "=========================="

    SCAN_DIR=${OUTDIR}/scan_${SCAN}
    mkdir -p ${SCAN_DIR}

    curl --netrc -s \
    "${BASE}/data/experiments/${EXP}/scans/${SCAN}/resources/DICOM/files?format=json" \
    | jq -r '.ResultSet.Result[].URI' \
    | while read FILEURI
    do

        FNAME=$(basename "${FILEURI}")

        echo "Downloading ${FNAME}"

        wget --netrc -q \
        -c \
        -O "${SCAN_DIR}/${FNAME}" \
        "${BASE}${FILEURI}"

    done

done



#!/bin/bash

# ============================================================
# Download one ZIP per scan from RPACS/XNAT
# ============================================================

USER="kahwang"
EXP="RPACS_E107776"
BASE="https://rpacs.iibi.uiowa.edu/xnat"

OUTDIR="${EXP}_zips"

mkdir -p "${OUTDIR}"

for SCAN in 600 700 800 900
do

    ZIPFILE="${OUTDIR}/scan_${SCAN}.zip"

    echo "======================================="
    echo "Downloading scan ${SCAN}"
    echo "Output: ${ZIPFILE}"
    echo "======================================="

    wget \
        --netrc \
        -c \
        -O "${ZIPFILE}" \
        "${BASE}/data/experiments/${EXP}/scans/${SCAN}/resources/DICOM/files?format=zip"

done