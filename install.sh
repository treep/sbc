#!/bin/sh
#
# install SBC to the /opt/ directory
#

set -e

mkdir -p /opt/{bin,sbc}

cp sbc /opt/bin/

cp systems.lisp /opt/sbc/
cp compile.lisp /opt/sbc/
