#!/usr/bin/perl -w
use strict;
use CGI qw/:standard/;
use File::Copy;
my $tmp_dir = '/home/sunshine/KuaiPan/GraduatePaper/tmp';
my $BlastHead ="P2G: Powered by TBLASTN 2.2.30+\r\n\r\n\r\nResult lines begin:\r\n\r\n\r\n";


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

sub make_query_page{

	####----advanced search parameter

	my $evalue = textfield({'name'=>'evalue','size'=>7,'maxlength'=>10, 'value'=>0.001,
		'title'=>'Expected number of chance matches in a random model. By default 10.'
		});
	my $max_results = textfield({'name'=>'max_length','size'=>7,'maxlength'=>3, 'value'=>10,
		'title'=>'Maximum number of aligned sequences to display. By default 300.' 		
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
		'title'=>'Click the button will start the blast!'
		});
	my $reset_button = reset({'name'=>'reset','value'=>'Reset',
		'title'=>'Click the button will clear all your inputs!'
		});

	####----query table
	my $MainPanel= table(
            Tr([
                th(['Enter a set of peptide sequences in the text area below:']),
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
		
	my $query = div({'id'=>'content'},p({'class'=>'p3'},'The MimoBlast tool in the SAROTUP suite is designed to check if there are peptides in the MimoDB database that are identical or <b>similar</b> to the peptides user submitted. Highly similar peptides obtained with various targets might also be TUPs. Besides, peptides similar to a known TUP may also be TUPs. For example, SVSVGMNPSPRP is very likely to be a TUP because it is nearly identical to SVSVGMKPSPRP, a notorious TUP. If you got the former peptide, a BLAST against the MimoDB database would remind you it may be a TUP. Here we go!'), div({'id'=>'nb'}, $MainPanel));
		
	####-----query page

	my $start_form = start_multipart_form;
	my $end_form = endform;
	my $query_content = $start_form.$query.$end_form;

	####----make query page

	make_basic_page($query_content);
}

sub make_result_page{
	my $result_table;
	
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
		my $seqs = check_user_input($seq,$load_file);
	
		####----save_mimotopes to local PC
		my ($mimotop_tmp,$run_time)= save_mimotopes(@$seqs);
	
		####----run tblastn to get the result
		my ($result_file_name) = run_tblastn($mimotop_tmp,$run_time);
	
		####----parse the result file to get information
		my $final_result = parse_result($result_file_name,$seqs,$run_time);

		####----create the result table
		my $downfile = substr($result_file_name, 34);
		my $downlink = a({'-href'=>"../temp/$downfile.gz",'Title'=>'Download full blast result file','target'=>'_blank'},img({'src'=>'../image/download.gif','align'=>'absmiddle','hspace'=>'8'}));
		my $thead = th(['Your Query Peptide','Similar Peptide in MimoDB','Blast Report'.$downlink]);

		$result_table = div({'id'=>'content'},p({'class'=>'p3'},'The MimoBlast results are summarized in the table below. Move your mouse over the hyperlinked peptide sequences one by one, you can view aligment in pairs on the fly through the pop-up browser windows. You can also read the report file for each query sequence or download all the report in a compressed archive by click the corresponding links or icons.'), table(Tr($thead), @$final_result));
	}

	make_basic_page($result_table);
}

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
					li(a({'id'=>'current', 'href'=>'../cgi-bin/MimoBlast.pl',
						'title' =>'Find peptides similar to yours in the MimoDB database!'},'MimoBlast')),
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

sub check_user_input{

	my ($SeqsData,$UserSideFile) = @_;
	my $RawSeq;

	if ( ($SeqsData eq '') and ($UserSideFile eq '') ){
		make_error_page("<b>sequence input error!</b> No sequence is input, or no sequence file is uploaded. Please enter or paste peptides into the text area in FASTA or raw sequence format. Alternatively, upload a file in FASTA or raw sequence format.");
	}

	if ( ($SeqsData ne '') and ($UserSideFile ne '') ){
		make_error_page("<b>sequence input error!</b> Sequence overloaded! You can either enter a set of peptide sequences into the text area or upload a file in FASTA or raw sequence format. Do not submit sequences through the text area and the file box simultaneously.");
	}

	if ( ($SeqsData ne '') and ($UserSideFile eq '') ){
		my @lines = split /^/, $SeqsData;
		$RawSeq = checkFileFormat( (\@lines) );
	}

	if ( $UserSideFile ne '' and ($SeqsData eq '') ){
		my $ServerSideFile = tmpFileName($UserSideFile);
		open(fhSEQ,$ServerSideFile);
		my @lines = <fhSEQ>;
		$RawSeq = checkFileFormat( (\@lines) );
	}

	return unique(@$RawSeq);
}

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

			if (length($RawSeqLine) < 3 or length($RawSeqLine) > 40){
				make_error_page("<b>unsupported sequence length!</b> Pay attention to <b>$line!</b>. The MimoBlast tool accepts peptide sequence at least with 3 residues and no longer than 40 residues, as all peptides in the MimoDB database is 3-40 residues long.");}

			push @$RawSeq, $RawSeqLine;
		}
	}
	return $RawSeq;
}


sub run_tblastn{
	####----get the mimotope array from make_result_page subrutine
	
		my ($query_seq, $run_time) = @_;
	
	####----parameters for advanced search

		my $e_value = param('evalue');
		my $max_result = param('max_length');
		my $short_tblastn = param('short_default');
	
	####----tblastn direction
	
		my $blast_dir = "/home/sunshine/ncbi-blast-2.2.30+/bin";
		my $tblastn_dir = "$blast_dir/tblastn";
	
	####----outfile name
		
		my $out_file_name = "$tmp_dir/MimoBlastResult".$run_time.".all";
	
	####----the database name
		
		my $db_name = "/home/sunshine/Downloads/chroms/blast_db_hg38/hg_merge_blast_db_1";

	####----create tblastn function

		my $tblastn = "$tblastn_dir -query $query_seq -db $db_name -out $out_file_name";

	####----check the advanced search parameter value
		
		if ($short_tblastn) {
			$tblastn .= ' -task tblastn-short -word_size 2 -seg no -evalue 20000 -matrix PAM30 -gapopen 9 -gapextend 1'; 
		}
		else{
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
		}
		else {
			$tblastn .= ' -max_target_seqs 300';
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

sub parse_result{
	####----blast output file name and query sequences and timestamp as input
	my ($file_name,$mimotopes,$run_time) = @_;
	
	####----@final_result for saving all query sequences; @mimo_result for saving each query sequence
	my (@final_result,@mimo_result);
	
	####----open the output file 
	open RESULT,$file_name or die(make_error_page($!));

	####----$count for each result file name 
	####----$open_result is a switch for opennig one file to print result into it 
	####----$print_on is a switch for print or not
	####----$turn is a switch for beginning a new @mimo_result
	my $count = 1;
	my $open_result = 0;
	my $print_on = 0; 
	my $turn = 0;

	####----parse the output file
	while (defined(my $line = <RESULT>)) {

		####----each query sequence begin with a 'Query='
		if ($line =~ /^Query=/) {
			$print_on = 1;
			$open_result = 1;
		}
		my $result_name = "Report ".$count;
		my $local_result_name = "MimoBlastResult".$run_time.'.part'.$count;
			open ONE,">$tmp_dir/$local_result_name" or die(make_error_page($!)) if $open_result;
			if ($open_result == 1) {
				print ONE $BlastHead; #print the report head
				$open_result = 0;
			}
			if ($print_on == 1) {
				print ONE $line;
			}

			####----each query sequence end with 'Effective search space used:'
			if ($line =~ /^Effective search space used:/) {
				$print_on = 0;
				$turn = 1;
				close ONE;
				$count++;
			}

			####----get the MimoID
			if ( $line =~ /^> (Mimoset ID: \d+; Peptide \d+-?\d?: \w+)/ ) {
				$line = $1;
				my $similar;
				if ($mimo_result[-1]) {
					my $num = 0;
					while ($num <= $#mimo_result) {
						if ($line eq $mimo_result[$num]) {
							$similar = 0;
							last;
						}
						else {
							$similar = 1;
						}
						$num++;
					}
					if ($similar == 1) {
						push (@mimo_result,$line);
					}
				}
				else {push @mimo_result,$line;}
			}

			####----get the information from @mimo_result and value it as ''
			if ($print_on == 0 and $open_result == 0 and $turn == 1 ) {
				my $result_file = a({'-href'=>"./MimoBlast.pl?File=$local_result_name",'Title'=>'View it','target'=>'_blank'},$result_name."&nbsp;&nbsp;". img({'src'=>'../image/viewer.gif', 'align'=>'absmiddle'}));

				####----if no subject is found ,the MimoID will be 'No hits found'
				if (!$mimo_result[-1]) {
					push @mimo_result,td("No hits found!");
					my $return_result = Tr(td(shift(@$mimotopes)),$mimo_result[-1],td($result_file));
					push @final_result,$return_result;
				}
				else {
					my $j = 0;
					while ($j <= $#mimo_result) {
						if ($mimo_result[$j] =~ /Mimoset ID: (\d+); Peptide \d+-?\d?: (\w+)/ ) {
							$mimo_result[$j] = td(a({-href=>"javascript:void(0)",onmouseover=>"openwin(\"$local_result_name\",\"$1\",\"$2\")"},$2)." in mimoset: ". a({'href'=>"http://i.uestc.edu.cn/mimodb/browse.php?table=mimoset&ID=$1",'Title'=>'Visit it','target'=>'_blank'},$1));
						}
						$j++;
					}
					my $rowspan = scalar(@mimo_result);
					my $return_result = Tr(td({'rowspan'=>"$rowspan"},shift(@$mimotopes)),shift(@mimo_result),td({'rowspan'=>"$rowspan"},$result_file),Tr([@mimo_result]));
					push @final_result,$return_result;
				}	
				@mimo_result = qw//;
				$turn = 0;
			}
		}

	####----close the output filehandle and return the @final_result

		close RESULT;
		return \@final_result;

	####----parse_result end
}

#Delete redundant sequence added by Jian Huang 2011-8-15
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

sub save_mimotopes{
	####----parameter: @sequences pass the checking
	my (@seqs) = @_;
	
	####----make tempfile unique
	srand(time);
	my $run_time =time.int rand(1000);
			
	####----the local direction for saving the mimotope file 
	my $tmp_mimotopes = "$tmp_dir/MimoBlast_InFile".$run_time.".fa";
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
