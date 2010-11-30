#!perl -w
# Generate the CPAN installed version of get_flash_videos, i.e. set
# $SCRIPT_NAME.

open my $out, ">", $ARGV[0] or die $!;

my $install_type = exists $ENV{GFV_INSTALL_TYPE} ? $ENV{GFV_INSTALL_TYPE} : "";

# So, despite having 3 environment variables that seem to serve the purpose of
# identifying which CPAN shell you're using various bugs seem to mean they
# aren't set how you'd expect.

# cpanplus: Look at the version environment variable only (all the other shells
# set CPANPLUS_IS_RUNNING).
$install_type ||= "cpan-cpanp" if $ENV{PERL5_CPANPLUS_IS_VERSION};

# cpanminus: Appears to be buggy, only PERL5_CPANPLUS_IS_RUNNING is set. (But
# also handle the CPANM variable being set just in case someone fixes this
# bug).
$install_type ||= "cpan-cpanm" if(
	($ENV{PERL5_CPANPLUS_IS_RUNNING} and !$ENV{PERL5_CPAN_IS_RUNNING})
	|| $ENV{PERL5_CPANM_IS_RUNNING});

# cpan: Just check the original environment variable, we've ruled out the other
# shells now.
$install_type ||= "cpan-cpan" if $ENV{PERL5_CPAN_IS_RUNNING};

# Not under a shell (probably).
$install_type ||= "cpan-manual";

# ...phew

# Add our header with the type...
print $out <<EOF;
#!$^X
\$::SCRIPT_NAME = "get_flash_videos";
\$::INSTALL_TYPE = "$install_type";
EOF

open my $in, "<", "get_flash_videos" or die $!;

<$in>; # throw away first line (shebang) for tidyiness.
print $out join "", <$in>;

