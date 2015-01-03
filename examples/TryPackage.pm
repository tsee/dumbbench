package TryPackage;
use v5.10;

sub get_subs_to_benchmark {
	qw(
	file_find
	file_find_rule
	path_class_iterator
	path_iterator_rule
	path_class_rule
	file_find_parallel
	file_find_node
	file_next
	file_find_iterator
	);
	qw(
	preincrement
	postincrement
	addition
	);
	qw(
	sleep1
	sleep2
	sleep3
	);
	}

# http://rjbs.manxome.org/rubric/entry/1981

sub sleep1 { sleep 1 }
sub sleep2 { sleep 2 }
sub sleep3 { sleep 3 }

sub preincrement {
	state $i = 0;
	++$i;
	}

sub postincrement {
	state $i = 0;
	$i++;
	}

sub addition {
	state $i = 0;
	$i += 1;
	}
	
sub file_find {
	require File::Find;
	}
	
sub file_find_rule {
	require File::Find::Rule;
	}

sub path_class_iterator {
	require Path::Class::Iterator;
	}

sub path_iterator_rule {
	require Path::Iterator::Rule;
	}

sub path_class_rule {
	require Path::Class::Rule;
	}
	
sub file_find_parallel {
	require File::Find::Parallel;
	}

sub file_find_node {
	require File::Find::Node;
	}

sub file_next {
	require File::Next;
	}

sub file_find_iterator {
	require File::Find::Iterator;
	}
1;
