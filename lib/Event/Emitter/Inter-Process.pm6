use Event::Emitter::Role::Handler;

role Event::Emitter::Inter-Process does Event::Emitter::Role::Handler;

has Bool $!sub-process = False;
has Int  $!tapid;

has @!events;
has %!tapbuf;

my \PROC_STATE_SIZE1 = 0;
my \PROC_STATE_EVENT = 1;
my \PROC_STATE_SIZE2 = 2;
my \PROC_STATE_SIZEM = 3;
my \PROC_STATE_DATA  = 4;


submethod BUILD(Bool :$sub-process? = False) {
  $!tapid = 0; 
  $!sub-process = $sub-process;
  if $sub-process { 
    start {
      my $data = %(
        buffer => Buf.new,
        lsize  => 0,
        event  => Buf.new,
        state  => PROC_STATE_SIZE1,
      );
      my $last = 0;
      my $lastloop = $*IN.eof;
      while ! $*IN.opened { sleep .1; }
      while (!$*IN.eof) || $lastloop {
        my $d = $lastloop ?? $*IN.slurp-rest(:bin) !! $*IN.read(1);
        warn $d.perl if $d.elems;
        $data<buffer> ~= $d;


        if self!state($data) {
          self!run($data<event>.decode, $data<data>); 
        }
        last if $lastloop;
        $lastloop = True if $*IN.eof && !$lastloop;
      }    
    }
  }
}

method !run($event, $data) {
  my @a = @!events.grep(-> $e {
    given ($e<event>.WHAT) {
      when Regex    { $event ~~ $e<event> }
      when Callable { $e<event>.($event)  }
      default       { $e<event> eq $event }
    };
  });
  @a.perl.say;
  $_<callable>($data) for @a;
}

method !state($state is rw) {
  if $state<state> == PROC_STATE_SIZE1 &&
     $state<buffer>.elems >= 1
  {
    warn 'SIZE1';
    $state<lsize> = $state<buffer>[0];
    $state<buffer> .=subbuf(1);
    $state<state>++;
  }
  if $state<state> == PROC_STATE_EVENT && 
     $state<buffer>.elems >= $state<lsize> 
  {
    warn 'EVENT';
    $state<event> = $state<buffer>.subbuf(0, $state<lsize>); 
    $state<buffer> .=subbuf($state<lsize>);
    $state<state>++;
  }
  if $state<state> == PROC_STATE_SIZE2 && 
     $state<buffer>.elems > 0
  {
    warn 'SIZE2';
    #warn $state<buffer>.elems;
    #warn $state<buffer>.perl;
    $state<lsize> = $state<buffer>[0] * 256;
    #warn $state<lsize>;
    $state<buffer> .=subbuf(1);
    $state<state>++;
    #warn $state<buffer>.perl;
  }
  if $state<state> == PROC_STATE_SIZEM &&
     $state<buffer>.elems > 0
  {
    warn 'SIZEM';
    #warn $state<buffer>.elems;
    #warn $state<buffer>.perl;
    $state<lsize> += $state<buffer>[0];
    #warn $state<lsize>;
    $state<buffer> .=subbuf(1);
    #try warn $state<buffer>.perl;
    $state<state>++;
  }   
  if $state<state> == PROC_STATE_DATA &&
     $state<buffer>.elems >= $state<lsize> 
  {
    warn 'DATA';
    #warn $state<lsize>;
    $state<data>   = $state<buffer>.subbuf(0, $state<lsize>);
    #try warn "DATA: {$state<data>.perl}";
    $state<buffer> .=subbuf($state<lsize>);
    $state<state> = 0; 
    return True;
  }
  return False;
}

method hook(Proc::Async $proc) {
  my $id = $!tapid++;
  %!tapbuf{$id} = %( 
    process => $proc,
    state   => PROC_STATE_SIZE1,
    buffer  => Buf.new,
    lsize   => 0,
    event   => Buf.new,
    data    => Buf.new,
  );
  my Supply $c    .= new;
  my        $state = %!tapbuf{$id};
  $c.tap(-> $d { 
    if self!state($state) {
      self!run($state<event>.decode, $state<data>); 
      $c.emit(1);
    }
  });
  $proc.stdout(:bin).tap(-> $data {
    $state<buffer> = $state<buffer> ~ $data;
    $c.emit(1);
  });
}

method on($event, Callable $callable) {
  @!events.push({
    event    => $event,
    callable => $callable,
  });
}

method emit(Blob $event, Blob $data? = Blob.new) {
  my Blob $msg  .= new;  
  my Int $bytes = 0;

  #encode $event
  $msg ~= Buf.new($event.bytes);
  $msg ~= Buf.new($event);
  
  #encode $data size
  $msg ~= Buf.new(($data.elems/256).floor);
  $msg ~= Buf.new($data.elems % 256);

  $msg ~= Buf.new($data);

  $*OUT.write($msg) if $!sub-process;
  if !$!sub-process {
    for %!tapbuf.keys -> $i {
      try { 
      say "write ({$msg.perl}) to ({%!tapbuf{$i}<process>.perl});";
      %!tapbuf{$i}<process>.write($msg);
      CATCH { default { 'CAUGHT'.say; .say; } }
      }
    }
  }
  $msg;
}

