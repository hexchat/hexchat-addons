"""Functions for writing to online pastebins. Written for the HexChat plugin
Floodcontrol, but usable as a standalone module in any project."""

# Author & maintainer: BurritoBazooka <burritobazooka@gmail.com>
# License: Unlicense
###########################################
# This is free and unencumbered software released into the public domain.

# Anyone is free to copy, modify, publish, use, compile, sell, or distribute this 
# software, either in source code form or as a compiled binary, for any purpose, 
# commercial or non-commercial, and by any means.

# In jurisdictions that recognize copyright laws, the author or authors of this 
# software dedicate any and all copyright interest in the software to the public domain.
# We make this dedication for the benefit of the public at large and to the detriment 
# of our heirs and successors.  We intend this dedication to be an overt act of 
# relinquishment in perpetuity of all present and future rights to this software 
# under copyright law.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTBILITY, FITNESS FOR A 
# PARTICULAR PURPOSE AND NONINFRINGEMENT, IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR 
# ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR 
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR 
# OTHER DEALINGS IN THE SOFTWARE.
###########################################
# TODO:
# We will support one or two fallback pastebins, as well as picking a main package
# like pastebinit for writing.

# We will support haste, elmer, possibly also bpaste:
# http://hackage.haskell.org/package/haste
# https://github.com/sudokode/elmer
# https://github.com/cbramy/bpaste
# And then also HTTPing to pb: https://ptpb.pw/

import requests
import time
import subprocess

try:
    import urlparse
except ImportError: #py3
    import urllib.parse as urlparse

TIME_UNITS = {"s": 1,
              "mi": 60,
              "h": 60*60,
              "d": 60*60*24,
              "w": 60*60*24*7,
              "mo": 60*60*24*30,
              "y": 60*60*24*365
              }

class PastebinError(BaseException):
    pass

class PastebinAPINotFound(PastebinError):
    pass

class PastebinGaveNoURL(PastebinError):
    pass

class PastebinAPINameConflict(PastebinError):
    pass

def human_time_to_seconds(time_expr):
    # Converts simple time intervals ("10 seconds", "1 week", "1.5 days") to int seconds.
    # That's it. It can't do "1 week and 20 minutes".
    # Times must be in a string format of "<number> [unit]". Default unit is seconds.
    try:
        return int(time_expr)
    except ValueError:
        pass
    n, unit = time_expr.strip().lower().split(" ")
    n = float(n)

    for k, v in TIME_UNITS.items():
        if unit.startswith(k):
            return int(v * n)

    raise ValueError("Invalid unit. Valid ones are those that start with: {}".format(list(TIME_UNITS.keys())))

def trim(s, lines=None, chars=None, suffix="\n..."):
    """Trim `s` by `lines` and `chars`, and add `suffix`"""
    if lines is None and chars is None:
        return s

    sl = s.splitlines()

    if lines is not None:
        jsl = "\n".join(sl[:lines])
    else:
        jsl = sl

    if chars is not None:
        cs = jsl[:chars]
    else:
        cs = jsl

    return cs + suffix

class PastebinAPI(object):
    """Common superclass for all pastebin APIs. Subclass it to create new APIs."""
    def __init__(*args, **kwargs):
        # We are only using classes to group code together and to help define
        # APIs using a common interface while storing very little state information
        # relevant to only one 'instance'.
        # It doesn't make sense to instantiate as an object.
        raise NotImplementedError

    @staticmethod
    def write(contents, expiry=None, exposure="unlisted", syntax="text", readcount=None, user_agent=None, **kwargs):
        raise NotImplemented

    @staticmethod
    def read(url, lines=None, chars=None, user_agent=None, **kwargs):
        raise NotImplemented

class PastebinAPIObject(object):
    pass

class pb(PastebinAPI):
    home_url = "https://ptpb.pw/"
    lexers = None
    formatters = None
    @staticmethod
    def write(contents, expiry=None, exposure="unlisted", syntax="text", formatter=None, user_agent=None, **kwargs):
        options = {
            "c": contents,
            }
        if exposure is "private":
            options['p'] = 1
        # if expiry is not None:
        #     options['s'] = human_time_to_seconds(expiry)
        if expiry is None:
            options['s'] = human_time_to_seconds("1 week")
        else:
            options['s'] = human_time_to_seconds(expiry)

        headers = {}
        if user_agent:
            headers['user-agent'] = user_agent
        r = requests.post(pb.home_url, data=options, headers=headers)
        r.raise_for_status()
        result = {}
        for line in r.text.split("\n"):
            k, _, v = line.partition(": ")
            result[k] = v

        r_msg = r.text.replace("\n", "; ")
        if 'url' not in result:
            raise PastebinGaveNoURL(r_msg)

        url = result['url']
        if syntax in pb.get_lexers():
            url = url + "/" + syntax
            if formatter in pb.get_formatters():
                url = url + "/" + formatter

        return url, r_msg
    @staticmethod
    def read(url, lines=None, chars=None, user_agent=None, **kwargs):
        split_path = urlparse.urlsplit(url).path.split("/")
        paste_id = [i for i in split_path if i][0]
        return trim(pb.read_id(paste_id), lines, chars)

    @staticmethod
    def read_id(paste_id):
        r = requests.get(pb.home_url + paste_id)
        r.raise_for_status()
        return r.text

    @classmethod
    def get_lexers(cls, force_update=False):
        if force_update or cls.lexers is None:
            r = requests.get(cls.home_url + "l")
            results = []
            for line in r.text.splitlines():
                results.append(line.lstrip("- "))
            cls.lexers = results
        return cls.lexers

    @classmethod
    def get_formatters(cls, force_update=False):
        if force_update or cls.formatters is None:
            r = requests.get(cls.home_url + "lf")
            results = []
            for line in r.text.splitlines():
                results.append(line.lstrip("- "))
            cls.formatters = results
        return cls.formatters

class _dummy(PastebinAPI):
    home_url = "https://example.com/"
    @staticmethod
    def write(contents, **kwargs):
        time.sleep(0.5)
        return "https://example.com/dummy_paste", "Success"
    @staticmethod
    def read(url, lines=None, chars=None, sample_lines=70, **kwargs):
        sample_paste = "".join(["Line {} of sample paste from {}\n".format(i, url) for i in range(sample_lines)])
        return trim(sample_paste, lines, chars)

class ShellCommandPastebin(PastebinAPIObject):
    def __init__(self, apiname, shellcommand, shellcommand_read):
        self.shellcommand = shellcommand # shellcmd which takes content in stdin gives a URL in stdout. e.g. curl -F 'f:1=<-' ix.io
        if apiname is None:
            self.apiname = shellcommand
        else:
            self.apiname = apiname
        self.shellcommand_read = shellcommand_read # shellcmd which takes a URL in stdin gives content in stdout. e.g. xargs curl
    def run_shellcommand(self, shellcommand, stdin_data):
        process = subprocess.Popen(shellcommand, shell=True, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        out, err = process.communicate(input=stdin_data)
        if err:
            raise PastebinError(self, err)
        return out
    def write(self, content, *args, **kwargs):
        out = self.run_shellcommand(self.shellcommand, content).strip()
        return out, out
    def read(self, url, *args, **kwargs):
        out = self.run_shellcommand(self.shellcommand_read, url).strip()
        return out, out
    def __repr__(self):
        return "<ShellCommandPastebin, apiname={}>".format(self.apiname, self.shellcommand)
    def remove_api(self):
        shellcommand_pastebins.remove(self)

shellcommand_pastebins = []
def add_shellcommand_pastebin(apiname, shellcommand, shellcommand_read):
    global shellcommand_pastebins

    existing_names = {b.apiname: b for b in shellcommand_pastebins}
    existing_names.update({c.__name__: c for c in PastebinAPI.__subclasses__()})
    if apiname in existing_names:
        raise PastebinAPINameConflict(existing_names[b])
    new_bin = ShellCommandPastebin(apiname, shellcommand, shellcommand_read)
    shellcommand_pastebins.append(new_bin)
    return new_bin

def get_api_by_name(apiname):
    apis = {b.apiname: b for b in shellcommand_pastebins}
    apis.update({c.__name__: c for c in PastebinAPI.__subclasses__()})
    api = apis.get(apiname)
    if api is not None:
        return api
    raise PastebinAPINotFound(apiname)

def get_api_names():
    return {c.__name__ for c in PastebinAPI.__subclasses__()}.union(
        {b.apiname for b in shellcommand_pastebins}
        )


# Service write functions must return a tuple, the first value is a URL to give to the user,
# The second is arbitrary data/information to print, or None.

# Service read functions must return plaintext corresponding to the requested paste URL.
# No formatting should be returned.

# Keyword arguments for read and write functions are intended to be flexible,
# because of the variance in Pastebins' features. You should be explicit in specifying
# kwargs when calling these functions, rather than relying on their positions.
# Read and write functions should therefore also accept the "**kwargs" wildcard,
# so that keywords irrelevant to a specific API can be discarded without errors.

# IDEA: HexChat can open a new window for reading.
