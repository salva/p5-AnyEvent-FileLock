package AnyEvent::FileLock;

our $VERSION = '0.01';

use strict;
use warnings;
use 5.010;
use Carp;
use AE;

use Fcntl ();
use Method::WeakCallback qw(weak_method_callback);

sub flock {
    my ($class, %opts) = @_;
    my $mode = delete $opts{mode} // '+<';
    my $flock_mode = delete $opts{flock_mode} // $mode;
    my $operation = ($flock_mode eq '<' ? Fcntl::LOCK_SH() : Fcntl::LOCK_EX());
    my $delay = delete $opts{delay} || 0.1;

    my $user_cb = delete $opts{cb} // croak "cb argument is missing";

    my $max_time;
    if (defined(my $timeout = delete $opts{timeout})) {
        $max_time = AE::now() + $timeout;
    }

    my $fh;
    my $file = delete $opts{file};
    if (defined $file) {
        my $open_mode = delete $opts{open_mode} // $mode;
        $open_mode =~ /^\+?(?:<|>>?)/ or croak "bad mode specification";
        open $fh, $mode, $file or return
    }
    else {
        $fh = delete $opts{file} // croak "file or fh argument is required";
    }

    %opts and croak "unkwnown arguments found (".join(', ', sort keys %opts).")";

    my $self = { file => $file,
                 fh => $fh,
                 operation => $operation,
                 max_time => $max_time,
                 user_cb => $user_cb,
                 delay => $delay };
    bless $self, $class;

    my $alcb = $self->{acquire_lock_cb} = weak_method_callback($self, '_acquire_lock');
    &AE::postpone($alcb);

    $self;
}

sub _acquire_lock {
    my $self = shift;
    my $operation = $self->{opertation};
    my $now = AE::now;

    if (CORE::flock($self->{fh}, $self->{operation}|Fcntl::LOCK_NB())) {
        $self->{user_cb}->($self->{fh});
    }
    elsif ($! == Errno::EAGAIN() and
         (!defined($self->{max_time}) or $self->{max_time} <= $now)) {
        &AE::timer($self->{delay}, 0, $self->{acquire_lock_cb});
        return;
    }
    else {
        $self->{user_cb}->();
    }
    # release all the references, the object is useless from this
    # point on time.
    %$self = ();
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

AnyEvent::FileLock - Lock files asynchronously

=head1 SYNOPSIS

  use AnyEvent::FileLock;

  my $w = AnyEvent::FileLock->flock(file => $fn,
                                    cb => sub { ... },
                                    mode => '<',
                                    delay => $seconds,
                                    timeout => $timeout);


=head1 DESCRIPTION

This module tries to lock some file repeatly until it success or a
timeout happens.

=head2 API

The function provides a unique method C<flock> accepting the following
arguments:

=over 4

=item fh => $file_handle

When this argument is given the passed file handle is used as the file
locking target.

=item file => $file_name

When this argument is given a file with the given name will be opened
or created and then the module will try to lock it.

=item cb => $sub_ref

The given function is called once the lock is acquired on the
file with the file handle passed as an argument.

In case of error (i.e. timeout) C<undef> will be passed instead of the
file handle. The error can be retrieved from C<$!>.

The user is responsible for closing the file handle or calling
C<flock($fh, LOCK_UN)> on it when required.

=item open_mode => $mode

The mode used to open the file when the argument C<file> is
passed. Accepted values are C<< < >>, C<< > >>, C<<< >> >>>, C<< +< >>
and C<< +> >>.

=item flock_mode => $mode

The mode used when locking the file, it accepts the same set of values
as C<open_mode>. C<< < >> means shared access and everything else
exclusive access.

=item mode => $mode

Configures both C<open_mode> and C<flock_mode>.

=item timeout => $seconds

The operation is aborted if the lock operation can not be completed
for the given lapse.

Note that this timeout is aproximate, it is checked just after every
failed locking attempt.

=item delay => $seconds

Time to be delayed between consecutive locking attemps. Defaults to 1
second.

=back

=head1 SEE ALSO

L<AnyEvent>.

=head1 AUTHOR

Salvador FandiE<ntilde>o, E<lt>sfandino@yahoo.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Qindel FormaciE<ntilde>n y Servicios S.L.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
