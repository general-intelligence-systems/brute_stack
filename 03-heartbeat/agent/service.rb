#!/usr/bin/env falcon-host

eval File.read(File.expand_path("_common/falcon.rb", root)), binding, "_common/falcon.rb"
eval File.read(File.expand_path("_common/heartbeat.rb", root)), binding, "_common/heartbeat.rb"
