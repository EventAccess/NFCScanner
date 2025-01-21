#!/bin/bash
set -ex

PR_SHA_SHORT=$(git rev-parse --short --verify HEAD)

# Get git tag, and massage into something semver-ish
# v1.0.0 if tag exactly, potentially v1.0.0+{n-commits-since-tag}.{commit-hash}.{dirty}
GIT_DESCRIPTION="$(git describe --tags --always --match 'v*' --dirty)"
GIT_DESCRIPTION="${GIT_DESCRIPTION/-/+}"
GIT_DESCRIPTION="${GIT_DESCRIPTION//-/.}"

DATETIME=$(date --utc '+%Y-%m-%d %H:%M:%S %Z')
VERSION="${GIT_DESCRIPTION}"

# Date and version are used in PCB silkscreen, make sure to pass those in
KICAD_DEFINES=(
    -D "REVISION=${VERSION}"
    -D "DATE=${DATETIME}"
)

PROJECT="NfcCarrierBoard"

PCB_FILE="${PROJECT}.kicad_pcb"
GERBER_STAGING="./gerber/"
OUTPUT="./output/"

# Massage date-time into something more suitable for file names
DATETIME_FN="${DATETIME// UTC/Z}"
DATETIME_FN="${DATETIME_FN//:/}"
DATETIME_FN="${DATETIME_FN/ /T}"
DATETIME_FN="${DATETIME_FN// /-}"

rm -rv "${GERBER_STAGING}" "${OUTPUT}"
mkdir -p "${GERBER_STAGING}" "${OUTPUT}"

# Generate files for DirtyPCBs
kicad-cli pcb export gerbers --output="${GERBER_STAGING}" --layers=F.Cu,B.Cu,F.SilkS,B.SilkS,F.Mask,B.Mask,Edge.Cuts "${KICAD_DEFINES[@]}" "${PCB_FILE}"
kicad-cli pcb export drill --format=excellon --output="${GERBER_STAGING}" "${PCB_FILE}"
# Website specifies txt, then mentions dri further down - rename to txt
mv "${GERBER_STAGING}"/${PROJECT}{.drl,-excellon-drl.txt}
mv "${GERBER_STAGING}"/${PROJECT}-Edge_Cuts.gm{1,l}
sed -i -e 's/-Edge_Cuts.gm1/-Edge_Cuts.gml/g' "${GERBER_STAGING}"/${PROJECT}-job.gbrjob


# Include list of new/changed files when dirty
if [[ "${VERSION}" == *"dirty" ]]; then
    git status --porcelain --untracked=all --ignored=no --find-renames > "${GERBER_STAGING}"/git-status.info
fi

# Bundle into zip file for DirtyPCBs
zip -r9 "${OUTPUT}/${PROJECT}_${DATETIME_FN}_${VERSION}_DirtyPCBs.zip" "${GERBER_STAGING}"

# Output KiCad linting errors
kicad-cli sch erc --output="${OUTPUT}/schematic-erc.json" "${KICAD_DEFINES[@]}" "${PROJECT}.kicad_sch" --severity-error --severity-warning --format=json
kicad-cli pcb drc --output="${OUTPUT}/pcb-drc.json" "${KICAD_DEFINES[@]}" "${PCB_FILE}" --severity-error --severity-warning --format=json
# jq 'del(.sheets[].violations[]|select(.excluded==true))' "${OUTPUT}/schematic-erc.json"

# Render schematic
kicad-cli sch export svg --output="${OUTPUT}" "${KICAD_DEFINES[@]}" "${PROJECT}.kicad_sch"
kicad-cli sch export pdf --output="${OUTPUT}" "${KICAD_DEFINES[@]}" "${PROJECT}.kicad_sch"

# Output BOM
# TODO: Populate relevant schematic part fields
kicad-cli sch export bom --output="${OUTPUT}"/${PROJECT}-BOM.csv ${PROJECT}.kicad_sch --fields 'MPN,DigiKey,${QUANTITY},Reference,Value' --labels='MPN,DigiKey,Qty,Refs,Value' --exclude-dnp
