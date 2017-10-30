package Catalyst::Plugin::DBIC::ConsoleQueryLog;

use Moo::Role;
use Catalyst::Utils;
use Text::SimpleTable;

our $VERSION = '0.001';

my $_model_name = '';
my $model_name = sub {
  my $c = shift;
  return $_model_name ||= do {
    if(my $config = $c->config->{'Plugin::DBIC::ConsoleQueryLog'}) {
      $config->{'model_name'};
    } else {
      undef;
    }
  };
};

my $model = sub {
  my $c = shift;
  my $model = $c->model($c->$model_name);
  if($model) {
    return $model;
  } else {
    $c->log->info("You specified a model '$model_name' but I can't find it.") if $model_name;
    return;
  }
};

my $querylog_analyzer = sub {
  my $c = shift;
  my $model = $c->$model || return;
  if($model->can('querylog_analyzer')) {
    return $model->querylog_analyzer;
  } else {
    $c->log->info("You requested querylog display for model $model but there's no querylog_analyzer");
    return;
  }
};

my $sorted_queries = sub {
  my $c = shift;
  my @sorted_queries = @{($c->$querylog_analyzer||return)
    ->get_sorted_queries ||[]};
  return @sorted_queries;
};

after 'finalize', sub {
  return unless (my $c = shift)->debug;
  my $t = $c->querylog_table;
  my @sorted_queries = $c->$sorted_queries;
  foreach my $q (@sorted_queries) {
    $c->add_querylog_table_row($t, $q);
  }
  $c->log->info( "SQL Profile Data:\n" . $t->draw . "\n" );
};

sub querylog_table {
  my $column_width = Catalyst::Utils::term_width() - 6 - 18;
  my $t = Text::SimpleTable->new( [ $column_width, 'SQL' ], [ 12, 'Time' ] );
  return $t;
};

sub add_querylog_table_row {
  my ($c, $t, $q) = @_;
  my $q_sql = $q->sql . ' : ' . join(', ', @{$q->params||[]});
  my $q_total = sprintf('%0.6f', $q->time_elapsed);
  $t->row($q_sql, $q_total);
};

1;
