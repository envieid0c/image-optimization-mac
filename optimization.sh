#!/bin/bash

# acquire sudo at the beginning
###sudo -v
# Keep-alive: update existing `sudo` time stamp until `.osx` has finished

ROOT_PATH=$(cd $(dirname $0) && pwd);
cd $ROOT_PATH;

while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

SOURCE="${BASH_SOURCE[0]}"

# resolve $SOURCE until the file is no longer a symlink

while [ -h "$SOURCE" ];
do 

  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

  SOURCE="$(readlink "$SOURCE")"

   # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located

  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
  
done

SELF_PATH="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

TMPDIR=/tmp/optimizer
RESOURCESDIR="$SELF_PATH/Resources"
jpegoptim="$RESOURCESDIR/jpegoptim"
optipng="$RESOURCESDIR/optipng"
pngquant="$RESOURCESDIR/pngquant"
jpegrecompress="$RESOURCESDIR/jpeg-recompress"
cjpeg="$RESOURCESDIR/cjpeg"

EXIFTOOL="$SELF_PATH/Resources/Image-ExifTool-11.15/exiftool"
RECOMPRESS="$SELF_PATH/Resources/recompress"

rebuildIcon=0

if [ "$1" == "" ]; then
    echo "No theme path supplied. Exiting"
    exit 1
elif [ ! -d "$1" ]; then
    echo "Error. Theme path does not exist. Exiting"
    exit 1
fi

echo "Optimising $1"

if [ "$2" == "-r" ]; then
  rebuildIcon=1
  echo "Will rebuild ICNS files"
  
fi

sizeBefore=$( du -sh "$1" | awk '{print $1}')

oIFS="$IFS"; IFS=$'\n'

#############################
# Find and convert all .png files to a palleted (8-bit) transparent PNG.
#############################
# pngquant uses lossy compression techniques to reduce the size of a PNG image.
# It converts a 32-bit PNG image to a 8-bit paletted image. More specifically,
# instead of storing each pixel as a 4-channel, 32-bit RGBA value, each pixel is stored as an 8-bit
# reference for mapping to a color in a palette. This 8-bit color palette is embedded in the image,
# and is capable of defining 256 unique colors.
# The trick then becomes how to reduce the total number of colors
# in an image without sacrificing too much perceivable quality.
#############################

pngOptimize=( $( find "$1" -type f -name "*.png" 2>/dev/null ) )

for (( p=0; p<${#pngOptimize[@]}; p++ ))
    do
    echo "Reducing ${pngOptimize[$p]}"
    "$pngquant" --ext .png --quality=65-80 --skip-if-larger -- "${pngOptimize[$p]}"
done

#############################
# Find and compiress  all .png
#############################
# optipng optimizes a PNG file by compressing it losslessly
# By default, optipng compresses the PNG file in-place, hence overwriting the original file.
# To write the output to a different file, use the -out option to specify a new output file.
# If the specified output file already exists, the -clobber option allows it to be overwritten.
# The -clobber is useful if you are running the command more than once.
# Meta data.
# The -o option specifies the optimization level, which ranges from 0 to 7.
# Level 7 offers the highest compression, but also takes the longest time to complete.
# It has been reported that there is a marginal return of improved compression as you increase the optimization level.
# The results obtained from my own 1-image test confirm that. The tests show that the default optimization 
# level of 2 is pretty good, and that higher levels do not offer a big increase in compression.
pngCompress=( $( find "$1" -type f -name "*.png" 2>/dev/null ) )

for (( p=0; p<${#pngCompress[@]}; p++ ))
    do
    echo "Compress ${pngCompress[$p]}"
    "$optipng" -nc -nb -o7 -full -strip all -- "${pngCompress[$p]}"
done

#############################
# Jpegoptim - utility to optimize jpeg files
#############################
# Provides lossless optimization (based on optimizing the Huffman tables)
# and "lossy" optimization based on setting maximum quality factor.
#find . -type f -name "*.jpg" -exec "$jpegoptim" -P -f {} \;
jpegOptim=( $( find "$1" -type f -name "*.jpg" 2>/dev/null ) )
    for (( p=0; p<${#jpegOptim[@]}; p++ ))
        do
        echo "Compress ${jpegOptim[$p]}"
        "$jpegoptim" -P -f --strip-all -- "${jpegOptim[$p]}"
    done
    echo "Finish jpegOptim!"

#############################
# Mozilla JPEG Encoder Project
# Optimizing your images can feel like black magic sometimes.
# The safest JPG compression is lossless meaning no quality loss (guide), lossy compression has far superior space savings.
# This guide will show you how to batch optimize JPG images using lossy compression with jpeg-recompress from jpeg-archive on Linux.
#############################

find "$1" -type f -iname '*.jpg' -exec $jpegrecompress --quality medium --min 60 --method smallfry \{} \{} \;
find "$1" -type f -iname '*.jpeg' -exec $jpegrecompress --quality medium --min 60 --method smallfry \{} \{} \;

#############################
#cjpeg
# NOTE:  This file was modified by The libjpeg-turbo Project to include only
# information relevant to libjpeg-turbo and to wordsmith certain sections.
#############################

find "$1" -type f -iname '*.jpg' -exec $cjpeg -quality 90 \{} \{} \;
find "$1" -type f -iname '*.jpeg' -exec $cjpeg -quality 90 \{} \{} \;

#############################
# ExifTool - Read, Write and Edit Meta Information!
#############################
# ExifTool by Phil Harvey
# ExifTool is a platform-independent Perl library plus a command-line application for reading,
# writing and editing meta information in a wide variety of files.

#exifTool=( $( find "$1" -type f | egrep -i "*.jpg|*.jpeg" 2>/dev/null ) )
#    for (( p=0; p<${#exifTool[@]}; p++ ))
#        do
#        echo "Compress ${exiftool[$p]}"
#        "$exiftool" -overwrite_original all -- "${exiftool[$p]}"
#    done

find "$1" -type f -iname "*.jpeg" -exec $EXIFTOOL -overwrite_original -all= \{} \;
find "$1" -type f -iname "*.jpg" -exec $EXIFTOOL -overwrite_original -all= \{} \;

#############################
# PEG Archive - Read, Write and Edit Meta Information!
#############################
#Utilities for archiving photos for saving to long term storage or serving over the web. The goals are:
# Use a common, well supported format (JPEG)
# Minimize storage space and cost
# Identify duplicates / similar photos
# Approach:
# Command line utilities and scripts
# Simple options and useful help
# Good quality output via sane defaults
# Compress JPEGs by re-encoding to the smallest JPEG quality while keeping
# perceived visual quality the same and by making sure huffman tables are optimized.

#recompress=( $( find "$1" -type f -name "*.jpg" 2>/dev/null ) )
#    for (( p=0; p<${#recompress[@]}; p++ ))
#        do
#        echo "Compress ${recompress[$p]}"
#       "$recompress" {} {} \;
#   done

#find "$1" -type f -name '*.jpg' -exec $RECOMPRESS {} {} \;

# Find and convert all .icns files to a palleted (8-bit) transparent PNG.
mkdir "$TMPDIR"

icnsFiles=$( find "$1" -type f -name "*.icns" 2>/dev/null )

for icn in $icnsFiles
do

    # Get size of original file
    originalSize=$(stat -f%z "$icn")

    tmpIconName="${icn##*/}"
    tmpIconName="${tmpIconName%.icns*}"

    # Copy the .icns file to temp location to do the shrinking
    cp "$icn" "$TMPDIR"

    # Convert .icns to .iconset and remove original if successful
    success=0
    iconutil -c iconset "${TMPDIR}"/"${tmpIconName}".icns && success=1

    # Delete all from folder except icon_32x32.png and icon_128x128.png
    if [ $success -eq 1 ]; then

        cd "${TMPDIR}"/"${tmpIconName}".iconset
        shopt -s extglob
        
        `rm !(icon_32x32.png|icon_64x64.png|icon_128x128.png|icon_256x256.png)`
        # As we're not rebuilding .icns then just retain the 128 pixel image.

        #`rm !(icon_128x128.png)`

        # Shrink the .png files to a palleted (8-bit) transparent PNG.

        "$pngquant" --force --ext .png -- "${TMPDIR}"/"${tmpIconName}".iconset/*

        # --------------------------------------------------------------------
        # This next part is not useful for Clover as although it can load and use
        # the .PNG file, Clover does not know about the .PNG icon type (ic07)
        # inside the .ICNS file that iconutil generates. So as far as Clover
        # is concerned, these .ICNS files don't contain a .PNG file.

        if [ $rebuildIcon -eq 1 ]; then

            # Recreate .icns file
            iconutil -c icns "${TMPDIR}"/"${tmpIconName}".iconset 2>/dev/null

            # Remove the temp .iconset
            rm -rf "${TMPDIR}"/"${tmpIconName}".iconset

            # Get size of new file
            newSize=$(stat -f%z "${TMPDIR}"/"${tmpIconName}".icns)

            if [ $newSize -lt $originalSize ]; then

                # remove the original .icns file
                rm "$icn"

                # Copy new icon to original location
                cp "${TMPDIR}"/"${tmpIconName}".icns "$icn"
                
                # Print result
                echo "${icn##*/} | Reduced from $originalSize to $newSize"

            else

                echo "${icn##*/} | Keeping original as it's smaller."

            fi

            # remove the temp .icns file
            rm "${TMPDIR}"/"${tmpIconName}".icns
                
            # --------------------------------------------------------------------
            
        else
        
            # As the above part is not used, here we just copy the .PNG file
            # back with the extension .icns (to satisfy Clover) before removing
            # the tmp file. 

            cp "${TMPDIR}"/"${tmpIconName}".iconset/*.png "$icn"
            rm -rf "${TMPDIR}"/"${tmpIconName}".iconset
            
        fi

    else

        # Original .ICNS file was not converted to an iconset.
        # More than likely, this is alreasy a .PNG with .ICNS extension.
        # Copy file bak and then remove it

        cp "${TMPDIR}"/"${tmpIconName}".icns  "$icn"
        rm "${TMPDIR}"/"${tmpIconName}".icns

    fi
done

rm -rf "$TMPDIR"

IFS="$oIFS"

#echo "Complete"

#sizeAfter=$( du -sh "$1" | awk '{print $1}')

#echo "----------------------------"
#echo "Size before shrinking: $sizeBefore"
#echo "Size after shrinking:  $sizeAfter"
#echo "----------------------------"
