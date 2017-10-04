use strict;
use warnings;

use Test::More tests => 3;
BEGIN { use_ok('AnyEvent::FileLock') };

use AE;
use Fcntl;
use File::Temp qw(tempfile);

subtest 'file handle as locking target' => sub {
    my $cv = AE::cv();
    my $temp_fh = tempfile();
    my $got_lock;
    my $w = AnyEvent::FileLock->flock(
        fh => $temp_fh,
        cb => sub {
            my ($fh) = @_;
            $got_lock = (defined $fh) ? 1 : 0;
            close($fh);
            $cv->send();
        },
    );
    $cv->recv();
    is($got_lock, 1, 'got lock');

    done_testing();
};

subtest 'retry to get lock' => sub {
    my $cv = AE::cv();
    my ($temp_fh, $filename) = tempfile();
    flock($temp_fh, Fcntl::LOCK_EX|Fcntl::LOCK_NB);

    my $got_lock;
    my $w = AnyEvent::FileLock->flock(
        file => $filename,
        cb   => sub {
            my ($fh) = @_;
            $got_lock = (defined $fh) ? 1 : 0;
            close($fh);
            $cv->send();
        },
    );
    my $t = AE::timer(0.3, 0, sub { flock($temp_fh, Fcntl::LOCK_UN); });
    $cv->recv();
    is($got_lock, 1, 'got lock');
    is_deeply($w, {}, 'object emptied');

    done_testing();
};
