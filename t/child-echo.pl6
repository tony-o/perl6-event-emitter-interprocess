#!/usr/bin/env perl6

use Event::Emitter::Inter-Process;

my $ee = Event::Emitter::Inter-Process.new(:sub-process(True));

warn "{$*IN.^attributes}";

$ee.on('echo', -> $data {
  $ee.emit('echo'.encode, $data);
});

warn 'sleeping';
sleep 12;
