package App::AcmeCpanauthors;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

our %SPEC;

sub _should_skip {
    local $_ = shift;
    # exclude known modules that do not contain list of CPAN authors
    return 1 if /\A(Utils\::.+|Utils|Factory|Register)\z/;
    0;
}

sub _list_installed {
    require Module::List;
    my $mods = Module::List::list_modules(
        "Acme::CPANAuthors::",
        {
            list_modules  => 1,
            list_pod      => 0,
            recurse       => 1,
        });
    my @res;
    for my $ca0 (sort keys %$mods) {
        my $ca = $ca0;
        $ca =~ s/\AAcme::CPANAuthors:://;
        next if _should_skip($ca);
        push @res, {
            name => $ca,
        };
     }
    \@res;
}

$SPEC{acme_cpanauthors} = {
    v => 1.1,
    summary => 'Unofficial CLI for Acme::CPANAuthors',
    args => {
        action => {
            schema  => ['str*', in=>[
                'list_cpan', 'list_installed',
                'list_ids',
            ]],
            req => 1,
            cmdline_aliases => {
                list_cpan => {
                    summary => 'Shortcut for --action list_cpan',
                    is_flag => 1,
                    code    => sub { $_[0]{action} = 'list_cpan' },
                },
                L => {
                    summary => 'Shortcut for --action list_cpan',
                    is_flag => 1,
                    code    => sub { $_[0]{action} = 'list_cpan' },
                },
                list_installed => {
                    summary => 'Shortcut for --action list_installed',
                    is_flag => 1,
                    code    => sub { $_[0]{action} = 'list_installed' },
                },
                list_ids => {
                    summary => 'Shortcut for --action list_ids',
                    is_flag => 1,
                    code    => sub { $_[0]{action} = 'list_ids' },
                },
            },
        },
        module => {
            summary => 'Acme::CPANAuthors::* module name, without Acme::CPANAuthors:: prefix',
            schema => ['str*'],
            pos => 0,
            completion => sub {
                require Complete::Module;
                my %args = @_;
                Complete::Module::complete_module(
                    word => $args{word},
                    find_pod => 0,
                    find_prefix => 0,
                    ns_prefix => 'Acme::CPANAuthors',
                );
            },
        },
        lcpan => {
            schema => 'bool',
            summary => 'Use local CPAN mirror first when available (for -L)',
        },
        detail => {
            summary => 'Display more information when listing modules/result',
            schema  => 'bool',
            cmdline_aliases => {l=>{}},
        },
    },
    examples => [
        {
            argv => [qw/--list-installed/],
            summary => 'List installed Acme::CPANAuthors::* modules',
            test => 0,
            'x.doc.show_result' => 0,
        },
        {
            argv => [qw/--list-cpan/],
            summary => 'List available Acme::CPANAuthors::* modules on CPAN',
            test => 0,
            'x.doc.show_result' => 0,
        },
        {
            argv => [qw/-L --lcpan/],
            summary => 'Like previous example, but use local CPAN mirror first',
            test => 0,
            'x.doc.show_result' => 0,
        },
        {
            argv => [qw/--list-ids Indonesian/],
            summary => "List PAUSE ID's of Indonesian authors",
            test => 0,
            'x.doc.show_result' => 0,
        },
    ],
};
sub acme_cpanauthors {
    my %args = @_;

    my $action = $args{action};
    my $detail = $args{detail};
    my $module = $args{module};

    if ($action eq 'list_installed') {

        my @res;
        for (@{ _list_installed() }) {
            if ($detail) {
                push @res, $_;
            } else {
                push @res, $_->{name};
            }
        }
        [200, "OK", \@res,
         {('cmdline.default_format' => 'text') x !!$detail}];

    } elsif ($action eq 'list_cpan') {

        my @methods = $args{lcpan} ?
            ('lcpan', 'metacpan') : ('metacpan', 'lcpan');

      METHOD:
        for my $method (@methods) {
            if ($method eq 'lcpan') {
                unless (eval { require App::lcpan::Call; 1 }) {
                    warn "App::lcpan::Call is not installed, skipped listing ".
                        "modules from local CPAN mirror\n";
                    next METHOD;
                }
                my $res = App::lcpan::Call::call_lcpan_script(
                    argv => [
                        qw/mods --namespace Acme::CPANAuthors/,
                        ("-l") x !!$detail,
                    ],
                );
                return $res if $res->[0] != 200;
                if ($detail) {
                    return [200, "OK",
                            [grep {!_should_skip($_->{module})}
                                 map {$_->{module} =~ s/\AAcme::CPANAuthors:://; $_}
                                     grep {$_->{module} =~ /Acme::CPANAuthors::/} sort @{$res->[2]}]];
                } else {
                    return [200, "OK",
                            [grep {!_should_skip($_)}
                                 map {s/\AAcme::CPANAuthors:://; $_}
                                     grep {/Acme::CPANAuthors::/} sort @{$res->[2]}]];
                }
            } elsif ($method eq 'metacpan') {
                unless (eval { require MetaCPAN::Client; 1 }) {
                    warn "MetaCPAN::Client is not installed, skipped listing ".
                        "modules from MetaCPAN\n";
                    next METHOD;
                }
                my $mcpan = MetaCPAN::Client->new;
                my $rs = $mcpan->module({
                        'module.name'=>'Acme::CPANAuthors::*',
                    });
                my @res;
                while (my $row = $rs->next) {
                    my $mod = $row->module->[0]{name};
                    say "D: mod=$mod" if $ENV{DEBUG};
                    $mod =~ s/\AAcme::CPANAuthors:://;
                    next if _should_skip($mod);
                    push @res, $mod unless grep {$mod eq $_} @res;
                }
                warn "Empty result from MetaCPAN\n" unless @res;
                return [200, "OK", [sort @res]];
            }
        }
        return [412, "Can't find a way to list CPAN mirrors"];

    } elsif ($action eq 'list_ids') {

        return [400, "Please specify module"] unless $module;

        require Acme::CPANAuthors;
        my $authors = Acme::CPANAuthors->new($module);
        [200, "OK", [$authors->id]];

    } else {

        [400, "Unknown action '$action'"];

    }
}

1;
# ABSTRACT:

=head1 SYNOPSIS

See the included script L<acme-cpanauthors>.


=head1 ENVIRONMENT

=head2 DEBUG => bool


=head1 SEE ALSO

L<Acme::CPANAuthors> and C<Acme::CPANAuthors::*> modules.
