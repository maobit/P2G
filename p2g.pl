#!/usr/bin/perl -w
use strict;
use CGI qw/:standard/;
use File::Copy;
my $tmp_dir = '/home/sunshine/KuaiPan/GraduatePaper/tmp';
my $BlastHead ="P2G: Powered by TBLASTN 2.2.30+\r\n\r\n\r\nResult lines begin:\r\n\r\n\r\n";
my $GBrowse_URL = "http://www.heqiang.com/cgi-bin/gb2/gbrowse/hg19/";


#########################
# Main Programme Start
#########################

	if (not param) {
		make_query_page();
	}
	else {
		make_result_page();
	}


#########################
# Subroutines start
#########################


##################################################################################
# Subroutine  : make_query_page
# Description : P2G's default page, the query page. Using CGI module to display 
# 				a textarea for the input of query sequence, it also accepts a 
#				fasta format file; there are also other options you can set to 
#				custom the TBLASTN's parameters, such as expect value, max
#				results number.
# Params      : void
# Return 	  : void
# Created 	  : ????
# Modified 	  : 2015-3-31 by Qiang He
#################################################################################

sub make_query_page{

	####----advanced search parameter

	my $evalue = textfield({'name'=>'evalue','size'=>7,'maxlength'=>10, 'value'=>0.001,
		'title'=>'Expected number of chance matches in a random model. By default 10.'
		});
	my $max_results = textfield({'name'=>'max_length','size'=>7,'maxlength'=>3, 'value'=>10,
		'title'=>'Maximum number of aligned sequences to display. By default 10.' 		
		});
	my $tblastn_short = checkbox_group({'name'=>'short_default', 
		'values'=>'Optimized parameters for short peptide (<15 residues)',
		'title'=>'Word size 2, no SEG, PAM30, gap open 9, gap extension 1, evalue 20000!',
		onchange=>"ShortChecked();"
		});

	####----default search parameter
	my $user_seq = textarea({'name'=>'mimotope','cols'=>'48','rows'=>'8',
		'title'=>'Input or paste your peptides here in FASTA or raw sequence format!'
		});
	my $user_upload = filefield({'id'=>'upload_button','name'=>'upload_file','size'=>20,
		'title'=>'Select and upload your peptide sequence file in FASTA or raw sequence format!'
		});

	my $example_button = button({'name'=>'', 'value'=>'Example',
		'title'=>'Click the button to load the example data!',
		onclick=>"ExampleMimoBlast();"});
	my $submit_button = submit({'id'=>'submit_button','name'=>'submit','value'=>'BLAST',
		'title'=>'Click the button to start!'
		});
	my $reset_button = reset({'name'=>'reset','value'=>'Reset',
		'title'=>'Click the button will clear all your inputs!'
		});

	####----query table
	my $MainPanel= table(
            Tr([
                th(['Enter a peptide sequence in the text area below:']),
                td([$user_seq]),
                td(['<b>Or upload a sequence file: </b>'.$user_upload]),
                td(['&nbsp;']),
				th(['Expect value: '.$evalue.'&nbsp;&nbsp;&nbsp;&nbsp;Max results: '.$max_results]),
                th([$tblastn_short]),
                td(['&nbsp;']),
				td([$example_button.'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'.$reset_button.
					'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'.$submit_button]),
            ]),
		);
		
	my $query = div({'id'=>'content'},p({'class'=>'p3'},'P2G is a web service that accepts <b>peptide</b> as input, and it locates the peptide in <b>Genome</b>. It uses <b>TBLASTN</b> to search the Human Genome database and then uses <b>GBrowse</b> to display the results visually. Here we go!'), div({'id'=>'nb'}, $MainPanel));

	####-----query page

	my $start_form = start_multipart_form;
	my $end_form = endform;
	my $query_content = $start_form.$query.$end_form;

	####----make query page

	make_basic_page($query_content);
}

###############################################################################
# Subroutines : make_result_page
# Description : Display the result of TBLASTN: if there is no hit at all,
#               display no hits found; if there is only one hit found, 
#               navigate to the GBrowse page using the hit's properties
#				(sequence name, start position, end position); if there are 
#				more than one hit, make a table display the hits, including 
#				the sequence name, start positon, end position and frame.
# Params 	  : void
# Return 	  : void
# Created 	  : ????
# Modified    : 2015-3-31 by Qiang He
###############################################################################

sub make_result_page{
	my $result_table;
	
	## present tblastn's report 
	my ($report) = url_param('File');
	if ($report) {
		my $what;
		my $where = $tmp_dir."/$report";

		open REPORT,$where or die(make_error_page($!));
		while (defined(my $line = <REPORT>)) {$what.= $line;}
		$result_table= div({'id'=>'content'},pre($what));
	}

	else{
		####----get user input or upload mimotopes
		my $seq = param('mimotope');
		my $load_file = upload('upload_file');

		####----check user input, get unique seqs
		my $seqs = check_user_input($seq, $load_file);
	
		####----save_mimotopes to server's tmp dir
		my ($mimotop_tmp, $run_time) = save_mimotopes(@$seqs);
	
		####----run tblastn to get the result
		my ($result_file_name) = run_tblastn($mimotop_tmp, $run_time);
	
		####----parse the result file to get information
		my $result = parse_result($result_file_name, $seqs, $run_time);
		my @row_result = @$result;

		####----create the result table
		# hash table key
		my $hit_name = "name";
		my $hit_start = "start";
		my $hit_end = "end";
		my $hit_frame = "frame";
		my $hit_query = "query";
		# Table header
		my $thead = th(['Matched Chromosome','Your Query Peptide', 'Frame', 'Start Postion', 'End Postion']);

		my (@name, @query_seq, @frame, @start, @end);
		my @final_result = ();

		# Create table for each hit
		my $i;
		for($i=1; $i<$row_result[0]+1; $i++) {
			push @name, $row_result[$i]{$hit_name};
			push @query_seq, $row_result[$i]{$hit_query};
			push @frame, $row_result[$i]{$hit_frame};
			push @start, $row_result[$i]{$hit_start};
			push @end, $row_result[$i]{$hit_end};
			#my $row_result = Tr([td([$row_result[$i]{$hit_name}, $row_result[$i]{$hit_query}, $row_result[$i]{$hit_frame}, $row_result[$i]{$hit_start}, $row_result[$i]{$hit_end}])]);
			my $row_result = Tr([td([a({'href'=> $GBrowse_URL."?q=$row_result[$i]{$hit_name}:$row_result[$i]{$hit_start}..$row_result[$i]{$hit_end}"},$row_result[$i]{$hit_name}), $row_result[$i]{$hit_query}, $row_result[$i]{$hit_frame}, $row_result[$i]{$hit_start}, $row_result[$i]{$hit_end}])]);
			push @final_result, $row_result;
		}

		$result_table = div({'id'=>'content'},p({'class'=>'p3'},'The MimoBlast results are summarized in the table below. Move your mouse over the hyperlinked peptide sequences one by one, you can view aligment in pairs on the fly through the pop-up browser windows. You can also read the report file for each query sequence or download all the report in a compressed archive by click the corresponding links or icons.'),  table(Tr($thead), @final_result));
	}

	make_basic_page($result_table);
}

#######################################################################################
# Subroutines : make_basic_page
# Description : The basic page of P2G, alse called template page. It provides basic 
#				layouts of the html component, you can insert your content into this
#				page, and this page changed dynamicly.
# Params      : $content, the content you want to insert.	
# Return 	  : void
# Created     : ????
######################################################################################

sub make_basic_page{	

	my($content) = @_;

	####----create the basic page

		print header;
		print start_html(
			-title=>'P2G',
			-style=>{'src'=>'../css/sarotup.css'},
			-script=>{
				'language'=>'javascript',
				'src'=>'../css/sarotup.js'
			}
		);

		print div({'id'=>'header'},p('P2G: Protein to Genome Browser'));

		print div({'id'=>'separator'},
			start_form({'method'=>'get','action'=>'http://www.google.com/search','target'=>'_blank'}),
			p(hidden({'name'=>'as_sitesearch','value'=>'immunet.cn'}),
			textfield({-name=>'as_q',-size=>20,-value=>'Search HLAB',-onclick=>"document.forms[0].as_q.value=''"})),
			end_form()
			);

		print div({'id'=>'container'},
			  div({'id'=>'lefter'},
				ul(
					li(a({'href'=>'../index.html'},'Home')),
					li(a({'href'=>'../cgi-bin/TUPScan.pl', 
						'title' =>'Find peptides with known TUP motifs in your query sequences!'},'TUPScan')),
                                        li(a({'href'=>'../TUPredict.html',
						'title' =>'Predict TUPs using machine learning methods!'},'TUPredict')),
					li(a({'href'=>'../cgi-bin/MimoScan.pl',
						'title' =>'Find peptides with your query patterns in the MimoDB database!'},'MimoScan')),
					li(a({'href'=>'./MimoSearch.pl',
						'title' =>'Find peptides identical to yours in the MimoDB database!'},'MimoSearch')),
					li(a({'id'=>'current', 'href'=>'../cgi-bin/p2g.pl',
						'title' =>'Peptide to Genome'},'P2G')),
					li(a({'href'=>'../citation.html'},'Citation')),
					li(a({'href'=>'../help.html#MimoBlast'},'Help'))
					),
				),

				div({'id'=>'middler'},br(),$content),

			  );

		print div({'id'=>'footer'},
			p(b(a({'title'=>"Dr. Huang's LAB",'href'=>"http://i.uestc.edu.cn/hlab",'target'=>'_blank'},'HLAB'),'|',a({'title'=>'Our COBI','href'=>"http://cobi.uestc.edu.cn",'target'=>'_blank'},'Center of Bioibformatics'),'|',a({'title'=>'Key Laboratory for NeuroInformation of Ministry of Education','href'=>"http://www.neuro.uestc.edu.cn"},'KLNME'),'|',a({'title'=>'University of Electronic Science and Technology of China','href'=>"http://www.uestc.edu.cn",'target'=>'_blank'},'UESTC'),'|','Chengdu, 610054, China&nbsp;&nbsp;&nbsp','[',a({'href'=>"mailto:hj\@uestc.edu.cn"},'Feedback'),']'))	
		);
		print end_html;
		exit;

	####----make_basic_ page end
}

sub make_error_page{
	####----say errors
		my($error)=@_;
		my $message = p({'class'=>'p3'},'<b>ERROR: </b>'.$error,br,br);
		my $error_image = p({'align'=>'center'},img({'src'=>"../image/error.png"}));
		my $result_error = div({'id'=>'content'}, $message, $error_image);
	
	####----create error page
		
		make_basic_page($result_error);

	####----make_error_page end
}

####################################################################################
# Subroutine  : check_user_input
# Description : Check user's input, it won't run TBLASTN and make error page if
#				the user's input exists any error.
#				Errors to be checked: 1, There are no peptides in text area and
#				also no uploaded file; 2, There are peptides in text area and also 
#				uploaded file; 3, sequence format error
# Params      : $SeqsData, sequence data in text area 
#				$UserSideFile, uploaded sequence data file
# Return 	  : unique(@$RawSeq), proccessed sequences; unique sequences, no fromat 
#				error and without blank line
# Created 	  : ????
####################################################################################

sub check_user_input{

	my ($SeqsData , $UserSideFile) = @_;
	my $RawSeq;

	# Condition 1: there is no input at all, neither textarea nor upload file
	if ( ($SeqsData eq '') and ($UserSideFile eq '') ){
		make_error_page("<b>sequence input error!</b> No sequence is input, or no sequence file is uploaded. Please enter or paste peptides into the text area in FASTA or raw sequence format. Alternatively, upload a file in FASTA or raw sequence format.");
	}

	# Condition 2: overloaded inputs, there are peptides in text area and also upload file
	if ( ($SeqsData ne '') and ($UserSideFile ne '') ){
		make_error_page("<b>sequence input error!</b> Sequence overloaded! You can either enter a set of peptide sequences into the text area or upload a file in FASTA or raw sequence format. Do not submit sequences through the text area and the file box simultaneously.");
	}

	# Condtion 3: peptides only exits in text area
	if ( ($SeqsData ne '') and ($UserSideFile eq '') ){
		my @lines = split /^/, $SeqsData;
		$RawSeq = checkFileFormat( (\@lines) );
	}

	# Condition 4: peptides only exits in upload file
	if ( $UserSideFile ne '' and ($SeqsData eq '') ){
		my $ServerSideFile = tmpFileName($UserSideFile);
		open(fhSEQ,$ServerSideFile);
		my @lines = <fhSEQ>;
		$RawSeq = checkFileFormat( (\@lines) );
	}

	return unique(@$RawSeq);
}

########################################################################################
# Subroutine  : checkFileFormat
# Description : Check the format of user's input
# Params      : All lines of user's input, it won't run TBLASTN and make error page if
#				there is any format error
# Return 	  : $RawSeq, processed sequences without fasta annotation and blank line
# Created	  : ????
########################################################################################

sub checkFileFormat{
	my($lines) = @_;
	my $RawSeq;

	foreach my $line(@$lines){
		# skip fasta annotation line
		if ($line =~ /^\>/){
			next;
		}
		# skip blank line
		elsif ($line =~/^\s*$/) {
			next;
		}
		else{
			my $RawSeqLine = uc(trim($line)); 
			if ($RawSeqLine =~ /[^ACDEFGHIKLMNPQRSTVWY]/){
				make_error_page("<b>unsupported file format or residue abbreviation!</b> Pay attention to <b>$line!</b>. At present, the MimoBlast tool only supports sequence in FASTA or raw format. Besides, only the standard IUPAC one-letter codes for the amino acids ( <i> i.e.</i> A, C, D, E, F, G, H, I, K, L, M, N, P, Q, R, S, T, V, W, Y) are supported.");} 

			if (length($RawSeqLine) < 3 or length($RawSeqLine) > 150){
				make_error_page("<b>unsupported sequence length!</b> Pay attention to <b>$line!</b>. The MimoBlast tool accepts peptide sequence at least with 3 residues and no longer than 40 residues, as all peptides in the MimoDB database is 3-40 residues long.");}

			push @$RawSeq, $RawSeqLine;
		}
	}
	return $RawSeq;
}


####################################################################################
# Subroutine  : run_blastn
# Description : Using system command to run TBLASTN.
# Params      : $query_seq, query sequence from the textarea or user upload file
#				$run_time, 
# Return 	  : 
# Created 	  : ????
####################################################################################

sub run_tblastn{
	####----get the mimotope array from make_result_page subroutine
	my ($query_seq, $run_time) = @_;
	
	####----parameters for advanced search
	my $e_value = param('evalue');
	my $max_result = param('max_length');
	my $short_tblastn = param('short_default');
	
	####----tblastn directory
	my $blast_dir = "/home/sunshine/ncbi-blast-2.2.30+/bin";
	my $tblastn_dir = "$blast_dir/tblastn";
	
	####----outfile name
	my $out_file_name = "$tmp_dir/P2GResult_".$run_time.".all";
	
	####----the database name
	my $db_name = "/home/sunshine/Downloads/chroms/blast_db_hg38/hg_merge_blast_db_5";

	####----create tblastn function
	my $tblastn = "$tblastn_dir -query $query_seq -db $db_name -out $out_file_name";

	####----check the advanced search parameter value
	if ($short_tblastn) {
		$tblastn .= ' -task tblastn-short -word_size 2 -seg no -evalue 20000 -matrix PAM30 -gapopen 9 -gapextend 1'; 
	} else{
		#$tblastn .= ' -task tblastn -word_size 3 -seg yes -matrix BLOSUM62 -gapopen 11 -gapextend 1';
		if ($e_value) {
			$tblastn .= ' -evalue '.$e_value;
		}
		else {
			$tblastn .= ' -evalue 0.001';
		}	
	}
	if ($max_result) {
		$tblastn .= ' -max_target_seqs '.$max_result;
	} else {
		$tblastn .= ' -max_target_seqs 10';
	}
	
	####----run tblastn
	my $system_check = system($tblastn);

	####----check if the output file exists
	if (-e $out_file_name) {
		my $downfile = $out_file_name.".gz";			
		`gzip -c9 $out_file_name > $downfile`;
		return ($out_file_name);
	}
	else {
		make_error_page('<b>blast error!</b> Blast report file does not exist. Please tell us the problem through the <a href="http://i.uestc.edu.cn/mimodb/feedback.php" >Feedback</a> link on the left menu bar. We will solve it as soon as possible. Thank you very much!');
	}

	####----run_tblastn end
}

######################################################################################
# Subroutine   : parse_result														 #
# Despcription : parse result from tblastn											 #
# Params       : tblastn results file, 												 #
# Return       : array, contains the hits information (the first array element is    #
# 		   		 the result count, and the rest array element are hash maps that     #
#          		 each hash map contains the hit's name, start poistion, end postion) #
# Created      : 2015-3-31 by Qiang He 												 #
######################################################################################

sub parse_result() {
	my ($file_name, $mimotopes, $run_time) = @_;
	open RES, $file_name or die(make_error_page($!));
	
	# hash table key
	my $hit_name = "name";
	my $hit_start = "start";
	my $hit_end = "end";
	my $hit_frame = "frame";
	my $hit_query = "query";

	# used to record the pointer of the file, and then we can back to the specify position
	my $file_position_prev = 0; 
	my $file_position_cur = 0;

	# array contains the result hits
	my $result_count = 0;
	my @results = ();

	my $line;
	while($line = <RES>) {
		chomp $line;

		# hash holding the reulst, 
		# hit[0]: hit's name, hit[1]: hit's start position
		# hit[2]: hit's end poistion
		my %hit = (); 
		if ($line =~ />/) {
			$result_count++;

			# query name
			# >chr10_GL383545v1_alt
			my ($name) = $line =~ />(.+)/;
			$hit{$hit_name} = trim($name); 
			
			while(my $res = <RES>) {
				chomp $res;
				if($res =~ />/) {
					# if the hit's begining found, set the file pointer back one line
					$file_position_cur = tell(RES);
					seek(RES, $file_position_prev, 0);
					last;
				} 	# end if

				# query sequence
				# Query  1    DENRSDLQRQNHTFSLEFNKDTEIQYSSIAFP  32
				if($res =~ /^Query\s+\d+/) {
					my ($query) = $res =~ /^Query\s+\d+\s+(\w+)\s+\d+/;
					foreach my $user_query (@$mimotopes) {
						if($query =~ /$user_query/i) {
							$hit{$hit_query} = $user_query;
						}
					}
				} 

				# query frame
				# Frame = +1
				if($res =~ /\s+Frame/) {
					my ($frame) =  $res =~ /\s+Frame\s+=\s+([+-]\d)/;
					$hit{$hit_frame} = $frame;
				}

				# query location
				# Sbjct  34   DENRSDLQRQNHTFSLEFNKDTEIQYSSIAFP  129
				if($res =~ /^Sbjct/) {
					my ($start, $end) = $res =~ /^Sbjct\s+(\d+)\s+\w+\s+(\d+)$/;
					$hit{$hit_start} = $start;
					$hit{$hit_end} = $end;
					push @results, {%hit}; # push this hit into results
				}  # end if

				# record the previous file pointer, so we can set the file pointer back one line
				# if the hit's begining found
				$file_position_prev = tell(RES);
			}   # end while
		}  # end if
	}  # end while
	close RES;

	# put the result count into the array
	unshift @results, $result_count;

	return \@results;
}  # end subroutine parse_result

##############################################################################
# Subroutine  : unique
# Description : Delete redundant sequence
# Params      : @RawSeq, sequences proccessed by subroutine checkFileFormat
# Return      : $filtered, unique sequences
# Created 	  : 2011-8-15 by Jian Huang
##############################################################################

sub unique {
    my @RawSeq = @_;
	my $filtered;
	my %seen = ();

	foreach my $line(@RawSeq) {
		next if $seen {$line}++;
		push @$filtered,$line;
	}
	return $filtered;
}

#############################################################################
# Subtoutine  : save_mimotopes
# Description : Saving sequences into server's tmp dir, so that we can use 
#				it to run TBLASTN.
# Params      : @seqs, sequences processed by checkFileFormat and unique
# Return 	  : $tmp_mimotopes, file contains query sequence; 
#				$run_time, running time of this TBLASTN job
# Created     : ????
# Modified 	  : 2015-3-31 by Qiang He
#				Change the run time to be understandable.
#############################################################################

sub save_mimotopes{
	####----parameter: @sequences pass the checking
	my (@seqs) = @_;
	
	####----make tempfile unique
	# use the localtime add a random number less than 1000 to generate run time
	srand(time);
	my $rand_number = int rand(1000);
	my ($sec,$min,$hour,$day,$mon,$year,$wday,$yday,$isdst)=localtime(time());
	my $year_real = $year + 1900;
	my $month_real = $mon + 1;
	my $run_time = "$year_real\_$month_real\_$day\_$hour\_$min\_$sec\_$rand_number";

	####----the local direction for saving the mimotope file 
	my $tmp_mimotopes = "$tmp_dir/P2G_In_".$run_time.".fa";
	open FILE,">$tmp_mimotopes" or make_error_page($!." hello");

	foreach my $seq (@seqs) {
		print FILE ">"."\n";
		print FILE $seq."\n";
	}
	close FILE;
	
	return ($tmp_mimotopes,$run_time);
}

sub trim {
    my @out = @_;
    for (@out) {
        s/^\s+//g;          # trim left
		s/\s+//g;			# trim middle
        s/\s+$//g;          # trim right
    }
    return @out == 1 
              ? $out[0]		# only one to return
              : @out;		# or many
}
