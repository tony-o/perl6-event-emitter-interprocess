#!/usr/bin/env perl6

my $proc = Proc::Async.new(:w, "perl6", '5');
 
$proc.stdout.act(&say);
$proc.stderr.act(&warn);

my $prom = $proc.start; 
$proc.write(Buf.new(0x63,0x64,0x65)); 
#$proc.close-stdin;
await $prom;

