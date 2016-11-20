# PhotoRename

Python script to:

1. Read images or videos from input file or folder

2. For each file in folder (input folder) or input file, get its EXIF tags: Creation date, GPS latitude, GPS Longitude

3. Make time lable by Creation date with syntax: `%Y%m%d_%H%M%S`

4. Get position lable by GPS lat, lon from Open Steet Map service.

5. Rename the file to new filename with syntax: `<time lable>_<position lable>.<file extension>`

E.g: `20160603_114724-Vung_Tau_Intourco_Resort-Tỉnh_Bà_Rịa_–_Vũng_Tàu-Việt_Nam.jpg`

# Purpose

When we arrange pictures or videos in the order of filename, they are arranged from the past to present or vice versa without reading file header.

The postion lable helps us to remember where the picture or video was captured or recorded.

# TODO

1. Add setup.py for auto-setup

2. Improve option parser
