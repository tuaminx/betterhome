#!/usr/local/bin/python
# -*- encoding: utf-8 -*-

import json
import signal
import subprocess
import sys
import time

from datetime import datetime
from dateutil import tz
from geopy.geocoders import Nominatim
from geopy.exc import GeopyError
from optparse import OptionParser
from os import listdir, rename
from os.path import isfile, isdir, join, dirname, basename, splitext

IS_DEBUG = False
NEW_ADDRESS_ITEM = []
dt_format = "%Y%m%d_%H%M%S"

def get_formated_filename(input_path, src_filename):
    debug("File: %s" %src_filename)
    file_path = join(input_path, src_filename)
    proc = subprocess.Popen(["exiftool",
                             "-json",
                             "-c", "%.10f",
                             "-d", dt_format,
                             "-CreateDate",
                             "-MIMEType",
                             "-CreationDate",
                             "-FileModifyDate",
                             "-GPSLatitude",
                             "-GPSLongitude",
                             file_path],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = proc.communicate()

    extracted = json.loads(out)[0]
    parsed = json.loads(json.dumps(extracted))
    debug("JSON: %s" % parsed)

    if 'CreateDate' in parsed and 'MIMEType' in parsed:
        cdate = parsed['CreateDate']
        media_type = parsed['MIMEType']
        debug("EXIF:MIMEType: %s" % media_type)
        debug("EXIF:CreateDate: %s" % cdate)
        if media_type.startswith(u'video/') and 'CreationDate' in parsed:
            debug("EXIF:CreationDate: %s" % parsed['CreationDate'])
            cdate = parsed['CreationDate']
        else:
            cdate = None
    else:
        cdate = None

    lat = 0
    lon = 0

    if 'GPSLatitude' in parsed:
        lat = parsed['GPSLatitude']
        debug("EXIF:GPSLatitude: %s" % lat)
        if not isinstance(lat, float) and 'N' in lat:
            lat = lat[:-2]

    if 'GPSLongitude' in parsed:
        lon = parsed['GPSLongitude']
        debug("EXIF:GPSLongitude: %s" % lon)
        if not isinstance(lat, float) and 'E' in lon:
            lon = lon[:-2]

    location_str = ""

    if 0 < float(lat) or 0 < float(lon):
        location_str = get_position_from_gps(lat, lon)

    if location_str is None or cdate is None:
        return "_skip_%s" % src_filename

    res_name = "%s%s.%s" % (cdate, location_str, file_path[-3:])
    debug("Destination name: %s" %res_name)
    return res_name


def debug(message):
    if IS_DEBUG:
        print "[DEBUG] %s" % message


def log(message):
    print "[  LOG] %s" % message


def info(message):
    print "[ INFO] %s" % message


def get_position_from_gps(latitude, longitude):
    position = ""
    country = ""
    city = ""
    ward = ""
    state = ""

    position_field = ['hospital', 'supermarket', 'bank', 'restaurant',
                      'hotel', 'building', 'house', 'address29', 'theme_park',
                      'bus_stop', 'mall', 'attraction', 'place_of_worship',
                      'zoo', 'park', 'aerodrome', 'beach', 'stadium',
                      'playground', 'community_centre', 'kindergarten',
                      'school', 'cafe', 'pedestrian', 'bus_station']
    ward_field = ['town', 'suburb', 'district', 'subdistrict', 'hamlet',
                  'village']
    state_field = ['city', 'state', 'province']
    ignore_field = ['country', 'country_code', 'road', 'postcode',
                    'neighbourhood', 'house_number', 'mobile_phone']

    if latitude and longitude:
        debug("Getting pos from GPS: %s : %s" % (latitude, longitude))
        geo_locator = Nominatim()

        try:
            location = geo_locator.reverse("%s, %s" % (latitude, longitude),
                                          timeout=60)
        except GeopyError as e:
            info("Error, skip: %s" % e.message)
            return None

        address_raw = location.raw.get('address', None)
        if address_raw is None:
            debug("address_raw is None")
            return ""

        address_json = json.loads(json.dumps(address_raw))
        if address_json is None:
            debug("address_json is None")
            return ""

        for item in address_json.keys():
            if item not in position_field + ward_field + state_field + \
                    ignore_field:
                NEW_ADDRESS_ITEM.append("%s : %s" % (item,
                                                     address_json[item]))

        debug("Raw address from OpenStreetMap: %s" % address_raw)
        for fpos in position_field:
            if fpos in address_json:
                position = address_json[fpos]
                debug("Found fpos: %s" % position)

        for fward in ward_field:
            if fward in address_json:
                ward = address_json[fward]
                debug("Found fward: %s" % ward)
                # For author's purpose. I don't know why OSM has this mistake
                if ward == u'Phường 8':
                    ward = u'Quận 8'
                    debug("New fward: %s" % ward)

        for fstate in state_field:
            if fstate in address_json:
                state = address_json[fstate]
                debug("Found fstate: %s" % state)

        if 'country' in address_json:
            country = address_json['country']
            debug("Found country: %s" % country)

        if position:
            debug("Have fpos (%s) so fward (%s) unusable" % (position, ward))
            ward = ""

        if city:
            city = "-%s" % city
        if country:
            country = "-%s" % country
        if ward:
            ward = "-%s" % ward
        if state:
            state = "-%s" % state
        if position:
            position = "-%s" % position

    position = position.replace(' ', '_')
    ward = ward.replace(' ', '_')
    city = city.replace(' ', '_')
    country = country.replace(' ', '_')
    state = state.replace(' ', '_')

    return "%s%s%s%s%s" %(position, ward, city, state, country)


def process_file(in_path, in_name, de_name, dry_run):
    if in_name.decode('unicode_escape') == de_name:
        info("File's names are identical. Skip%s" % (' ' * 20))
        return
    n = 1
    name = splitext(de_name)[0]
    ext = de_name[-3:]
    while isfile(join(in_path, de_name)):
        de_name = "%s_%s.%s" % (name, n, ext)
        n += 1
    if dry_run:
        info("In folder %s" % in_path)
        info("   Old: %s" % in_name)
        info("   New: %s" % de_name)
    else:
        try:
            rename(join(in_path, in_name),
                   join(in_path, de_name))
        except OSError as e:
            info("File %s cannot be renamed: %s" % (in_name, e.message))


def signal_handler(signal, frame):
        info('Ctrl+C was pressed. I stop!')
        sys.exit(0)


if __name__ == "__main__":
    # For system input signal
    signal.signal(signal.SIGINT, signal_handler)

    # For option parser
    usage = "usage: %prog [options]"
    opt_parser = OptionParser(usage=usage)
    opt_parser.add_option("-i", "--input",
                          action="store", type="string", dest="input_path",
                          help="input path, can be a file or a folder")
    opt_parser.add_option("--dryrun", default=False,
                          action="store_true", dest="is_dryrun",
                          help="run with outputed new name, not actually "
                               "renamed")
    opt_parser.add_option("--retry", default=False,
                          action="store_true", dest="is_retry",
                          help="re-execution with previous failed files")
    opt_parser.add_option("--debug", default=False,
                          action="store_true", dest="is_debug",
                          help="show debug logs")
    opt_parser.add_option("--remove", default=False,
                          action="store_true", dest="is_remove",
                          help="remove '_retry_'")

    (options, args) = opt_parser.parse_args(sys.argv)

    input_path = options.input_path
    is_dryrun = options.is_dryrun
    is_retry = options.is_retry
    is_remove = options.is_remove
    IS_DEBUG = options.is_debug

    if isdir(input_path):
        debug("Processing for a directory")
        if not is_retry:
            files = [f for f in listdir(input_path)
                     if isfile(join(input_path, f)) and
                     not f.startswith('.') and
                     not f.startswith('_skip_')]
        else:
            files = [f for f in listdir(input_path)
                     if isfile(join(input_path, f)) and
                     not f.startswith('.') and
                     f.startswith('_skip_')]
        count = 0
        total = len(files)
        start_time = time.time()
        for src_filename in files:
            if is_retry and not src_filename.startswith('_skip_'):
                    continue

            if is_retry and is_remove:
                dest_filename = src_filename[6:]
            else:
                dest_filename = get_formated_filename(input_path, src_filename)
            process_file(input_path, src_filename, dest_filename, is_dryrun)

            count += 1
            check_duration = time.time() - start_time
            est_fin = (check_duration / count) * (total - count)
            if 0 == int(round(est_fin/60)):
                est_string = "%s sec" % int(round(est_fin))
            else:
                est_string = "%s min" % int(round(est_fin/60))
            if not IS_DEBUG:
                sys.stdout.write("Rename processing: %d/%d. "
                                 "Estimated to finish in %s%s\r" %
                                 (count, total, est_string, ' ' * 5))
                sys.stdout.flush()
            else:
                debug("Rename processing: %d/%d. Estimated to finish in %s"
                      % (count, total, est_string))
        total_time = int(round((time.time() - start_time)/60))
        info("Done for %s files in %s min%s" % (total, total_time, ' ' * 30))
        if len(NEW_ADDRESS_ITEM) > 0:
            info("Found new address items:")
            for i in NEW_ADDRESS_ITEM:
                info(" %s" % i)

    if isfile(input_path):
        path = dirname(input_path)
        src_filename = basename(input_path)
        to_process = True
        if is_retry and not src_filename.startswith('_skip_'):
            to_process = False
        if to_process:
            dest_filename = get_formated_filename(path, src_filename)
            process_file(path, src_filename, dest_filename, is_dryrun)
