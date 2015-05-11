#!/usr/bin/env perl6

use Event::Emitter::Inter-Process;
use Test;

plan 2;

my $ee = Event::Emitter::Inter-Process.new;

my Proc::Async $proc .= new(:w, 'perl6', '-Ilib', $*SPEC.catpath('', 't', 'child-echo.pl6'));

$proc.stdout(:bin).tap(-> $w { 
  warn "FROM: \$proc";
  warn $w.decode;
});
$proc.stderr(:bin).tap(-> $w { 
  warn "FROM: \$proc";
  warn $w.decode;
});

$ee.hook($proc);

my $str = ('a'..'z').pick(64).join('');

my @events;
my $promise = Promise.new;
$ee.on("echo", -> $data {
  @events.push($data).decode;
  $data.perl.say;
  $promise.keep(True);
});

my $pro = $proc.start;
$ee.emit('echo'.encode, $str.encode);

await Promise.allof($promise, $pro);

ok @events[0] eq $str, "Did child echo '$str'?";
