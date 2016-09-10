#!/usr/bin/env python

import sys

f = open(sys.argv[1], 'rb')
while True:
  d = f.read(100)
  if len(d) == 0:
    break
  for b in d:
    sys.stdout.write('%02x\n' % ord(b))
