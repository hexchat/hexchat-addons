#!/usr/bin/env python
# -*- coding: utf-8 -*-
import xchat
import random

# Copyright (c) 2014, MAGIC
# All rights reserved.
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

# 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
# 3. Neither the name of the contributors may be used to endorse or promote products derived from this software without specific prior written permission.

# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


__module_name__ = "#VIzon betting generator"
__module_version__ = "1.1"
__module_author__ = "MAGIC"
__module_description__ = "Generates random numbers for #VIzon and /notices them to guuchan"


def randomz(word, eol, data): # mfw can't use 'def random' cause of pythons 'random' function
	numbers = str(random.sample([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29], 6))
	no_brackets = str(numbers).strip('[]')
	output = no_brackets.replace(",", "")
	xchat.command('notice guuchan !bet ' + output)
	return xchat.EAT_ALL # kills remaining bits of memory
	
def check(word, word_eol, data):
	xchat.command('notice guuchan !check ' + word_eol[1].decode('utf-8').encode('utf-8'))
	return xchat.EAT_ALL # kills remaining bits of memory
 
def unload_cb(userdata):
    print(__module_name__ + ' version '  + __module_version__ + ' unloaded. ')


xchat.hook_unload(unload_cb)
xchat.hook_command("vizon",randomz,help="/vizonhelp - generates random number and /notice them to guuchan")
xchat.hook_command("check",check,help="/vizonhelp - generates random number and /notice them to guuchan")
print(__module_name__ + ' version '  + __module_version__ + ' by ' + __module_author__ + ' loaded. ')