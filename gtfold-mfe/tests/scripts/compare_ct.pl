#!/usr/bin/perl 

use paul_specials;
use Error;
use Exception::Class('CompareCTException');

sub compare_ct_structures()
{
my $ref_filename=$_[0];
my $filename=$_[1];

open(REF, "< $ref_filename");
open(RNA, "< $filename");

#printf "opened files $ref_filename and $filename\n\n\n";

@ref_struct = read_struct_ct(*REF);
@struct = read_struct_ct(*RNA);

my $rlen = length($ref_struct[0]);
my $slen = length($struct[0]);
my $ref_seq = $ref_struct[0];
my $seq = $struct[0];

$ref_struct[0]=$rlen;
$struct[0]=$slen;

my $ref_dotb = table_to_bracket(\@ref_struct);
my $dotb = table_to_bracket(\@struct);

$dotb =~ s/\(/\{/g;
$dotb =~ s/\)/\}/g;

    $_ = $ref_seq;
    my $ref_nogaps = tr/\-//;
    $_ = $seq;
    my $nogaps = tr/\-//;


    if (($rlen-$ref_nogaps) != ($slen-$nogaps)){
	      CompareCTException->throw(error => "seq lengths aren't equal (reference = $rlen, prediction = $slen)!
$rlen-$ref_nogaps ne $slen-$nogaps
ref_nogaps = $ref_nogaps
nogaps     = $nogaps

>ref
$ref_seq
$ref_dotb
>str
$seq\n\n\n");
    }

#print ">ref1
#$ref_seq
#$ref_dotb
#>str1
#$seq
#$dotb\n\n\n";

#If different lengths, gap or delete as appropriate:
while ($rlen != $slen){
    
    for (my $i = 0; $i < length($ref_seq); $i++){
	if ( substr($ref_seq,$i,1) =~ '\-'){  
	    
	    if (substr($ref_dotb,$i,1)  =~ '\.' ){
		substr($ref_seq,$i,1) = "";
		substr($ref_dotb,$i,1) = "";
		$i--;
	    }
	    elsif ((substr($seq,$i,1) ne substr($ref_seq,$i,1)) && (substr($ref_dotb,$i,1)  ne '\.') ) {
		substr($seq,$i,0) = ".";
		substr($dotb,$i,0) = ".";
		
		substr($ref_seq,$i,1) = ".";
		
		
	    }
		}
    }
    
    
    for (my $i = 0; $i < length($seq); $i++){
	
	if ( substr($seq,$i,1) =~ '\-'){  
	    
	    if (substr($dotb,$i,1)  =~ '\.' ){
		substr($seq,$i,1) = "";
		substr($dotb,$i,1) = "";
		$i--;
	    }
	    elsif (substr($seq,$i,1) ne substr($ref_seq,$i,1) && (substr($dotb,$i,1)  ne '\.')) {
		substr($ref_seq,$i,0) = ".";
		substr($ref_dotb,$i,0) = ".";
		substr($seq,$i,1) = ".";
		
	    }
	}
	
    }
#print ">ref
#$ref_seq
#$ref_dotb
#>str
#$seq
#$dotb\n\n";
    @ref_struct = make_pair_table($ref_dotb); 
    @struct = make_pair_table($dotb);
    
    #Update lengths after gapping
    $rlen = length($ref_seq);
    $slen = length($seq);
    
}



#print ">ref
#$ref_seq
#$ref_dotb
#>str
#$seq\n";



my $rcount = 0;
my $scount = 0; 
my $true_pos = 0; 
my $true_neg = 0; 
my $false_neg = 0; 
my $false_pos = 0;
my $conflict = 0;
my $contradict = 0;
my $temp = 0;

for (my $i=1; $i<=$rlen; $i++){
    
    #printf "%6d %6d\n", $ref_struct[$i], $struct[$i];

    if ($ref_struct[$i]>0 && $ref_struct[$i]>$i){
	$rcount++;
	#print "$rcount: $i-$ref_struct[$i]\n";
    }
    
    if ($struct[$i]>0 && $struct[$i]>$i){
	$scount++;
    }

    if (($ref_struct[$i]==$struct[$i]) && $ref_struct[$i]>0 && $ref_struct[$i]>$i){
	#printf "%6d %6d\n", $ref_struct[$i], $struct[$i];
	$true_pos++;
	$temp = $struct[$i];
	substr($dotb,$i-1,1) = '(';
	substr($dotb,$temp-1,1) = ')';
    }
    elsif (($ref_struct[$i]!=$struct[$i]) && $struct[$i]>0 && $struct[$i]>$i){
      
      #print "struct: $i . $struct[$i]\n";
      
      $prime5 = $i;
      $prime3 = $struct[$i];
      
      if ($ref_struct[$prime3]>0 || $ref_struct[$prime5]>0){
	#print "   ref: $ref_struct[$prime3] . $ref_struct[$ref_struct[$prime3]] : $ref_struct[$prime5] . $ref_struct[$ref_struct[$prime5]]\n";
	$contradict++;
	
	substr($dotb,$prime5-1,1) = '<';
	substr($dotb,$prime3-1,1) = '>';
	

      }
      else {
	#check nested!
	$j=$prime5;
	$b=1;
	while ($b && $j<$prime3 ) {
	  
	  if ( ($ref_struct[$j]>0 && $ref_struct[$j]<$prime5) || $ref_struct[$j]>$prime3 ) {
	    $b=0;
	    $conflict++;
	    #print "conflict $ref_struct[$j] . $j\n";
	    
	    substr($dotb,$prime5-1,1) = '[';
	    substr($dotb,$prime3-1,1) = ']';
	    
	  }
	  $j++;
	}

      }
      
      
    }
    
    for (my $j=$i+4; $j<=$rlen; $j++){
	
	my $x = substr($ref_seq,$i-1,1);
	my $y = substr($ref_seq,$j-1,1);
	
	if (ispair($x,$y) ){
	    $true_neg++;
	    #print "$x $i $y $j\n";
	}
	
    }
    

}


#$false_pos = $scount - $true_pos;
$false_pos = $conflict + $contradict;
$false_neg = $rcount - $true_pos;

$true_neg=$true_neg-$true_pos-$false_pos;

my $sensitivity = 0;
my $selectivity =0;
if ($rcount>0){
    $sensitivity = $true_pos/($false_neg + $true_pos); #$rcount;
}
if ($scount>0){
    $selectivity = $true_pos/($false_pos + $true_pos); #$scount;
}

my $approx_corr = ($sensitivity + $selectivity)/2;
my $N = $true_pos + $false_pos + $false_neg + $true_neg;

my $corr_coeff  = 0;
if ($true_pos>0){ 
$corr_coeff  = ($N*$sensitivity*$selectivity - $true_pos)/sqrt(($N*$sensitivity - $true_pos)*($N*$selectivity - $true_pos));
}


my $MCC  = 0;
my $MCCquotient = (($true_pos+$false_pos)*($true_pos+$false_neg)*($true_neg+$false_pos)*($true_neg+$false_neg));

if ($MCCquotient>0){
$MCC = ($true_pos*$true_neg - $false_pos*$false_neg)/sqrt( $MCCquotient  );
}

$old_false_pos = $scount - $true_pos;
$compatable = $old_false_pos - $false_pos;

#print ">ref
#$ref_seq
#$ref_dotb
#>str
#$seq\n";
#print "$dotb\n";

my $comparison_result = sprintf("
seq length =         %6d
num of bps in ref =  %6d 
num of bps in sub =  %6d
Basepair distance =  %6d
true positives =     %6d
true negatives =     %6d
false positive =     %6d 
\t contradict = $contradict
\t conflict   = $conflict 
\t compatable = $compatable
false negative =     %6d
sensitivity =        %1.3f
selectivity =        %1.3f
Approximate correlation = %1.3f
Correlation Coefficient = %1.3f 
Matthews Corr. Coeff.   = %1.3f 

\n\n", $rlen, $rcount, $scount, $false_pos+$false_neg+$compatable, $true_pos, $true_neg, $false_pos, $false_neg, $sensitivity, $selectivity, $approx_corr, $corr_coeff, $MCC);

my $latex_comparison_result = sprintf("LaTeX:
Subj. File & BPs in Ref. & BPs in Subj. & TPs (sens.)& FPs (select.) & Matthews Corr. Coeff. (approx. corr.) & \\\\
$filename & %d & %d & %d (%2.1f) & %d (%2.1f) & %1.3f (%2.1f) \\\\ \n\n", 
$rcount, $scount, $true_pos,  $sensitivity*100, $false_pos, $selectivity*100, $MCC, $approx_corr*100);

#printf "%1.4f\t%1.4f\n",
#$sensitivity, $selectivity;

  return ($sensitivity, $selectivity, $comparison_result, $latex_comparison_result);
}

sub read_struct_ct{

$fileptr = $_[0];
my $seq = "";

my $i=-1;
while ( <$fileptr> ){

    @F = split;

    #if ((/ = /) && ($#F!=5)) {
    #    next;
    #}
    
    if ($i>=0){
    
    $seq .= $F[1];
    $table[$i] = $F[4];
}
    $i++;

    #if ($F[4]==0) {$s .= "."; next}
    #$s .= "(" if ($F[0]<$F[4]);
    #$s .= ")" if ($F[0]>$F[4]);
}


  $seq  =~ tr/a-z/A-Z/;
#print "2: $seq\n\n";

return ($seq, @table);

}

sub ispair{
    my ($x, $y) = @_;
    
    if ( ($x eq 'A' && $y eq 'U')||($x eq 'U' && $y eq 'A') ) {
	
	return 1;
    }
    elsif ( ($x eq 'G' && $y eq 'C')||($x eq 'C' && $y eq 'G') ) {
	
	return 1;
    }
    elsif ( ($x eq 'G' && $y eq 'U')||($x eq 'U' && $y eq 'G') ) {
	
	return 1;
    }
    
    else {
	return 0;
    }
}

# End of file
1;
