#!/usr/bin/env ruby
#
# Taxonomy ontology generator
#
#  Copyright (C) 2013,2014 Toshiaki Katayama <ktym@dbcls.jp>
#
# Usage:
#
#   % wget ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz
#   % mkdir taxdump
#   % tar --directory=taxdump -xvf taxdump.tar.gz
#   % ruby taxdump2owl.rb > taxdump.owl 2> taxcite.ttl
#

module TurtleHelper
  def quote(str)
    return str.gsub('\\', '\\\\').gsub("\e", '\\e').gsub("\b", '\\b').gsub("\f", '\\f').gsub("\t", '\\t').gsub("\n", '\\n').gsub("\r", '\\r').gsub('"', '\\"').inspect
  end

  def triple(s, p, o)
    return [s, p, o].join("\t") + " ."
  end
end

module TaxonomyOntology

  PREFIX = [
    "@base <http://ddbj.nig.ac.jp/ontologies/taxonomy/> .",
    "@prefix : <> .",
    "@prefix owl: <http://www.w3.org/2002/07/owl#> .",
    "@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .",
    "@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .",
    "@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .",
    #"@prefix dcterms: <http://purl.org/dc/terms/> .",
    #"@prefix sio: <http://semanticscience.org/resource#> .",
    #"@prefix so: <http://purl.org/obo/owl/SO#> .",
    #"@prefix obo: <http://purl.obolibrary.org/obo/> .",
    #"@prefix faldo: <http://biohackathon.org/resource/faldo#> .",
    #"@prefix taxo: <http://taxonomyontology.org/ontology#> .",
    #"@prefix taxo: <http://insdc.org/owl/taxonomy#> .",
    "@prefix taxid: <http://identifiers.org/taxonomy/> .",
    "@prefix taxncbi: <http://www.ncbi.nlm.nih.gov/taxonomy/> .",
    #"@prefix codon: <http://www.ncbi.nlm.nih.gov/Taxonomy/Utils/wprintgc.cgi#> .",
    #"@prefix pmid: <http://pubmed.org/> .",
    "@prefix pubmed: <http://identifiers.org/pubmed/> .",
  ]

  ONTOLOGY = <<"END_OF_ONTOLOGY"

# Taxonomy ontology

<>
  a owl:Ontology ;
  rdfs:comment "Taxonomy ontology generated from NCBI taxdump files" ;
  owl:versionInfo "#{Time.now.strftime('%Y-%m-%d')}"^^xsd:date .

# properties

:rank
  a owl:ObjectProperty, owl:FunctionalProperty ;
  rdfs:label "Taxonomy rank" ;
  rdfs:domain :Taxon ;
  rdfs:range :Rank .
:merged
  a owl:ObjectProperty ;
  rdfs:label "Previous taxon ID" ;
  rdfs:domain :Taxon ;
  rdfs:range :Taxon .

:citation
  a owl:ObjectProperty ;
  rdfs:label "Citation node" ;
  rdfs:domain :Taxon ;
  rdfs:range rdfs:Resource .
:citationPubMed
  a owl:ObjectProperty ;
  rdfs:label "Citation PubMed ID" ;
  rdfs:domain :Taxon ;
  rdfs:range rdfs:Resource .
:citationURL
  a owl:DatatypeProperty ;
  rdfs:label "Citation URL" ;
  rdfs:domain :Taxon ;
  rdfs:range xsd:string .
:citationKey
  a owl:DatatypeProperty ;
  rdfs:label "Citation key" ;
  rdfs:domain :Taxon ;
  rdfs:range xsd:string .
:citationText
  a owl:DatatypeProperty ;
  rdfs:label "Citation text" ;
  rdfs:domain :Taxon ;
  rdfs:range xsd:string .

:geneticCode
  a owl:ObjectProperty, owl:FunctionalProperty ;
  rdfs:label "Genetic code" ;
  rdfs:domain :Taxon ;
  rdfs:range :GeneticCode .
:geneticCodeMt
  a owl:ObjectProperty, owl:FunctionalProperty ;
  rdfs:label "Mitochondrial genetic code" ;
  rdfs:domain :Taxon ;
  rdfs:range :GeneticCode .

# properties (taxdump/names.dmp)

:name
  a owl:DatatypeProperty ;
  rdfs:label "name" ;
  rdfs:domain :Taxon ;
  rdfs:range xsd:string .

:scientificName
  a owl:DatatypeProperty, owl:FunctionalProperty ;
  rdfs:subPropertyOf :name ;
  rdfs:label "scientific name" ;
  rdfs:domain :Taxon ;
  rdfs:range xsd:string .
:authority
  a owl:DatatypeProperty ;
  rdfs:subPropertyOf :name ;
  rdfs:label "authority" ;
  rdfs:domain :Taxon ;
  rdfs:range xsd:string .
:synonym
  a owl:DatatypeProperty ;
  rdfs:subPropertyOf :name ;
  rdfs:label "synonym" ;
  rdfs:domain :Taxon ;
  rdfs:range xsd:string .
:preferredSynonym
  a owl:DatatypeProperty ;
  rdfs:subPropertyOf :name ;
  rdfs:label "preferred synonym" ;
  rdfs:domain :Taxon ;
  rdfs:range xsd:string .
:acronym
  a owl:DatatypeProperty ;
  rdfs:subPropertyOf :name ;
  rdfs:label "acronym" ;
  rdfs:domain :Taxon ;
  rdfs:range xsd:string .
:preferredAcronym
  a owl:DatatypeProperty ;
  rdfs:subPropertyOf :name ;
  rdfs:label "preferred acronym" ;
  rdfs:domain :Taxon ;
  rdfs:range xsd:string .
:anamorph
  a owl:DatatypeProperty ;
  rdfs:subPropertyOf :name ;
  rdfs:label "anamorph" ;
  rdfs:domain :Taxon ;
  rdfs:range xsd:string .
:teleomorph
  a owl:DatatypeProperty ;
  rdfs:subPropertyOf :name ;
  rdfs:label "teleomorph" ;
  rdfs:domain :Taxon ;
  rdfs:range xsd:string .
:misnomer
  a owl:DatatypeProperty ;
  rdfs:subPropertyOf :name ;
  rdfs:label "misnomer" ;
  rdfs:domain :Taxon ;
  rdfs:range xsd:string .
:commonName
  a owl:DatatypeProperty ;
  rdfs:subPropertyOf :name ;
  rdfs:label "common name" ;
  rdfs:domain :Taxon ;
  rdfs:range xsd:string .
:preferredCommonName
  a owl:DatatypeProperty ;
  rdfs:subPropertyOf :name ;
  rdfs:label "preferred common name" ;
  rdfs:domain :Taxon ;
  rdfs:range xsd:string .
:inPart
  a owl:DatatypeProperty ;
  rdfs:subPropertyOf :name ;
  rdfs:label "in-part" ;
  rdfs:domain :Taxon ;
  rdfs:range xsd:string .
:includes
  a owl:DatatypeProperty ;
  rdfs:subPropertyOf :name ;
  rdfs:label "includes" ;
  rdfs:domain :Taxon ;
  rdfs:range xsd:string .
:equivalentName
  a owl:DatatypeProperty ;
  rdfs:subPropertyOf :name ;
  rdfs:label "equivalent name" ;
  rdfs:domain :Taxon ;
  rdfs:range xsd:string .
:misspelling
  a owl:DatatypeProperty ;
  rdfs:subPropertyOf :name ;
  rdfs:label "misspelling" ;
  rdfs:domain :Taxon ;
  rdfs:range xsd:string .
:typeMaterial
  a owl:DatatypeProperty ;
  rdfs:subPropertyOf :name ;
  rdfs:label "type material" ;
  rdfs:domain :Taxon ;
  rdfs:range xsd:string .
:genbankAcronym
  a owl:DatatypeProperty ;
  rdfs:subPropertyOf :name ;
  rdfs:label "genbank acronym" ;
  rdfs:domain :Taxon ;
  rdfs:range xsd:string .
:genbankAnamorph
  a owl:DatatypeProperty ;
  rdfs:subPropertyOf :name ;
  rdfs:label "genbank anamorph" ;
  rdfs:domain :Taxon ;
  rdfs:range xsd:string .
:genbankCommonName
  a owl:DatatypeProperty ;
  rdfs:subPropertyOf :name ;
  rdfs:label "genbank common name" ;
  rdfs:domain :Taxon ;
  rdfs:range xsd:string .
:genbankSynonym
  a owl:DatatypeProperty ;
  rdfs:subPropertyOf :name ;
  rdfs:label "genbank synonym" ;
  rdfs:domain :Taxon ;
  rdfs:range xsd:string .
:blastName
  a owl:DatatypeProperty ;
  rdfs:subPropertyOf :name ;
  rdfs:label "blast name" ;
  rdfs:domain :Taxon ;
  rdfs:range xsd:string .

:uniqueName
  a owl:DatatypeProperty ;
  rdfs:subPropertyOf :name ;
  rdfs:label "unique name" ;
  rdfs:domain :Taxon ;
  rdfs:range xsd:string .

# classes (taxdump/nodes.dmp)

:Taxon
  a owl:Class ;
  rdfs:label "taxon" .

:Rank
  a owl:Class ;
  rdfs:label "rank" .

:Class
  a :Rank ;
  rdfs:label "class" .
:Family
  a :Rank ;
  rdfs:label "family" .
:Forma
  a :Rank ;
  rdfs:label "forma" .
:Genus
  a :Rank ;
  rdfs:label "genus" .
:Infraclass
  a :Rank ;
  rdfs:label "infraclass" .
:Infraorder
  a :Rank ;
  rdfs:label "infraorder" .
:Kingdom
  a :Rank ;
  rdfs:label "kingdom" .
:NoRank
  a :Rank ;
  rdfs:label "no rank" .
:Order
  a :Rank ;
  rdfs:label "order" .
:Parvorder
  a :Rank ;
  rdfs:label "parvorder" .
:Phylum
  a :Rank ;
  rdfs:label "phylum" .
:Species
  a :Rank ;
  rdfs:label "species" .
:SpeciesGroup
  a :Rank ;
  rdfs:label "species group" .
:SpeciesSubgroup
  a :Rank ;
  rdfs:label "species subgroup" .
:Subclass
  a :Rank ;
  rdfs:label "subclass" .
:Subfamily
  a :Rank ;
  rdfs:label "subfamily" .
:Subgenus
  a :Rank ;
  rdfs:label "subgenus" .
:Subkingdom
  a :Rank ;
  rdfs:label "subkingdom" .
:Suborder
  a :Rank ;
  rdfs:label "suborder" .
:Subphylum
  a :Rank ;
  rdfs:label "subphylum" .
:Subspecies
  a :Rank ;
  rdfs:label "subspecies" .
:Subtribe
  a :Rank ;
  rdfs:label "subtribe" .
:Superclass
  a :Rank ;
  rdfs:label "superclass" .
:Superfamily
  a :Rank ;
  rdfs:label "superfamily" .
:Superkingdom
  a :Rank ;
  rdfs:label "superkingdom" .
:Superorder
  a :Rank ;
  rdfs:label "superorder" .
:Superphylum
  a :Rank ;
  rdfs:label "superphylum" .
:Tribe
  a :Rank ;
  rdfs:label "tribe" .
:Varietas
  a :Rank ;
  rdfs:label "varietas" .

# classes (taxdump/gencode.dmp)

:GeneticCode
  a owl:Class ;
  rdfs:label "Genetic code" .

:GeneticCode0
  a :GeneticCode ;
  rdfs:label "Unspecified" .
:GeneticCode1
  a :GeneticCode ;
  rdfs:label "Standard" .
:GeneticCode2
  a :GeneticCode ;
  rdfs:label "Vertebrate Mitochondrial" .
:GeneticCode3
  a :GeneticCode ;
  rdfs:label "Yeast Mitochondrial" .
:GeneticCode4
  a :GeneticCode ;
  rdfs:label "Mold Mitochondrial; Protozoan Mitochondrial; Coelenterate Mitochondrial; Mycoplasma; Spiroplasma" .
:GeneticCode5
  a :GeneticCode ;
  rdfs:label "Invertebrate Mitochondrial" .
:GeneticCode6
  a :GeneticCode ;
  rdfs:label "Ciliate Nuclear; Dasycladacean Nuclear; Hexamita Nuclear" .
:GeneticCode9
  a :GeneticCode ;
  rdfs:label "Echinoderm Mitochondrial; Flatworm Mitochondrial" .
:GeneticCode10
  a :GeneticCode ;
  rdfs:label "Euplotid Nuclear" .
:GeneticCode11
  a :GeneticCode ;
  rdfs:label "Bacterial, Archaeal and Plant Plastid" .
:GeneticCode12
  a :GeneticCode ;
  rdfs:label "Alternative Yeast Nuclear" .
:GeneticCode13
  a :GeneticCode ;
  rdfs:label "Ascidian Mitochondrial" .
:GeneticCode14
  a :GeneticCode ;
  rdfs:label "Alternative Flatworm Mitochondrial" .
:GeneticCode15
  a :GeneticCode ;
  rdfs:label "Blepharisma Macronuclear" .
:GeneticCode16
  a :GeneticCode ;
  rdfs:label "Chlorophycean Mitochondrial" .
:GeneticCode21
  a :GeneticCode ;
  rdfs:label "Trematode Mitochondrial" .
:GeneticCode22
  a :GeneticCode ;
  rdfs:label "Scenedesmus obliquus Mitochondrial" .
:GeneticCode23
  a :GeneticCode ;
  rdfs:label "Thraustochytrium Mitochondrial" .
:GeneticCode24
  a :GeneticCode ;
  rdfs:label "Pterobranchia Mitochondrial" .
:GeneticCode25
  a :GeneticCode ;
  rdfs:label "Candidate Division SR1 and Gracilibacteria" .

# taxonomy

END_OF_ONTOLOGY

  NAME_PROPERTY = {
    "scientific name"       => "scientificName",
    "authority"	            => "authority",
    "synonym"               => "synonym",
    "preferred synonym"     => "preferredSynonym",
    "acronym"               => "acronym",
    "preferred acronym"     => "preferredAcronym",
    "anamorph"              => "anamorph",
    "teleomorph"            => "teleomorph",
    "misnomer"              => "misnomer",
    "common name"           => "commonName",
    "preferred common name" => "preferredCommonName",
    "in-part"               => "inPart",
    "includes"              => "includes",
    "equivalent name"       => "equivalentName",
    "misspelling"           => "misspelling",
    "type material"         => "typeMaterial",
    "genbank acronym"       => "genbankAcronym",
    "genbank anamorph"      => "genbankAnamorph",
    "genbank common name"   => "genbankCommonName",
    "genbank synonym"       => "genbankSynonym",
    "blast name"            => "blastName",
  }

  RANK_CLASS = {
    "class"                 => "Class",
    "family"                => "Family",
    "forma"                 => "Forma",
    "genus"                 => "Genus",
    "infraclass"            => "Infraclass",      # Not defined in UniProt
    "infraorder"            => "Infraorder",      # Not defined in UniProt
    "kingdom"               => "Kingdom",
    "no rank"               => "NoRank",          # Not defined in UniProt
    "order"                 => "Order",
    "parvorder"             => "Parvorder",
    "phylum"                => "Phylum",
    "species"               => "Species",
    "species group"         => "SpeciesGroup",    # Species_Group in UniProt
    "species subgroup"      => "SpeciesSubgroup", # Species_Subgroup in UniProt
    "subclass"              => "Subclass",
    "subfamily"             => "Subfamily",
    "subgenus"              => "Subgenus",
    "subkingdom"            => "Subkingdom",
    "suborder"              => "Suborder",
    "subphylum"             => "Subphylum",
    "subspecies"            => "Subspecies",
    "subtribe"              => "Subtribe",
    "superclass"            => "Superclass",
    "superfamily"           => "Superfamily",
    "superkingdom"          => "Superkingdom",
    "superorder"            => "Superorder",
    "superphylum"           => "Superphylum",
    "tribe"                 => "Tribe",
    "varietas"              => "Varietas",
  }

  class Name
    attr_reader :name, :unique_name, :name_class

    def initialize(name, unique_name, name_class)
      @name = name
      @unique_name = unique_name
      @name_class = name_class
    end

    def property
      NAME_PROPERTY[@name_class]
    end

    def scientific_name?
      @name_class == "scientific name"
    end

    def unique_variant?
      @unique_name.length > 0
    end
  end

  class Citation
    attr_reader :pmid, :url, :key, :text

    def initialize(pmid, url, key, text)
      @pmid = pmid.to_i > 0 ? pmid : nil
      @url = url.length > 0 ? url : nil
      @key = key.length > 0 ? key : nil
      @text = text.length > 0 ? text : nil
    end
  end


  class Parser
    def initialize(filename)
      $stderr.puts "Loading #{filename} ..." if $DEBUG
      @filename = filename
      @hash = {}
      parse
    end

    def [](key)
      @hash[key]
    end

    def dmp_split(str)
      str.encode!("UTF-8", "CP1250", :invalid => :replace, :undef => :replace, :replace => "?")
      ary = str.sub(/\|$/, '').split(/\t\|\t/)
      return ary.map{|x| x.strip}
    end
  end

  ## taxdump/citations.dmp

  class CitationsParser < Parser
    def parse
      File.open(@filename).each do |line|
        cit_id, cit_key, pubmed_id, medline_id, url, text, taxid_list, = *dmp_split(line)
        next if (pubmed_id + url + cit_key + text).empty?
        citation = Citation.new(pubmed_id, url, cit_key, text)
        taxid_list.split(/\s+/).each do |tax_id|
          @hash[tax_id] ||= []
          @hash[tax_id] << citation
        end
      end
    end
  end

  ## taxdump/merged.dmp

  class MergedParser < Parser
    def parse
      File.open(@filename).each do |line|
        old_tax_id, new_tax_id, = *dmp_split(line)
        @hash[new_tax_id] ||= []
        @hash[new_tax_id] << old_tax_id
      end
    end
  end

  ## taxdump/names.dmp

  class NamesParser < Parser
    def parse
      File.open(@filename).each do |line|
        tax_id, name_txt, unique_name, name_class, = *dmp_split(line)
        name = Name.new(name_txt, unique_name, name_class)
        @hash[tax_id] ||= []
        if name.scientific_name?
          @hash[tax_id].unshift name
        else
          @hash[tax_id] << name
        end
      end
    end
  end

  ## taxdump/nodes.dmp

  class TaxdumpParser < Parser
    include TurtleHelper

    def initialize(hash = {:nodes => "nodes.dmp", :names => "names.dmp", :merged => "merged.dmp", :citations => "citations.dmp"})
      output_header
      @citations = CitationsParser.new(hash[:citations])
      @merged = MergedParser.new(hash[:merged])
      @names = NamesParser.new(hash[:names])
      super(hash[:nodes])
    end

    def output_header
      $stderr.puts "@prefix : <http://ddbj.nig.ac.jp/ontologies/taxonomy#> ."
      $stderr.puts "@prefix taxid: <http://identifiers.org/taxonomy/> .",
      $stderr.puts
      puts PREFIX
      puts ONTOLOGY
    end

    def parse
      File.open(@filename).each do |line|
        tax_id, parent_tax_id, rank, embl_code, division_id, inherited_div_flag, genetic_code_id, inherited_gc_flag, mitochondrial_genetic_code_id, inherited_mgc_flag, genbank_hidden_flag, hidden_subtree_root_flag, comments, = *dmp_split(line)
        tax = "taxid:#{tax_id}"

        puts triple(tax, "a", ":Taxon")
        puts triple(tax, "rdfs:subClassOf", "taxid:#{parent_tax_id}") if tax_id != parent_tax_id
        puts triple(tax, "rdfs:seeAlso", "taxncbi:#{tax_id}")
        puts triple(tax, ":rank", ":#{RANK_CLASS[rank]}")
        puts triple(tax, ":geneticCode", ":GeneticCode#{genetic_code_id}")
        puts triple(tax, ":geneticCodeMt", ":GeneticCode#{mitochondrial_genetic_code_id}")

        if @names[tax_id]
          @names[tax_id].each do |name|
            if name.scientific_name?
              puts triple(tax, "rdfs:label", quote(name.name))
            end
            puts triple(tax, ":#{NAME_PROPERTY[name.name_class]}", quote(name.name))
            if name.unique_variant?
              puts triple(tax, ":uniqueName", quote(name.unique_name))
            end
          end
        end

        if @citations[tax_id]
          @citations[tax_id].each do |citation|
            pairs = []
            pairs << ":citationPubMed pubmed:#{citation.pmid}" if citation.pmid
            pairs << ":citationURL #{quote(citation.url)}" if citation.url
            pairs << ":citationKey #{quote(citation.key)}" if citation.key
            pairs << ":citationText #{quote(citation.text)}" if citation.text
            #puts triple(tax, ":citation", "[ #{pairs.join(' ; ')} ]")
            $stderr.puts triple(tax, ":citation", "[ #{pairs.join(' ; ')} ]")
          end
        end

        if @merged[tax_id]
          @merged[tax_id].each do |old_tax_id|
            puts triple(tax, ":merged", "taxid:#{old_tax_id}")
          end
        end
      end
    end
  end
end

nodes_dmp = ARGV.shift || "taxdump/nodes.dmp"
names_dmp = ARGV.shift || "taxdump/names.dmp"
merged_dmp = ARGV.shift || "taxdump/merged.dmp"
citations_dmp = ARGV.shift || "taxdump/citations.dmp"

TaxonomyOntology::TaxdumpParser.new(
  :nodes => nodes_dmp,
  :names => names_dmp,
  :merged => merged_dmp,
  :citations => citations_dmp
)


=begin

* NCBI (taxdump.tar.gz)

nodes.dmp file consists of taxonomy nodes. The description for each node includes the following fields:

        tax_id                                  -- node id in GenBank taxonomy database
        parent tax_id                           -- parent node id in GenBank taxonomy database
        rank                                    -- rank of this node (superkingdom, kingdom, ...) 
        embl code                               -- locus-name prefix; not unique
        division id                             -- see division.dmp file
        inherited div flag  (1 or 0)            -- 1 if node inherits division from parent
        genetic code id                         -- see gencode.dmp file
        inherited GC  flag  (1 or 0)            -- 1 if node inherits genetic code from parent
        mitochondrial genetic code id           -- see gencode.dmp file
        inherited MGC flag  (1 or 0)            -- 1 if node inherits mitochondrial gencode from parent
        GenBank hidden flag (1 or 0)            -- 1 if name is suppressed in GenBank entry lineage
        hidden subtree root flag (1 or 0)       -- 1 if this subtree has no sequence data yet
        comments                                -- free-text comments and citations

1	|	1	|	no rank	|		|	8	|	0	|	1	|	0	|	0	|	0	|	0	|	0	|		|
562	|	561	|	species	|	EC	|	0	|	1	|	11	|	1	|	0	|	1	|	1	|	0	|		|
511145	|	83333	|	no rank	|		|	0	|	1	|	11	|	1	|	0	|	1	|	1	|	0	|		|

Taxonomy names file (names.dmp):
        tax_id                                  -- the id of node associated with this name
        name_txt                                -- name itself
        unique name                             -- the unique variant of this name if name not unique
        name class                              -- (synonym, common name, ...)

1	|	all	|		|	synonym	|
1	|	root	|		|	scientific name	|
562	|	"Bacillus coli" Migula 1895	|		|	authority	|
562	|	"Bacterium coli commune" Escherich 1885	|		|	authority	|
562	|	"Bacterium coli" (Migula 1895) Lehmann and Neumann 1896	|		|	authority	|
562	|	ATCC 11775	|		|	type material	|
562	|	Bacillus coli	|		|	synonym	|
562	|	Bacterium coli	|		|	synonym	|
562	|	Bacterium coli commune	|		|	synonym	|
562	|	CCUG 24	|		|	type material	|
562	|	CCUG 29300	|		|	type material	|
562	|	CIP 54.8	|		|	type material	|
562	|	DSM 30083	|		|	type material	|
562	|	Enterococcus coli	|		|	synonym	|
562	|	Escherchia coli	|		|	misspelling	|
562	|	Escherichia coli	|		|	scientific name	|
562	|	Escherichia coli (Migula 1895) Castellani and Chalmers 1919	|		|	authority	|
562	|	Escherichia coli retron Ec107	|		|	includes	|
562	|	Escherichia coli retron Ec67	|		|	includes	|
562	|	Escherichia coli retron Ec79	|		|	includes	|
562	|	Escherichia coli retron Ec86	|		|	includes	|
562	|	Eschericia coli	|		|	misspelling	|
562	|	JCM 1649	|		|	type material	|
562	|	LMG 2092	|		|	type material	|
562	|	NBRC 102203	|		|	type material	|
562	|	NCCB 54008	|		|	type material	|
562	|	NCTC 9001	|		|	type material	|
562	|	bacterium 10a	|		|	includes	|
562	|	bacterium E3	|		|	synonym	|
511145	|	Escherichia coli MG1655	|		|	synonym	|
511145	|	Escherichia coli str. K-12 substr. MG1655	|		|	scientific name	|
511145	|	Escherichia coli str. K12 substr. MG1655	|		|	equivalent name	|
511145	|	Escherichia coli str. MG1655	|		|	equivalent name	|
511145	|	Escherichia coli strain MG1655	|		|	equivalent name	|


Citations file (citations.dmp):
	cit_id					-- the unique id of citation
	cit_key					-- citation key
	pubmed_id				-- unique id in PubMed database (0 if not in PubMed)
	medline_id				-- unique id in MedLine database (0 if not in MedLine)
	url					-- URL associated with citation
	text					-- any text (usually article name and authors).
						-- The following characters are escaped in this text by a backslash:
						-- newline (appear as "\n"),
						-- tab character ("\t"),
						-- double quotes ('\"'),
						-- backslash character ("\\").
	taxid_list				-- list of node ids separated by a single space

9620	|	Martinez-Murcia AJ et al. (1999)	|	0	|	10319482	|		|	Martinez-Murcia, A.J., Anton, A.I., Rodriguez-Valera, F. \"Patterns of sequence variation in two regions of the 16S rRNA multigene family of Escherichia coli.\" Int. J. Syst. Bacteriol. (1999) 49:601-610.	|	562 	|


Merged nodes file (merged.dmp):
	old_tax_id                              -- id of nodes which has been merged
	new_tax_id                              -- id of nodes which is result of merging

662101	|	562	|
662104	|	562	|


Genetic codes file (gencode.dmp):
        genetic code id                         -- GenBank genetic code id
        abbreviation                            -- genetic code name abbreviation
        name                                    -- genetic code name
        cde                                     -- translation table for this genetic code
        starts                                  -- start codons for this genetic code


* EBI (taxonomy.dat)

ID                        : 1
PARENT ID                 : 0
RANK                      : no rank
GC ID                     : 1
SCIENTIFIC NAME           : root
SYNONYM                   : all
//
ID                        : 562
PARENT ID                 : 561
RANK                      : species
GC ID                     : 11
SCIENTIFIC NAME           : Escherichia coli
SYNONYM                   : bacterium E3
SYNONYM                   : Bacterium coli
SYNONYM                   : Bacterium coli commune
SYNONYM                   : Enterococcus coli
SYNONYM                   : Bacillus coli
INCLUDES                  : bacterium 10a
INCLUDES                  : Escherichia coli retron Ec86
INCLUDES                  : Escherichia coli retron Ec79
INCLUDES                  : Escherichia coli retron Ec67
INCLUDES                  : Escherichia coli retron Ec107
MISSPELLING               : Eschericia coli
MISSPELLING               : Escherchia coli
//
ID                        : 511145
PARENT ID                 : 83333
RANK                      : no rank
GC ID                     : 11
SCIENTIFIC NAME           : Escherichia coli str. K-12 substr. MG1655
SYNONYM                   : Escherichia coli MG1655
EQUIVALENT NAME           : Escherichia coli str. K12 substr. MG1655
EQUIVALENT NAME           : Escherichia coli strain MG1655
EQUIVALENT NAME           : Escherichia coli str. MG1655
//

* OBO (ncbitaxon.obo)

format-version: 1.2
data-version: 2013-01-24
synonymtypedef: acronym "acronym"
synonymtypedef: anamorph "anamorph"
synonymtypedef: blast_name "blast name"
synonymtypedef: common_name "common name"
synonymtypedef: equivalent_name "equivalent name"
synonymtypedef: genbank_acronym "genbank acronym"
synonymtypedef: genbank_anamorph "genbank anamorph"
synonymtypedef: genbank_common_name "genbank common name"
synonymtypedef: genbank_synonym "genbank synonym"
synonymtypedef: in_part "in-part"
synonymtypedef: misnomer "misnomer"
synonymtypedef: misspelling "misspelling"
synonymtypedef: scientific_name "scientific name"
synonymtypedef: synonym "synonym"
synonymtypedef: teleomorph "teleomorph"
remark: Autogenerated by OWLTools-NCBIConverter.
ontology: ncbitaxon

[Term]
id: NCBITaxon:1
name: root
namespace: ncbi_taxonomy
synonym: "all" RELATED synonym []
xref: GC_ID:1

[Term]
id: NCBITaxon:562
name: Escherichia coli
namespace: ncbi_taxonomy
alt_id: NCBITaxon:662101
alt_id: NCBITaxon:662104
synonym: "Bacillus coli" RELATED synonym []
synonym: "Bacterium coli" RELATED synonym []
synonym: "Bacterium coli commune" RELATED synonym []
synonym: "bacterium E3" RELATED synonym []
synonym: "Enterococcus coli" RELATED synonym []
synonym: "Escherchia coli" RELATED misspelling []
synonym: "Eschericia coli" RELATED misspelling []
xref: GC_ID:11
xref: PMID:10319482
is_a: NCBITaxon:561 ! Escherichia
property_value: has_rank NCBITaxon:species

[Term]
id: NCBITaxon:511145
name: Escherichia coli str. K-12 substr. MG1655
namespace: ncbi_taxonomy
synonym: "Escherichia coli MG1655" RELATED synonym []
synonym: "Escherichia coli str. K12 substr. MG1655" EXACT equivalent_name []
synonym: "Escherichia coli str. MG1655" EXACT equivalent_name []
synonym: "Escherichia coli strain MG1655" EXACT equivalent_name []
xref: GC_ID:11
is_a: NCBITaxon:83333 ! Escherichia coli K-12

* OBO2OWL (ncbitaxon.owl)

    <!-- http://purl.obolibrary.org/obo/NCBITaxon_1 -->

    <owl:Class rdf:about="http://purl.obolibrary.org/obo/NCBITaxon_1">
        <rdfs:label rdf:datatype="http://www.w3.org/2001/XMLSchema#string">root</rdfs:label>
        <oboInOwl:hasDbXref rdf:datatype="http://www.w3.org/2001/XMLSchema#string">GC_ID:1</oboInOwl:hasDbXref>
        <oboInOwl:hasRelatedSynonym rdf:datatype="http://www.w3.org/2001/XMLSchema#string">all</oboInOwl:hasRelatedSynonym>
        <oboInOwl:hasOBONamespace rdf:datatype="http://www.w3.org/2001/XMLSchema#string">ncbi_taxonomy</oboInOwl:hasOBONamespace>
    </owl:Class>
    <owl:Axiom>
        <owl:annotatedTarget rdf:datatype="http://www.w3.org/2001/XMLSchema#string">all</owl:annotatedTarget>
        <owl:annotatedSource rdf:resource="http://purl.obolibrary.org/obo/NCBITaxon_1"/>
        <oboInOwl:hasSynonymType rdf:resource="http://purl.obolibrary.org/obo/ncbitaxon#synonym"/>
        <owl:annotatedProperty rdf:resource="http://www.geneontology.org/formats/oboInOwl#hasRelatedSynonym"/>
    </owl:Axiom>
    
    <!-- http://purl.obolibrary.org/obo/NCBITaxon_562 -->

    <owl:Class rdf:about="http://purl.obolibrary.org/obo/NCBITaxon_562">
        <rdfs:label rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Escherichia coli</rdfs:label>
        <rdfs:subClassOf rdf:resource="http://purl.obolibrary.org/obo/NCBITaxon_561"/>
        <oboInOwl:hasRelatedSynonym rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Bacillus coli</oboInOwl:hasRelatedSynonym>
        <oboInOwl:hasRelatedSynonym rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Bacterium coli</oboInOwl:hasRelatedSynonym>
        <oboInOwl:hasRelatedSynonym rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Bacterium coli commune</oboInOwl:hasRelatedSynonym>
        <oboInOwl:hasRelatedSynonym rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Enterococcus coli</oboInOwl:hasRelatedSynonym>
        <oboInOwl:hasRelatedSynonym rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Escherchia coli</oboInOwl:hasRelatedSynonym>
        <oboInOwl:hasRelatedSynonym rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Eschericia coli</oboInOwl:hasRelatedSynonym>
        <oboInOwl:hasDbXref rdf:datatype="http://www.w3.org/2001/XMLSchema#string">GC_ID:11</oboInOwl:hasDbXref>
        <oboInOwl:hasAlternativeId rdf:datatype="http://www.w3.org/2001/XMLSchema#string">NCBITaxon:662101</oboInOwl:hasAlternativeId>
        <oboInOwl:hasAlternativeId rdf:datatype="http://www.w3.org/2001/XMLSchema#string">NCBITaxon:662104</oboInOwl:hasAlternativeId>
        <oboInOwl:hasDbXref rdf:datatype="http://www.w3.org/2001/XMLSchema#string">PMID:10319482</oboInOwl:hasDbXref>
        <oboInOwl:hasRelatedSynonym rdf:datatype="http://www.w3.org/2001/XMLSchema#string">bacterium E3</oboInOwl:hasRelatedSynonym>
        <oboInOwl:hasOBONamespace rdf:datatype="http://www.w3.org/2001/XMLSchema#string">ncbi_taxonomy</oboInOwl:hasOBONamespace>
        <ncbitaxon:has_rank rdf:resource="http://purl.obolibrary.org/obo/NCBITaxon_species"/>
    </owl:Class>
    <owl:Axiom>
        <owl:annotatedTarget rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Bacillus coli</owl:annotatedTarget>
        <owl:annotatedSource rdf:resource="http://purl.obolibrary.org/obo/NCBITaxon_562"/>
        <oboInOwl:hasSynonymType rdf:resource="http://purl.obolibrary.org/obo/ncbitaxon#synonym"/>
        <owl:annotatedProperty rdf:resource="http://www.geneontology.org/formats/oboInOwl#hasRelatedSynonym"/>
    </owl:Axiom>
    <owl:Axiom>
        <owl:annotatedTarget rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Bacterium coli</owl:annotatedTarget>
        <owl:annotatedSource rdf:resource="http://purl.obolibrary.org/obo/NCBITaxon_562"/>
        <oboInOwl:hasSynonymType rdf:resource="http://purl.obolibrary.org/obo/ncbitaxon#synonym"/>
        <owl:annotatedProperty rdf:resource="http://www.geneontology.org/formats/oboInOwl#hasRelatedSynonym"/>
    </owl:Axiom>
    <owl:Axiom>
        <owl:annotatedTarget rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Escherchia coli</owl:annotatedTarget>
        <owl:annotatedSource rdf:resource="http://purl.obolibrary.org/obo/NCBITaxon_562"/>
        <oboInOwl:hasSynonymType rdf:resource="http://purl.obolibrary.org/obo/ncbitaxon#misspelling"/>
        <owl:annotatedProperty rdf:resource="http://www.geneontology.org/formats/oboInOwl#hasRelatedSynonym"/>
    </owl:Axiom>
    <owl:Axiom>
        <owl:annotatedTarget rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Eschericia coli</owl:annotatedTarget>
        <owl:annotatedSource rdf:resource="http://purl.obolibrary.org/obo/NCBITaxon_562"/>
        <oboInOwl:hasSynonymType rdf:resource="http://purl.obolibrary.org/obo/ncbitaxon#misspelling"/>
        <owl:annotatedProperty rdf:resource="http://www.geneontology.org/formats/oboInOwl#hasRelatedSynonym"/>
    </owl:Axiom>
    <owl:Axiom>
        <owl:annotatedTarget rdf:datatype="http://www.w3.org/2001/XMLSchema#string">bacterium E3</owl:annotatedTarget>
        <owl:annotatedSource rdf:resource="http://purl.obolibrary.org/obo/NCBITaxon_562"/>
        <oboInOwl:hasSynonymType rdf:resource="http://purl.obolibrary.org/obo/ncbitaxon#synonym"/>
        <owl:annotatedProperty rdf:resource="http://www.geneontology.org/formats/oboInOwl#hasRelatedSynonym"/>
    </owl:Axiom>
    <owl:Axiom>
        <owl:annotatedTarget rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Bacterium coli commune</owl:annotatedTarget>
        <owl:annotatedSource rdf:resource="http://purl.obolibrary.org/obo/NCBITaxon_562"/>
        <oboInOwl:hasSynonymType rdf:resource="http://purl.obolibrary.org/obo/ncbitaxon#synonym"/>
        <owl:annotatedProperty rdf:resource="http://www.geneontology.org/formats/oboInOwl#hasRelatedSynonym"/>
    </owl:Axiom>
    <owl:Axiom>
        <owl:annotatedTarget rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Enterococcus coli</owl:annotatedTarget>
        <owl:annotatedSource rdf:resource="http://purl.obolibrary.org/obo/NCBITaxon_562"/>
        <oboInOwl:hasSynonymType rdf:resource="http://purl.obolibrary.org/obo/ncbitaxon#synonym"/>
        <owl:annotatedProperty rdf:resource="http://www.geneontology.org/formats/oboInOwl#hasRelatedSynonym"/>
    </owl:Axiom>
    
    <!-- http://purl.obolibrary.org/obo/NCBITaxon_511145 -->

    <owl:Class rdf:about="http://purl.obolibrary.org/obo/NCBITaxon_511145">
        <rdfs:label rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Escherichia coli str. K-12 substr. MG1655</rdfs:label>
        <rdfs:subClassOf rdf:resource="http://purl.obolibrary.org/obo/NCBITaxon_83333"/>
        <oboInOwl:hasRelatedSynonym rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Escherichia coli MG1655</oboInOwl:hasRelatedSynonym>
        <oboInOwl:hasExactSynonym rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Escherichia coli str. K12 substr. MG1655</oboInOwl:hasExactSynonym>
        <oboInOwl:hasExactSynonym rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Escherichia coli str. MG1655</oboInOwl:hasExactSynonym>
        <oboInOwl:hasExactSynonym rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Escherichia coli strain MG1655</oboInOwl:hasExactSynonym>
        <oboInOwl:hasDbXref rdf:datatype="http://www.w3.org/2001/XMLSchema#string">GC_ID:11</oboInOwl:hasDbXref>
        <oboInOwl:hasOBONamespace rdf:datatype="http://www.w3.org/2001/XMLSchema#string">ncbi_taxonomy</oboInOwl:hasOBONamespace>
    </owl:Class>
    <owl:Axiom>
        <owl:annotatedTarget rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Escherichia coli MG1655</owl:annotatedTarget>
        <owl:annotatedSource rdf:resource="http://purl.obolibrary.org/obo/NCBITaxon_511145"/>
        <oboInOwl:hasSynonymType rdf:resource="http://purl.obolibrary.org/obo/ncbitaxon#synonym"/>
        <owl:annotatedProperty rdf:resource="http://www.geneontology.org/formats/oboInOwl#hasRelatedSynonym"/>
    </owl:Axiom>
    <owl:Axiom>
        <owl:annotatedTarget rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Escherichia coli strain MG1655</owl:annotatedTarget>
        <owl:annotatedSource rdf:resource="http://purl.obolibrary.org/obo/NCBITaxon_511145"/>
        <oboInOwl:hasSynonymType rdf:resource="http://purl.obolibrary.org/obo/ncbitaxon#equivalent_name"/>
        <owl:annotatedProperty rdf:resource="http://www.geneontology.org/formats/oboInOwl#hasExactSynonym"/>
    </owl:Axiom>
    <owl:Axiom>
        <owl:annotatedTarget rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Escherichia coli str. MG1655</owl:annotatedTarget>
        <owl:annotatedSource rdf:resource="http://purl.obolibrary.org/obo/NCBITaxon_511145"/>
        <oboInOwl:hasSynonymType rdf:resource="http://purl.obolibrary.org/obo/ncbitaxon#equivalent_name"/>
        <owl:annotatedProperty rdf:resource="http://www.geneontology.org/formats/oboInOwl#hasExactSynonym"/>
    </owl:Axiom>
    <owl:Axiom>
        <owl:annotatedTarget rdf:datatype="http://www.w3.org/2001/XMLSchema#string">Escherichia coli str. K12 substr. MG1655</owl:annotatedTarget>
        <owl:annotatedSource rdf:resource="http://purl.obolibrary.org/obo/NCBITaxon_511145"/>
        <oboInOwl:hasSynonymType rdf:resource="http://purl.obolibrary.org/obo/ncbitaxon#equivalent_name"/>
        <owl:annotatedProperty rdf:resource="http://www.geneontology.org/formats/oboInOwl#hasExactSynonym"/>
    </owl:Axiom>

* Turtle (draft version; final version will be generated by this script)

@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
#@prefix taxo: <http://taxonomyontology.org/ontology#> .
@prefix taxo: <http://insdc.org/ontology/taxonomy#> .
@prefix taxid: <http://identifiers.org/taxonomy/> .
@prefix taxncbi: <http://www.ncbi.nlm.nih.gov/taxonomy/> .
@prefix codon: <http://www.ncbi.nlm.nih.gov/Taxonomy/Utils/wprintgc.cgi#> .
@prefix pmid: <http://pubmed.org/> .

<>
  a owl:Ontology ;
  rdfs:comment "Ontology for NCBI taxonomy converted from NCBI's taxdump files" ;
  owl:versionIRI <http://taxonomyontology.org/version/2013-08-21> .

taxid:1
  rdfs:seeAlso taxncbi:1 ;
  a owl:Class ;
  rdfs:label "root" ;
  taxo:codonTable codon:SG1 ;
  taxo:hasRelatedSynonym "all" .

[]
  a owl:Axiom ;
  owl:annotatedProperty taxo:hasRelatedSynonym ;
  owl:annotatedSource taxid:1 ;
  owl:annotatedTarget "all" .

taxid:562
  rdfs:seeAlso taxncbi:562 ;
  a owl:Class ;
  rdfs:label "Escherichia coli" ;
  rdfs:subClassOf taxid:561 ;
  taxo:hasRelatedSynonym "Bacillus coli" ;
  taxo:hasRelatedSynonym "Bacterium coli" ;
  taxo:hasRelatedSynonym "Bacterium coli commune" ;
  taxo:hasRelatedSynonym "Enterococcus coli" ;
  taxo:hasRelatedSynonym "Escherchia coli" ;
  taxo:hasRelatedSynonym "Eschericia coli" ;
  taxo:hasRelatedSynonym "bacterium E3" ;
  taxo:codonTable codon:SG11 ;
  taxo:hasAlternativeId taxid:662101 ;
  taxo:hasAlternativeId taxid:662104 ;
  taxo:reference pmid:10319482 ;
  taxo:rank taxo:Species .

[]
  a owl:Axiom ;
  owl:annotatedProperty taxo:hasRelatedSynonym ;
  owl:annotatedSource taxid:562 ;
  owl:annotatedTarget "Bacillus coli" ;
  taxo:hasSynonymType taxo:synonym .

[]
  a owl:Axiom ;
  owl:annotatedProperty taxo:hasRelatedSynonym ;
  owl:annotatedSource taxid:562 ;
  owl:annotatedTarget "Escherchia coli" ;
  taxo:hasSynonymType taxo:misspelling .

taxid:511145
  rdfs:seeAlso taxncbi:511145 ;
  a owl:Class ;
  rdfs:label "Escherichia coli str. K-12 substr. MG1655" ;
  rdfs:subClassOf taxid:83333 ;
  taxo:hasRelatedSynonym "Escherichia coli MG1655" ;
  taxo:hasExactSynonym "Escherichia coli MG1655" ;
  taxo:hasExactSynonym "Escherichia coli str. K12 substr. MG1655" ;
  taxo:hasExactSynonym "Escherichia coli str. MG1655" ;
  taxo:hasExactSynonym "Escherichia coli strain MG1655" ;
  taxo:codonTable codon:SG11 ;
  taxo:rank taxo:NoRank .  # missing in OBO2OWL

[]
  a owl:Axiom ;
  owl:annotatedSource taxid:511145 ;
  owl:annotatedTarget "Escherichia coli MG1655" ;
  owl:annotatedProperty taxo:hasRelatedSynonym ;
  taxo:hasSynonymType taxo:synonym .

[]
  a owl:Axiom ;
  owl:annotatedSource taxid:511145 ;
  owl:annotatedTarget "Escherichia coli str.MG1655" ;
  owl:annotatedProperty taxo:hasExactSynonym ;
  taxo:hasSynonymType taxo:equivalent_name .

* Taxon name types

http://www.ncbi.nlm.nih.gov/pmc/articles/PMC3245000/table/gkr1178-T2/
http://www.ebi.ac.uk/ena/about/taxonomy_name_types

% cut -f 4 -d '|' taxdump/names.dmp | s | u -c 
    919 acronym
    441 anamorph
 178894 authority
    224 blast name
  13429 common name
  18928 equivalent name
    342 genbank acronym
    144 genbank anamorph
  23282 genbank common name
   1947 genbank synonym
    415 in-part
  16200 includes
   1193 misnomer
  19980 misspelling
1060921 scientific name
 178108 synonym
    171 teleomorph
  49212 type material

* Taxon ranks

% cut -f 3 -d '|' taxdump/nodes.dmp | s | u -c
    258 	class	
   7607 	family	
    393 	forma	
  66644 	genus	
     14 	infraclass	
     76 	infraorder	
      3 	kingdom	
 138971 	no rank	
   1229 	order	
      6 	parvorder	
    102 	phylum	
 817572 	species	
    318 	species group	
    123 	species subgroup	
    129 	subclass	
   2433 	subfamily	
   1111 	subgenus	
      1 	subkingdom	
    354 	suborder	
     24 	subphylum	
  15564 	subspecies	
    321 	subtribe	
      5 	superclass	
    793 	superfamily	
      5 	superkingdom	
     48 	superorder	
      5 	superphylum	
   1635 	tribe	
   5177 	varietas	

* Uniprot taxon ranks

    <rdf:Description>
        <rdf:type rdf:resource="&owl;AllDifferent"/>
        <owl:distinctMembers rdf:parseType="Collection">
            <rdf:Description rdf:about="&core;Class"/>
            <rdf:Description rdf:about="&core;Family"/>
            <rdf:Description rdf:about="&core;Forma"/>
            <rdf:Description rdf:about="&core;Genus"/>
            <rdf:Description rdf:about="&core;Kingdom"/>
            <rdf:Description rdf:about="&core;Order"/>
            <rdf:Description rdf:about="&core;Parvorder"/>
            <rdf:Description rdf:about="&core;Phylum"/>
            <rdf:Description rdf:about="&core;Species"/>
            <rdf:Description rdf:about="&core;Species_Group"/>
            <rdf:Description rdf:about="&core;Species_Subgroup"/>
            <rdf:Description rdf:about="&core;Subclass"/>
            <rdf:Description rdf:about="&core;Subfamily"/>
            <rdf:Description rdf:about="&core;Subgenus"/>
            <rdf:Description rdf:about="&core;Subkingdom"/>
            <rdf:Description rdf:about="&core;Suborder"/>
            <rdf:Description rdf:about="&core;Subphylum"/>
            <rdf:Description rdf:about="&core;Subspecies"/>
            <rdf:Description rdf:about="&core;Subtribe"/>
            <rdf:Description rdf:about="&core;Superclass"/>
            <rdf:Description rdf:about="&core;Superfamily"/>
            <rdf:Description rdf:about="&core;Superkingdom"/>
            <rdf:Description rdf:about="&core;Superorder"/>
            <rdf:Description rdf:about="&core;Superphylum"/>
            <rdf:Description rdf:about="&core;Tribe"/>
            <rdf:Description rdf:about="&core;Varietas"/>
        </owl:distinctMembers>
    </rdf:Description>

=end
