package App::DiffTarballs;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

use File::chdir;
use IPC::System::Options qw(system);

our %SPEC;

my %xcompletion_tarball = (
    'x.completion' => [filename => {
        filter => sub {-f $_[0] && $_[0] =~ /\.tar\.?/},
    }],
);

$SPEC{diff_tarballs} = {
    v => 1.1,
    summary => 'Diff contents of two tarballs',
    description => <<'_',

This utility extracts the two tarballs to temporary directories and then
performs `diff -ruN` against the two. It deletes the temporary directories
afterwards.

_
    args => {
        tarball1 => {
            schema => 'filename*',
            %xcompletion_tarball,
            req => 1,
            pos => 0,
        },
        tarball2 => {
            schema => 'filename*',
            %xcompletion_tarball,
            req => 1,
            pos => 1,
        },
    },
    deps => {
        all => [
            {prog => 'tar'},
            {prog => 'diff'},
        ],
    },
    examples => [
        {
            argv => [qw/My-Dist-1.001.tar.gz My-Dist-1.002.tar.bz2/],
            summary => 'Show diff between two Perl releases',
            test => 0,
            'x.doc.show_result' => 0,
        },
    ],
};
sub diff_tarballs {
    require Cwd;
    require File::Temp;
    require ShellQuote::Any::Tiny;

    my %args = @_;

    return [404, "No such file or directory: $args{tarball1}"]
        unless -f $args{tarball1};
    return [404, "No such file or directory: $args{tarball2}"]
        unless -f $args{tarball2};

    my $abs_tarball1 = Cwd::abs_path($args{tarball1});
    my $abs_tarball2 = Cwd::abs_path($args{tarball2});

    return [404, "No such file or directory: $args{tarball1}"]
        unless -f $args{tarball1};
    return [404, "No such file or directory: $args{tarball2}"]
        unless -f $args{tarball2};

    my $dir1 = File::Temp::tempdir(CLEANUP => 1);
    my $dir2 = File::Temp::tempdir(CLEANUP => 1);

    $CWD = $dir1;
    system({log=>1, die=>1}, "tar", "xf", $abs_tarball1);
    system({log=>1, die=>1}, "tar", "xf", $abs_tarball2);
    return [304, "$args{tarball1} and $args{tarball2} are the same file"]
        if $abs_tarball1 eq $abs_tarball2;

    my $cleanup = !$ENV{DEBUG};

    $dir1 = File::Temp::tempdir(CLEANUP => $cleanup);
    $dir2 = File::Temp::tempdir(CLEANUP => $cleanup);

    $CWD = $dir1;
    system({log=>1, die=>1}, "tar", "xf", $abs_tarball1);
    my @glob1 = glob("*");
    unless (@glob1 == 1) {
        return [412, "$args{tarball1} did not extract to ".
                    "a single file/directory"];
    }

    $CWD = $dir2;
    system({log=>1, die=>1}, "tar", "xf", $abs_tarball2);
    my @glob2 = glob("*");
    unless (@glob2 == 1) {
        return [412, "$args{tarball2} did not extract to ".
                    "a single file/directory"];
    }

    my $name1 = $glob1[0];
    my $name2 = $glob2[0];
    $name1 .= ".0" if $name1 eq $name2;

    rename "$dir1/$glob1[0]", "$dir2/$name1";

    my $diff_cmd = $ENV{DIFF} // do {
        "diff -ruN" .
            (exists $ENV{NO_COLOR} ? " --color=never" :
             defined $ENV{COLOR} ? ($ENV{COLOR} ? " --color=always" : " --color=never") :
             "");
    };
    system({log=>1, shell=>1}, join(
        " ",
        $diff_cmd,
        ShellQuote::Any::Tiny::shell_quote($name1),
        ShellQuote::Any::Tiny::shell_quote($name2),
    ));

    unless ($cleanup) {
        log_info("Not cleaning up temporary directory %s", $dir2);
    }

    [200];
}

1;
# ABSTRACT:

=head1 SYNOPSIS

See the included script L<diff-tarballs>.


=head1 ENVIRONMENT

=head2 DEBUG

Bool. If set to true, will cause temporary directories to not being cleaned up
after the program is done.

=head2 DIFF

String. Set diff command to use. Defaults to C<diff -ruN>. For example, you can
set it to C<diff --color -ruN> (C<--color> requires GNU diff 3.4 or later), or
C<colordiff -ruN>.

=head2 NO_COLOR

If set (and L</DIFF> is not set), will add C<--color=never> option to diff
command.

=head2 COLOR => bool

If set to true (and L</DIFF> is not set), will add C<--color=always> option to
diff command.

If set to false (and L</DIFF> is not set), will add C<--color=never> option to
diff command.

Note that L</NO_COLOR> takes precedence.
