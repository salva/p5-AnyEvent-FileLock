use strict;
use warnings;

use Test::More tests => 2;
BEGIN { use_ok('AnyEvent::FileLock') };

use AE;
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
