#!/usr/bin/perl

use strict;
use warnings;

#
## main begin
#

my $file = shift;

&parse_result($file);



##################################################################################
# Subroutine : parse_result
# Despcription : parse result from tblastn
# Params: tblastn results file, 
# Return: array, contains the hits information (the first array element is the
# 		   result count, and the rest array element are hash maps that each hash 
#         map contains the hit's name, start poistion, end postion)
#################################################################################

sub parse_result() {
	my ($file_name) = @_;
	open RES, $file_name or die $!;
	
	# hash table key
	my $hit_name = "name";
	my $hit_start = "start";
	my $hit_end = "end";

	# used to record the pointer of the file, and then we can back to the specify position
	my $file_position_prev = 0; 
	my $file_position_cur = 0;

	# array contains the result hits
	my $result_count = 0;
	my @results = ();

	my $line;
	while($line = <RES>) {
		chomp $line;
		#print "file position(outer): ".tell(RES)."\n";

		#
		## ***** No hits found *****
		## if there's no hits found 
		#
		print "No results\n" if $line =~ /\*\*\*\*\*/;
		
		#
		## deal with found results
		#

		# arrays holding the reulst, 
		# hit[0]: hit's name, hit[1]: hit's start position
		# hit[2]: hit's end poistion
		my %hit = (); 
		if ($line =~ />/) {
			$result_count++;

			# query name
			# >chr10_GL383545v1_alt
			my ($name) = $line =~ />(.+)/;
			$hit{$hit_name} = $name; 
			
			while(my $res = <RES>) {
				chomp $res;
				if($res =~ />/) {
					# if the hit's begining found, set the file pointer back one line
					$file_position_cur = tell(RES);
					seek(RES, $file_position_prev, 0);
					last;
				}

				# query location
				# Sbjct  34   DENRSDLQRQNHTFSLEFNKDTEIQYSSIAFP  129
				if($res =~ /^Sbjct/) {
					#print "$res\n";
					my ($start, $end) = $res =~ /^Sbjct\s+(\d+)\s+\w+\s+(\d+)$/;
					$hit{$hit_start} = $start;
					$hit{$hit_end} = $end;
					push @results, {%hit}; # push this hit into results
				}

				# record the previous file pointer, so we can set the file pointer back one line
				# if the hit's begining found
				$file_position_prev = tell(RES);
			}
		}
	}
	close RES;

	# put the result count into the array
	unshift @results, $result_count;

=head
	# test the parsed result
	print "reulst count: $results[0]\n";
	for(my $index=1; $index<@results; $index++) {
		if(exists $results[$index]{$hit_end}) {  
			print "name: $results[$index]{$hit_name}\tstart: $results[$index]{$hit_start}\tend: $results[$index]{$hit_end}\n";
		}
	}
=cut

	return @results;
}