#!/usr/bin/python3

from purity_fb import PurityFb, FileSystem, NfsRule, rest

import os

# Requirements: environments variables FB_MGMT_VIP and FB_MGMT_TOKEN.

# Caution: this script deletes a filesystem so make sure it is safe to do so
# before use.

# Disable warnings related to unsigned SSL certificates on the FlashBlade.
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Create PurityFb object for a certain array using environment variables.
FB_MGMT = os.environ.get('FB_MGMT_VIP')
TOKEN = os.environ.get('FB_MGMT_TOKEN')

# Constants.
FS_NAME="ior-benchmark"
FS_SIZE=10 * 1024 * 1024 * 1024 * 1024  # 10TB

# Create management object.
fb = PurityFb(FB_MGMT)
fb.disable_verify_ssl()

try:
    fb.login(TOKEN)
except rest.ApiException as e:
    print("Exception: %s\n" % e)

try:
    # First, if the filesystem already exists, delete it.
    res = fb.file_systems.list_file_systems(names=[FS_NAME])

    if len(res.items) == 1:
        print("Found existing filesystem {}, deleting.".format(FS_NAME))
        fb.file_systems.update_file_systems(name=FS_NAME,
                attributes=FileSystem(nfs=NfsRule(v3_enabled=False)))
        fb.file_systems.update_file_systems(name=FS_NAME, attributes=FileSystem(destroyed=True))
        fb.file_systems.delete_file_systems(name=FS_NAME)

except rest.ApiException as e:
    print("Exception: %s\n" % e)

try:
    print("Creating filesystem {}".format(FS_NAME))
    fs_obj = FileSystem(name=FS_NAME, provisioned=FS_SIZE)
    fb.file_systems.create_file_systems(fs_obj)
    fb.file_systems.update_file_systems(name=FS_NAME,
            attributes=FileSystem(nfs=NfsRule(v3_enabled=True)))
except rest.ApiException as e:
    print("Exception: %s\n" % e)

fb.logout()
