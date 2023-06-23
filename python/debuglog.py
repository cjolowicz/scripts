# Copy-paste for debugging.
def log(message):
    import json
    import os
    import sys

    filename = sys._getframe().f_back.f_code.co_filename
    function = sys._getframe().f_back.f_code.co_qualname
    data = {
        "pid": os.getpid(),
        "filename": filename,
        "function": function,
        "message": message,
    }

    with open("/tmp/log", mode="a") as io:
        print(json.dumps(data), file=io)
