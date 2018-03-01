#!/usr/bin/env bash

FFMPEG=/home/hider/bin/ffmpeg
FFPROBE=/home/hider/bin/ffprobe
JHEAD=/usr/bin/jhead

IMG_NAME_PATTERN="img_%y%m%d_%H%M%S"
VIDEOEXT="mkv"
FFMPEG_PARAMS="-c:v libx264 -crf 26 -profile:v high -level 4.2"

DELIMITER="=========="

MODIFICATOR=$1

function renamePhoto() {
    local ISTEST=$1

    for file in "${@:2}"; do
        if [ ${ISTEST} -eq 1 ]
        then
            echo "${JHEAD} -n${IMG_NAME_PATTERN} -autorot ${file}"
        else
            ${JHEAD} -n${IMG_NAME_PATTERN} -autorot "${file}"
        fi
    done
}

function showVideoInfo() {
    for file in "${@:1}"; do
        echo "${DELIMITER} ${file} ${DELIMITER}"
        ${FFPROBE} "${file}"
    done
}

function getVideoDate() {
    local INFO=`${FFPROBE} "$1" 2>&1`
    local DATETIME=`echo "${INFO}" \
                    | grep -iE -m 1 "(creation_time|creationdate)"`
    if [ ${#DATETIME} -eq 0 ]
    then
        echo ""
    else
        echo "${DATETIME}" \
            | egrep -o -- "[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}(T[[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2})?" \
            | sed -e "s/-//g;s/://g;s/T/_/g"
    fi
}

function checkFileExists() {
    local DIR=$1
    local NAME=$2
    local EXT=$3
    local COUNTER=0

    local FULL_NAME="${DIR}/VID${NAME}.${EXT}"
    while [ -f "${FULL_NAME}" ]; do
        COUNTER=$((COUNTER+1))
        FULL_NAME="${DIR}/VID${NAME}-${COUNTER}.${EXT}"
    done
    echo "$FULL_NAME"
}

function renameVideo() {
    local ISTEST=$1

    for file in "${@:2}"; do
        local DATE=$(getVideoDate "${file}")
        local DIR=`dirname "${file}"`

        local FNAME=$(basename "$file")
        local EXT="${FNAME##*.}"

        local FULL_NAME=$(checkFileExists "$DIR" "$DATE" "$EXT")

        if [ ${ISTEST} -eq 1 ]
        then
            echo "mv ${file} ${FULL_NAME}"
        else
            mv "${file}" "${FULL_NAME}"
        fi
    done
}

function encodeVideo() {
    local ISTEST=$1

    for file in "${@:2}"; do

        local DATE=$(getVideoDate "${file}")
        local DIR=`dirname "${file}"`

        local FULL_NAME=$(checkFileExists "$DIR" "$DATE" "$VIDEOEXT")

        if [ ${ISTEST} -eq 1 ]
        then
            echo "${FFMPEG} -i ${file} ${FFMPEG_PARAMS} ${FULL_NAME}"
        else
            echo "${DELIMITER} ${file} -> ${FULL_NAME} ${DELIMITER}"
            ${FFMPEG} -i "${file}" ${FFMPEG_PARAMS} "${FULL_NAME}"
        fi
    done
}

function concatVideo() {
    local ISTEST=$1
    local FILES=("${@:2}")
    local FNAME=$(basename "${FILES[0]}")
    local DIR=$(dirname "${FILES[0]}")
    local FILENAME="${FNAME%.*}"
    local CONCAT="${DIR}/${FILENAME}-list.txt"
    local OUTPUT="${DIR}/${FILENAME}-full.${VIDEOEXT}"

    for file in "${FILES[@]}"; do
        if [ ${ISTEST} -eq 1 ]
        then
            echo "echo \"file '${file}'\" >> ${CONCAT}"
        else
            echo "file '$file'" >> ${CONCAT}
        fi
    done

    if [ ${ISTEST} -eq 1 ]
    then
        echo "ffmpeg -f concat -safe 0 -i ${CONCAT} -c copy ${OUTPUT}"
        echo "rm -f ${CONCAT}"
    else
        ffmpeg -f concat -safe 0 -i ${CONCAT} -c copy ${OUTPUT}
        rm -f ${CONCAT}
    fi

    local COUNTER=0
    for file in "${FILES[@]}"; do
        local FNAME=$(basename "${file}")
        local DIR=$(dirname "${file}")
        local FILENAME="${FNAME%.*}"
        local EXT="${FNAME##*.}"
        COUNTER=$((COUNTER+1))

        if [ ${ISTEST} -eq 1 ]
        then
            echo "mv "${file}" "${DIR}/${FILENAME}-concat-${COUNTER}.${EXT}""
        else
            mv "${file}" "${DIR}/${FILENAME}-concat-${COUNTER}.${EXT}"
        fi
    done
}

case ${MODIFICATOR} in
'photo-rename')
  renamePhoto 0 "${@:2}" ;;
'photo-rename-test')
  renamePhoto 1 "${@:2}" ;;
'video-encode')
  encodeVideo 0 "${@:2}" ;;
'video-encode-test')
  encodeVideo 1 "${@:2}" ;;
'video-info')
  showVideoInfo "${@:2}" ;;
'video-rename')
  renameVideo 0 "${@:2}" ;;
'video-rename-test')
  renameVideo 1 "${@:2}" ;;
'video-concat')
  concatVideo 0 "${@:2}" ;;
'video-concat-test')
  concatVideo 1 "${@:2}" ;;
esac
