# Disable WebTalk data collection
config_webtalk -user off
config_webtalk -install off

# Disable version check network call
set_param allow_version_check false

# Use all available cores for synthesis and implementation
set_param general.maxThreads [exec nproc]
