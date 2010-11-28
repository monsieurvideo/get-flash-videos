#!perl -w
# Generate the CPAN installed version of get_flash_videos, i.e. set
# $SCRIPT_NAME.

open my $out, ">", $ARGV[0] or die $!;

# Add our header with the type..
print $out <<EOF;
#!$^X
\$::SCRIPT_NAME = "get_flash_videos";
\$::SCRIPT_TYPE = "CPAN";
EOF

open my $in, "<", "get_flash_videos" or die $!;

<$in>; # throw away first line (shebang) for tidyiness.
print $out join "", <$in>;

