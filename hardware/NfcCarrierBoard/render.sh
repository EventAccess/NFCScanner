#!/bin/bash
set -ex

echo -n "Using KiCad version "
kicad-cli version

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

# Generate drill and gerbers
kicad-cli pcb export gerbers --output="${GERBER_STAGING}" --layers=F.Cu,B.Cu,F.SilkS,B.SilkS,F.Mask,B.Mask,Edge.Cuts "${KICAD_DEFINES[@]}" "${PCB_FILE}"
kicad-cli pcb export drill --format=excellon --output="${GERBER_STAGING}" "${PCB_FILE}"
# DirtyPCBs website specifies txt, then mentions dri further down - rename to txt
mv "${GERBER_STAGING}"/${PROJECT}{.drl,-excellon-drl.txt}
mv "${GERBER_STAGING}"/${PROJECT}-Edge_Cuts.gm{1,l}
sed -i -e 's/-Edge_Cuts.gm1/-Edge_Cuts.gml/g' "${GERBER_STAGING}"/${PROJECT}-job.gbrjob


# Include list of new/changed files when dirty
if [[ "${VERSION}" == *"dirty" ]]; then
    git status --porcelain --untracked=all --ignored=no --find-renames > "${GERBER_STAGING}"/git-status.info
fi

# Bundle into zip file
zip -r9 "${OUTPUT}/${PROJECT}_${DATETIME_FN}_${VERSION}.zip" "${GERBER_STAGING}"

# Output KiCad linting errors
kicad-cli sch erc --output="${OUTPUT}/schematic-erc.json" "${KICAD_DEFINES[@]}" "${PROJECT}.kicad_sch" --severity-error --severity-warning --format=json
kicad-cli pcb drc --output="${OUTPUT}/pcb-drc.json" "${KICAD_DEFINES[@]}" "${PCB_FILE}" --severity-error --severity-warning --format=json
# jq 'del(.sheets[].violations[]|select(.excluded==true))' "${OUTPUT}/schematic-erc.json"

# Render schematic
kicad-cli sch export svg --output="${OUTPUT}" "${KICAD_DEFINES[@]}" "${PROJECT}.kicad_sch"
kicad-cli sch export pdf --output="${OUTPUT}/${PROJECT}.pdf" "${KICAD_DEFINES[@]}" "${PROJECT}.kicad_sch"

# Output BOM
# TODO: Populate relevant schematic part fields
kicad-cli sch export bom --output="${OUTPUT}"/${PROJECT}-BOM.csv ${PROJECT}.kicad_sch --fields 'MPN,DigiKey,${QUANTITY},MFN,Reference,Value,Description,Footprint' --labels='MPN,DigiKey,Qty,MFN,Refs,Value,Description,Footprint' --exclude-dnp --group-by='DigiKey,MPN,MFN'

# Render STEP 3D model of board
kicad-cli pcb export step --drill-origin --subst-models --output output/${PROJECT}.step ${PROJECT}.kicad_pcb

# 3D Renders (color png) requires KiCAD v9
function kicad-render {
    docker run -it --rm -v "$(pwd):/workdir" -w /workdir kicad/kicad:nightly-full \
        kicad-cli pcb render "$@"
}

kicad-render --output="${OUTPUT}"/${PROJECT}-render-top-3d.png "${KICAD_DEFINES[@]}" ${PROJECT}.kicad_pcb \
  --quality=high --side=top --perspective --zoom=0.8 --pan=0,-0.6,0 --width=800 --height=1000 --light-camera=0.3

kicad-render --output="${OUTPUT}"/${PROJECT}-render-45.png "${KICAD_DEFINES[@]}" ${PROJECT}.kicad_pcb \
  --quality=high --rotate='320,0,135' --perspective --zoom=0.75 --pan=0,2,0 --width=1200 --height=1000 --light-camera=0.3

kicad-render --output="${OUTPUT}"/${PROJECT}-render-back.png "${KICAD_DEFINES[@]}" ${PROJECT}.kicad_pcb --quality=high --side=back --zoom=2 --pan=0,-1.5,0 --width=2200 --height=1000 --light-camera=0.8
kicad-render --output="${OUTPUT}"/${PROJECT}-render-left.png "${KICAD_DEFINES[@]}" ${PROJECT}.kicad_pcb --quality=high --side=left --zoom=2 --pan=0,-1.5,0 --width=2200 --height=1000 --light-camera=0.8
kicad-render --output="${OUTPUT}"/${PROJECT}-render-right.png "${KICAD_DEFINES[@]}" ${PROJECT}.kicad_pcb --quality=high --side=right --zoom=2 --pan=0,-1.5,0 --width=2200 --height=1000 --light-camera=0.8
kicad-render --output="${OUTPUT}"/${PROJECT}-render-front.png "${KICAD_DEFINES[@]}" ${PROJECT}.kicad_pcb --quality=high --side=front --zoom=2 --pan=0,-1.5,0 --width=2200 --height=1000 --light-camera=0.8
kicad-render --output="${OUTPUT}"/${PROJECT}-render-top.png "${KICAD_DEFINES[@]}" ${PROJECT}.kicad_pcb  --quality=user --side=top --zoom=0.8 --pan=0,-0.3,0 --width=800 --height=1000 --light-top=0.7 --light-camera=0.2
kicad-render --output="${OUTPUT}"/${PROJECT}-render-bottom.png "${KICAD_DEFINES[@]}" ${PROJECT}.kicad_pcb --quality=user --side=bottom --zoom=0.8 --pan=0,-0.3,0 --width=800 --height=1000 --light-bottom=0.7 --light-camera=0.2
