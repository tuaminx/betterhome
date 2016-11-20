#!/usr/local/bin/python
# -*- encoding: utf-8 -*-

import json
import signal
import subprocess
import sys
import re
import datetime

from optparse import OptionParser
from os import listdir, mkdir, unlink
from shutil import copyfile, move
from os.path import isfile, isdir, join

from Common import Log
from Common.Exception import ExPhotoRename, ExEditFile


class PhotoRename(object):
    """The class for photo rename

    """
    def __init__(self, input, output, review_folder,
                 logfile="/var/log/betterhome/photorename.log",
                 level="info",
                 lockfile="/var/log/betterhome/photorename.lock"):
        self.log = Log.Log("PhotoRename", logfile, level)
        self.date_format = "%Y%m%d"
        self.time_format = "%H%M%S"
        self.input = input
        self.output = output
        self.review = review_folder
        self.birthday = "20130925"
        self.exiftool = "/opt/local/bin/exiftool"
        self.lock = lockfile

    def get_info_from_exif(self, file_path):
        try:
            my_env = os.environ.copy()
            
            process = subprocess.Popen([self.exiftool,
                                        "-json",
                                        "-c", "%.10f",
                                        "-d", "%s-%s" % (self.date_format,
                                                         self.time_format),
                                        "-CreateDate",
                                        "-MIMEType",
                                        "-CreationDate",
                                        "-FileModifyDate",
                                        "-GPSLatitude",
                                        "-GPSLongitude",
                                        file_path],
                                       stdout=subprocess.PIPE,
                                       stderr=subprocess.PIPE)
            out, err = process.communicate()
        except OSError as ex:
            raise ExPhotoRename("OSERROR: %s" % ex.message)
        except Exception as ex:
            raise ExPhotoRename("Generally failed: %s" % ex.message)

        extracted = json.loads(out)[0]
        parsed = json.loads(json.dumps(extracted))

        if 'CreateDate' in parsed and 'MIMEType' in parsed:
            creation_date = parsed['CreateDate']
            media_type = parsed['MIMEType']
            self.log.debug("EXIF:MIMEType: %s" % media_type)
            self.log.debug("EXIF:CreateDate: %s" % creation_date)
            if media_type.startswith(u'video/'):
                if 'CreationDate' in parsed:
                    self.log.debug("EXIF:CreationDate: %s" %
                                   parsed['CreationDate'])
                    creation_date = parsed['CreationDate']
                else:
                    creation_date = None
        else:
            creation_date = None

        lat = None
        lon = None

        if 'GPSLatitude' in parsed:
            lat = parsed['GPSLatitude']
            if not isinstance(lat, float) and 'N' in lat:
                lat = lat[:-2]
            if float(lat) <= 0:
                lat = None
            else:
                lat = str(lat).replace('.', '_')

        if 'GPSLongitude' in parsed:
            lon = parsed['GPSLongitude']
            if not isinstance(lon, float) and 'E' in lon:
                lon = lon[:-2]
            if float(lon) <= 0:
                lon = None
            else:
                lon = str(lon).replace('.', '_')

        if creation_date is not None:
            date_split = str(creation_date).split('-')

        return (date_split[0] if not creation_date is None else None,
                date_split[1] if not creation_date is None else None,
                lat,
                lon)

    def copy_file(self, from_path, to_subfolder, to_filename):
        """Do coying file. If target was existed then copying to review folder
        instead. In review folder, last number of filename is increased if file
        was existed.
        """
        target_folder = join(self.output, to_subfolder)
        target_file = join(target_folder, to_filename)
        if isdir(target_folder):
            # If target was existed, working with review folder
            if isfile(target_file):
                self.log.info("File was existed. Move to Review")
                if not isdir(join(self.review, to_subfolder)):
                    try:
                        self.log.debug("Create sub-folder")
                        mkdir(join(self.review, to_subfolder))
                    except Exception as e:
                        raise ExPhotoRename("Fail in create folder %s: %s" %
                                            (target_folder, e.message))
                else:
                    # Subfolder was existed in review dir, if file still existed
                    # we should not overwrite but increase number in filename
                    number = 0
                    to_fname_base = to_filename.split('.')[0]
                    to_fname_ext = to_filename.split('.')[1]
                    while True:
                        if not isfile(join(self.review,
                                           "%s/%s" % (to_subfolder,
                                                      to_filename))):
                            break
                        self.log.debug("%s was existed" % to_filename)
                        number += 1
                        to_filename = "%s-%s.%s" % (to_fname_base,
                                                    number,
                                                    to_fname_ext)
                target_file = join(self.review,
                                   "%s/%s" % (to_subfolder, to_filename))
        else:
            try:
                mkdir(target_folder)
            except Exception as e:
                raise ExPhotoRename("Fail in create folder %s: %s" %
                                    (target_folder, e.message))
                pass
        try:
            move(from_path, target_file)
            self.log.info("Success in move file")
        except Exception as e:
            raise ExPhotoRename("Fail in move file %s: %s" %
                                (target_file, e.message))

    def calcule_age(self, input_date):
        """Calculate age from self.birthday to date in EXIF tag"""

        born_date = datetime.datetime.strptime(self.birthday, self.date_format)
        diff_year = input_date.year - born_date.year
        is_before_birthday = (input_date.month, input_date.day) < (
            born_date.month, born_date.day)
        return diff_year - int(is_before_birthday)

    def subfolder_from_date(self, creation_date):
        """Get sub-folder name from the create date in EXIF tag"""

        cdatetime = datetime.datetime.strptime(creation_date, self.date_format)
        age = self.calcule_age(cdatetime)

        self.log.debug("Date: %s. Age calculated: %s" % (creation_date, age))
        if age <= 0:
            return "00_truoc_thoi_noi"
        elif age < 10:
            return "0%s_tuoi" % age
        else:
            return "%s_tuoi" % age

    def process_file(self, from_folder, from_filename, from_subfolder=None):
        from_path = join(from_folder, from_filename)
        self.log.info("File: %s" % from_path)
        (cdate, ctime, clat, clon) = self.get_info_from_exif(from_path)

        if not all([cdate, ctime]):
            self.log.info("Creation date time got None")
            dest_filename = from_filename
        else:
            dest_filename = "%s-%s-%s-%s.%s" % (cdate, ctime, clat, clon,
                                                from_filename[-3:])

        if from_subfolder is not None:
            dest_subfolder = from_subfolder
        else:
            if not cdate is None:
                dest_subfolder = self.subfolder_from_date(cdate)
            else:
                # We got None in cdate, try to get date in filename to have
                # sub-folder name
                re_parse = re.search('.*(20\d\d)(\d\d)(\d\d).*',
                                     str(from_filename))
                try:
                    year = re_parse.group(1)
                    month = re_parse.group(2)
                    day = re_parse.group(3)
                    dest_subfolder = self.subfolder_from_date("%s%s%s" %
                                                              (year,
                                                               month,
                                                               day))
                except Exception:
                    self.log.info("Cannot parse date in filename. Use 'other'")
                    dest_subfolder = "others"
                    pass

        self.log.debug("Destination subf: %s - fname: %s" % (dest_subfolder,
                                                             dest_filename))
        self.copy_file(from_path, dest_subfolder, dest_filename)

    def process_folder(self, folder_path, folder_name, level=1):
        self.log.info("Folder: %s (lvl: %s)" % (folder_path, level))
        items = [f for f in listdir(folder_path) if not f.startswith('.')]
        for item in items:
            if isfile(join(folder_path, item)):
                self.process_file(folder_path, item, folder_name)
            else:
                level += 1
                if level >= 3:
                    self.log.info("Max subfolder reach. Skip %s" % item)
                    continue
                self.process_folder(join(folder_path, item), folder_name, level)
        self.log.info("Done with folder.")

    def acquire_lock(self):
        if isfile(self.lock):
            self.log.info("Lock existed: " % self.lock)
            return
        else:
            try:
                lf = open(self.lock, 'w')
                lf.write("%s" % datetime.datetime.now())
                lf.close()
                self.log.info("Acquire %s" % self.lock)
            except Exception:
                if isfile(self.lock):
                    try:
                        unlink(self.lock)
                    except Exception:
                        pass
                raise ExEditFile("Fail in acquire %s" % self.lock)

    def release_lock(self):
        if isfile(self.lock):
            try:
                unlink(self.lock)
                self.log.info("Release %s" % self.lock)
            except Exception:
                pass

    def process(self):
        self.acquire_lock()
        items = [i for i in listdir(self.input) if not i.startswith('.')]
        for item in items:
            if isfile(join(self.input, item)):
                self.process_file(self.input, item)
            else:
                self.process_folder(join(self.input, item), item)
        self.release_lock()


def signal_handler(signal, frame):
        sys.exit(0)


if __name__ == "__main__":
    # For system input signal
    signal.signal(signal.SIGINT, signal_handler)

    # For option parser
    usage = "usage: %prog [options]"
    opt_parser = OptionParser(usage=usage)
    opt_parser.add_option("-i", "--input",
                          action="store", type="string", dest="input_path",
                          help="input path, must be a folder")
    opt_parser.add_option("-o", "--output",
                          action="store", type="string", dest="output_path",
                          help="output path, must be a folder")
    opt_parser.add_option("-r", "--review",
                          action="store", type="string", dest="review_path",
                          help="review path, must be a folder")
    opt_parser.add_option("-l", "--log",
                          default="/var/log/betterhome/photorename.log",
                          action="store", type="string", dest="log_path",
                          help="log path, must be a file")
    opt_parser.add_option("-c", "--lock",
                          default="/var/log/betterhome/photorename.lock",
                          action="store", type="string", dest="lock_path",
                          help="lock file path, must be a file")
    opt_parser.add_option("--debug", default=False,
                          action="store_true", dest="is_debug",
                          help="show debug logs")

    (options, args) = opt_parser.parse_args(sys.argv)

    input_path = options.input_path
    output_path = options.output_path
    review_path = options.review_path
    log_path = options.log_path
    lock_path = options.lock_path
    is_debug = options.is_debug
    debug = "debug" if is_debug else "info"

    photo_rename = PhotoRename(input_path, output_path, review_path,
                               log_path, debug, lock_path)
    try:
        photo_rename.process()
    except Exception as ex:
        photo_rename.log.error("Error of PhotoRename: %s" % ex.message)
        # FIXME
        # It's expected to send an alert mail HERE
    finally:
        photo_rename.release_lock()
