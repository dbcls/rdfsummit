#!/usr/bin/env perl

=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

# Script to dump Ensembl triples. It was lashed together rapidly, and could stand to use a library for the writing of triples, with accommodation for the scale of the data involved.
# Requires installation of Ensembl Core and Compara APIs, as well as dependencies such as BioPerl


use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::DBSQL::DBAdaptor;


# Choice of database host is a factor in how fast the script runs. Try to find your nearest mirror, and check the database version before running.
Bio::EnsEMBL::Registry->load_registry_from_db(
  -host => 'useastdb.ensembl.org',
  -port => 5306,
  -user => 'anonymous',
  -db_version => 75,
  -no_cache => 1,
);


my %prefix = (
  base => 'http://rdf.ebi.ac.uk/resource/ensembl/',
  term => 'http://rdf.ebi.ac.uk/terms/ensembl/',
  rdfs => 'http://www.w3.org/2000/01/rdf-schema#',
  sio => 'http://semanticscience.org/resource/',
  dc => 'http://purl.org/dc/terms/',
  rdf => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
  faldo => 'http://biohackathon.org/resource/faldo#',
  skos => 'http://www.w3.org/2004/02/skos/core#',
  taxon => 'http://identifiers.org/taxonomy/',
);

foreach (keys %prefix) {
  triple('@prefix',$_.':',u($prefix{$_}) );
}
my $ga = Bio::EnsEMBL::Registry->get_adaptor('Human','Core','Gene');

my $genes = $ga->fetch_all;

my $count = 0;
while (my $gene = shift @$genes) {
  $count++;
  my @trans = @{$gene->get_all_Transcripts};

  triple(u($prefix{base}.$gene->stable_id), 'rdf:type','term:EnsemblGene' );
  dump_feature($gene);
  triple(u($prefix{base}.$gene->stable_id), 'rdfs:label', '"'.$gene->display_id.'"' );
  triple(u($prefix{base}.$gene->stable_id), 'dc:description', '"'.$gene->description.'"');
  triple(u($prefix{base}.$gene->stable_id), 'skos:altLabel', '"'.$gene->external_name.'"');
  
  my $meta = Bio::EnsEMBL::Registry->get_adaptor('Human','Core','MetaContainer');
  
  my $taxon_id = $meta->get_taxonomy_id;
  triple(u($prefix{base}.$gene->stable_id), 'term:taxon', 'taxon:'.$taxon_id);

  foreach my $transcript (@trans) {
    triple( u($prefix{base}.$gene->stable_id), 'sio:SIO_010080', 'base:'.$transcript->stable_id);
    triple( u($prefix{base}.$transcript->stable_id), 'rdf:type', 'term:EnsemblTranscript');
    dump_feature($transcript);
    
    if ($transcript->translation) {
      my $trans = $transcript->translation;
      triple( u($prefix{base}.$transcript->stable_id), 'sio:SIO_010082', 'base:'.$trans->stable_id);
      triple( u($prefix{base}.$trans->stable_id), 'rdf:type', 'term:EnsemblProtein');
      triple(u($prefix{base}.$trans->stable_id), 'dc:identifier', '"'.$trans->stable_id.'"' );
    }

    my @exons = @{$transcript->get_all_Exons};
    if ($transcript->strand == -1) {
      @exons = reverse @exons;
    }
    my $position = 1;
    # Assert Exon bag for a given transcript.
    triple('base:'.$transcript->stable_id, 'sio:SIO_010081', u($prefix{base}.$transcript->stable_id.'/splice'));
    triple(u($prefix{base}.$transcript->stable_id.'/splice'), 'rdf:type', 'term:ExonSpliceToTranscript');
    foreach my $exon (@exons) {
      triple(u($prefix{base}.$transcript->stable_id.'/splice'), 'sio:SIO_000053', 'base:'.$exon->stable_id);
      triple('base:'.$exon->stable_id,'rdf:type','term:EnsemblExon');
      triple('base:'.$transcript->stable_id, 'sio:SIO_000974',  u($prefix{base}.$transcript->stable_id.'#Exon_'.$position));
      triple(u($prefix{base}.$transcript->stable_id.'#Exon_'.$position),  'rdf:type', 'term:EnsemblExonOrderedItem');
      triple(u($prefix{base}.$transcript->stable_id.'#Exon_'.$position), 'sio:SIO_000628', 'base:'.$exon->stable_id);
      triple(u($prefix{base}.$transcript->stable_id.'#Exon_'.$position), 'sio:SIO_000300', $position);
      dump_feature($exon);
      $position++;
    }
  }

  # Homology

  my $similar_genes = $gene->get_all_homologous_Genes;
  foreach my $alt_gene (map {$_->[0]} @$similar_genes) {
    triple('base:'.$gene->stable_id, 'sio:SIO_000558', 'base:'.$alt_gene->stable_id);
  }
  print STDERR ".\n";
  # last if ($count == 100);
}
print "Dumped triples for $count genes \n";

  sub dump_feature {
    my $feature = shift;
    my $location = u($prefix{base}.'75/homo_sapiens/grch37/'.$feature->seq_region_name.':'.$feature->start.'-'.$feature->end.':'.$feature->strand);
    my $begin = u($prefix{base}.'75/homo_sapiens/grch37/'.$feature->seq_region_name.':'.$feature->start.':'.$feature->strand);
    my $end = u($prefix{base}.'75/homo_sapiens/grch37/'.$feature->seq_region_name.':'.$feature->end.':'.$feature->strand);
    my $reference = u($prefix{base}.'75/homo_sapiens/grch37/'.$feature->seq_region_name);
    triple(u($prefix{base}.$feature->stable_id), 'faldo:location', $location);
    triple($location, 'rdf:type', 'faldo:Region');
    triple($location, 'faldo:begin', $begin);
    triple($location, 'faldo:end', $end);
    triple($begin, 'rdf:type', 'faldo:ExactPosition');
    triple($begin, 'rdf:type', ($feature->strand == 1)? 'faldo:ForwardStrandPosition':'faldo:ReverseStrandPosition');
    triple($begin, 'faldo:position', ($feature->strand == 1) ? $feature->start : $feature->end);
    triple($begin, 'faldo:reference', $reference);

    triple($end, 'rdf:type', 'faldo:ExactPosition');
    triple($end, 'rdf:type', ($feature->strand == 1)? 'faldo:ForwardStrandPosition':'faldo:ReverseStrandPosition');
    triple($end, 'faldo:position', ($feature->strand == 1) ? $feature->end : $feature->start);
    triple($end, 'faldo:reference', $reference);

    triple('base:'.$feature->stable_id, 'dc:identifier', '"'.$feature->stable_id.'"' );
  }
  sub u {
    my $stuff= shift;
    return '<'.$stuff.'>';
  }
  sub triple {
    my ($subject,$predicate,$object) = @_;

    printf "%s %s %s .\n",$subject,$predicate,$object;
  }


