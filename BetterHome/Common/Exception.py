

class ExPhotoRename(Exception):
    def __init__(self, mess):
        self.message = mess


class ExEditFile(Exception):
    def __init__(self, mess):
        self.message = mess