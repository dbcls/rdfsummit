#!/usr/bin/env ruby

require 'rubygems'
require 'uri'
require 'bio'
require 'json'
require 'securerandom'

# [TODO] integrate this into BioRuby
module Bio
  class GenBank
    def dblink
      fetch('DBLINK')
    end

    def bioproject
      dblink[/\d+/]
    end
  end
end

###
### Utilities for RDF generation
###

module RDFSupport
  def new_uuid(prefix = "http://purl.jp/bio/10/genome/uuid/")
    #return "<#{prefix}#{SecureRandom.uuid}>"
    #return "genome:uuid-#{SecureRandom.uuid}"
    return "<urn:uuid:#{SecureRandom.uuid}>"
  end

  def quote(str)
    return str.gsub('\\', '\\\\').gsub("\t", '\\t').gsub("\n", '\\n').gsub("\r", '\\r').gsub('"', '\\"').inspect
  end

  def triple(s, p, o)
    return [s, p, o].join("\t") + " ."
  end

  def default_prefix
    return [
      triple("@prefix", "rdf:", "<http://www.w3.org/1999/02/22-rdf-syntax-ns#>"),
      triple("@prefix", "rdfs:", "<http://www.w3.org/2000/01/rdf-schema#>"),
      #triple("@prefix", "dcterms:", "<http://purl.org/dc/terms/>"),
      triple("@prefix", "xsd:", "<http://www.w3.org/2001/XMLSchema#>"),
      #triple("@prefix", "sio:", "<http://semanticscience.org/resource#>"),
      #triple("@prefix", "so:", "<http://purl.org/obo/owl/SO#>"),
      triple("@prefix", "obo:", "<http://purl.obolibrary.org/obo/>"),
      triple("@prefix", "faldo:", "<http://biohackathon.org/resource/faldo#>"),
    ]
  end

  def usdate2date(str)
    return Date.parse(str).strftime("%Y-%m-%d")  
  end
end

###
### Mapping RefSeq db_xref to Identifiers.org
###

# https://gist.github.com/3985701
# https://gist.github.com/4146256
class RS_ID
  include RDFSupport

  def initialize
    @rs_id = JSON.parse(File.read(File.dirname(__FILE__) + "/refseq2ttl/rs_id.json"))
  end

  def fetch(db)
    @rs_id[db]
  end

  def labels
    @rs_id.sort.each do |db, hash|
      puts triple("insdc:#{hash['class']}", "rdfs:label", quote(hash['label']))
    end
  end
end

###
### Mapping RefSeq feature table to Sequence Ontology
###

# https://gist.github.com/3650401
class FT_SO
  def initialize
    @data = JSON.parse(File.read(File.dirname(__FILE__) + "/refseq2ttl/ft_so.json"))
  end

  # ftso = FT_SO.new
  # puts ftso.so_id("-10_signal")  # => "SO:0000175"
  def so_id(feature)
    if hash = @data[feature]
      return hash["so_id"]
    end
  end

  def so_term(feature)
    if hash = @data[feature]
      return hash["so_term"]
    end
  end

  def so_desc(feature)
    if hash = @data[feature]
      return hash["so_desc"]
    end
  end

  def ft_desc(feature)
    if hash = @data[feature]
      return hash["ft_desc"]
    end
  end
end

###
### Convert RefSeq (prokaryote) entries to RDF
###

class RefSeq2RDF

  include RDFSupport

  def initialize(io = nil, seqtype = nil)
    set_prefixes

    @seqtype = seqtype
    @rs_id = RS_ID.new
    @ft_so = FT_SO.new

    @locus = {}
    @xref_warn = {}

    puts prefix
    puts

    parse_refseq(io) if io
  end

  attr_accessor :prefix

  def self.prefixes
    puts prefix
  end

  def set_prefixes
    @prefix = default_prefix + [
      #triple("@prefix", "genome:", "<http://purl.jp/bio/10/genome/>"),
      triple("@prefix", "idorg:", "<http://rdf.identifiers.org/database/>"),
      triple("@prefix", "insdc:", "<http://insdc.org/owl/>"),
    ]
  end

  def xref(subject, db, id)
    case db
    when "HOMD"
      id.sub!(/^tax_/, '')
    when "ECOCYC"
      #id = "ECOCYC:#{id}"
    when "GI", "ERIC", "HMP", "PSEUDO", "Pathema"
      unless @xref_warn[db]
        $stderr.puts "Warning: Need to register '#{db}' in Identifiers.org"
        @xref_warn[db] = true
      end
    end

    if hash = @rs_id.fetch(db)
      uri = "<#{hash['prefix']}#{id}>"
      puts triple(subject, "rdfs:seeAlso", uri)
      puts triple(uri, "rdfs:label", quote("#{db}:#{id}"))
      puts triple(uri, "rdf:type", "idorg:#{hash['class']}")
    else
      unless @xref_warn[db]
        $stderr.puts "Error: New database '#{db}' found. Add it to the rs_id.json file and/or Identifiers.org."
        @xref_warn[db] = true
      end
    end
  end

  ###
  ### FALDO http://biohackathon.org/faldo
  ###

  def new_location(pos, elem_type = false)
    loc_id = new_uuid

    puts triple(loc_id, "insdc:location", quote(pos))

    @locations = Bio::Locations.new(pos)
    pos_start = new_uuid
    pos_end = new_uuid
    puts triple(loc_id, "rdf:type", "faldo:Region")
    puts triple(loc_id, "faldo:begin", pos_start)
    puts triple(loc_id, "faldo:end", pos_end)
    # [TODO] need to check join(100000..1000289,1..1234) type object located over the origin
    new_position(pos_start, @locations.range.min, @locations.first.strand)
    new_position(pos_end, @locations.range.max, @locations.last.strand)

    list = []
    if elem_type
      @locations.each do |loc|
        elem_id = new_uuid
        elem_start = new_uuid
        elem_end = new_uuid
        puts triple(elem_id, "obo:so_part_of", loc_id)
        puts triple(elem_id, "rdf:type", elem_type[:id]) + "  # #{elem_type[:term]}"
        puts triple(elem_id, "rdf:type", "faldo:Region")
        puts triple(elem_id, "faldo:begin", elem_start)
        puts triple(elem_id, "faldo:end", elem_end)
        new_position(elem_start, loc.from, loc.strand)
        new_position(elem_end, loc.to, loc.strand)
        list << elem_id
      end
    end

    return loc_id, list
  end

  def new_position(pos_id, pos, strand)
    puts triple(pos_id, "faldo:position", pos)
    puts triple(pos_id, "faldo:reference", @sequence_id)
    puts triple(pos_id, "rdf:type", "faldo:ExactPosition")
    if strand > 0
      puts triple(pos_id, "rdf:type", "faldo:ForwardStrandPosition")
    else
      puts triple(pos_id, "rdf:type", "faldo:ReverseStrandPosition")
    end
  end

  ###
  ### Main
  ###

  def parse_refseq(io)
    # Read RefSeq entry
    Bio::FlatFile.auto(io).each do |entry|
      @entry = entry
      @features = entry.features
      @source = @features.shift
      parse_sequence
      parse_source
      parse_genes
      parse_cds
      parse_features
    end
  end

  ###
  ### Sequence
  ###

  # [TODO]
  # * bind sequences by BioProject ID?
  # * flag complete/draft?
  def parse_sequence
    @sequence_id = new_uuid

    # [TODO] How to identify the input is chromosome/plasmid/contig/...?
    sequence_type(@seqtype)
    # [TODO] Obtain rdfs:label from source /chromosome (eukaryotes) /plasmid (prokaryotes) -> see insdc:source_chromosome, insdc:source_plasmid
    sequence_label(@entry.definition)
    sequence_version(@entry.acc_version)
    sequence_length(@entry.nalen)
    # [TODO] provide REST API to retreive genomic DNA sequence by <@sequence_id.fasta>
    sequence_seq(@entry.acc_version)
    sequence_form(@entry.circular)
    # [TODO] sequenced date, modified in the source db or in our RDF data?
    sequence_date(@entry.date)
    # [TODO] rdfs:seeAlso (like UniProt) or dc:relation, owl:sameAs
    sequence_link_gi(@entry.gi.sub('GI:',''))
    sequence_link_accver(@entry.acc_version)
    sequence_link_bioproject(@entry.bioproject)
    # [TODO] how to deal with direct submissions (references without PMID)?
    sequence_ref(@entry.references)
  end

  def sequence_type(so = "SO:chromosome")
    case so
    when /0000340/, "SO:chromosome"
      puts triple(@sequence_id, "rdf:type", "obo:SO_0000340") + "  # SO:chromosome"
    when /0000155/, "SO:plasmid"
      puts triple(@sequence_id, "rdf:type", "obo:SO_0000155") + "  # SO:plasmid"
    when /0000736/, "SO:organelle_sequence"
      puts triple(@sequence_id, "rdf:type", "obo:SO_0000736") + "  # SO:organelle_sequence"
    when /0000819/, "SO:mitochondrial_chromosome"
      puts triple(@sequence_id, "rdf:type", "obo:SO_0000819") + "  # SO:mitochondrial_chromosome"
    when /0000740/, "SO:plastid_sequence"
      puts triple(@sequence_id, "rdf:type", "obo:SO_0000740") + "  # SO:plastid_sequence"
    when /0000719/, "SO:ultracontig"
      puts triple(@sequence_id, "rdf:type", "obo:SO_0000719") + "  # SO:ultracontig"
    when /0000148/, "SO:supercontig", "SO:scaffold"
      puts triple(@sequence_id, "rdf:type", "obo:SO_0000148") + "  # SO:supercontig/scaffold"
    when /0000149/, "SO:contig"
      puts triple(@sequence_id, "rdf:type", "obo:SO_0000149") + "  # SO:contig"
    else
      puts triple(@sequence_id, "rdf:type", "obo:SO_0000353") + "  # SO:sequence_assembly"
    end
  end

  def sequence_label(str)
    # Use "name:" key in the JSON representation
    puts triple(@sequence_id, "rdfs:label", quote(str))
  end

  def sequence_version(str)
    puts triple(@sequence_id, "insdc:sequence_version", quote(str))
  end

  def sequence_length(int)
    puts triple(@sequence_id, "insdc:sequence_length", int)
  end

  def sequence_seq(str)
    # [TODO] Where to privide the actual DNA sequence?
    fasta_uri = "<http://togows.dbcls.jp/entry/nucleotide/#{str}.fasta>"
    #fasta_uri = "<http://www.ncbi.nlm.nih.gov/nuccore/#{str}?report=fasta>"
    puts triple(@sequence_id, "insdc:sequence_fasta", fasta_uri)
  end

  def sequence_form(form)
    case form
    when "linear"
      puts triple(@sequence_id, "rdf:type", "obo:SO_0000987") + "  # SO:linear"
    when "circular"
      puts triple(@sequence_id, "rdf:type", "obo:SO_0000988") + "  # SO:circular"
    end
  end

  def sequence_date(date)
    puts triple(@sequence_id, "insdc:sequence_date", quote(usdate2date(date))+"^^xsd:date")
  end

  def sequence_link_gi(str)
    xref(@sequence_id, 'GI', str)
  end

  def sequence_link_accver(str)
    xref(@sequence_id, 'RefSeq', str)
  end

  def sequence_link_bioproject(str)
    xref(@sequence_id, 'BioProject', str)
  end

  def sequence_ref(refs)
    refs.each do |ref|
      pmid = ref.pubmed
      if pmid.length > 0
        xref(@sequence_id, 'PubMed', pmid)
      end
    end
  end

  ###
  ### Source
  ###

  def parse_source
    # Use @sequence_id for @source_id
    @source_id = @sequence_id

    hash = @source.to_hash
    source_location(@source.position)
    source_link(hash["db_xref"])
    hash.delete("db_xref")
    source_qualifiers(hash)
  end

  def source_location(pos)
    loc_id, = new_location(pos)
    puts triple(@source_id, "faldo:location", loc_id)
  end

  def source_link(links)
    links.each do |link|
      db, entry_id = link.split(':', 2)
      xref(@source_id, db, entry_id)
    end
  end

  def source_qualifiers(hash)
    hash.each do |qual, vals|
      vals.each do |val|
        if val == true
          puts triple(@source_id, "insdc:source_#{qual}", true)
        else        
          data = val.to_s.gsub(/\s+/, ' ').strip
          if data[/^\d+$/]
            puts triple(@source_id, "insdc:source_#{qual}", data)
          else
            puts triple(@source_id, "insdc:source_#{qual}", quote(data))
          end
        end
      end
    end
  end

  ###
  ### genes
  ###

  def parse_genes
    genes = @features.select {|x| x.feature == "gene"}
  
    count = 1
    genes.each do |gene|
      gene_id = new_uuid
      hash = gene.to_hash

      puts triple(gene_id, "rdf:type", "obo:SO_0000704") + "  # SO:gene"
      puts triple(gene_id, "obo:so_part_of", @sequence_id)

      loc_id, _ = new_location(gene.position)
      puts triple(gene_id, "faldo:location", loc_id)

      if hash["locus_tag"]
        locus_tag = hash["locus_tag"].first
        @locus[locus_tag] = gene_id
        puts triple(gene_id, "rdfs:label", quote(locus_tag))
      elsif hash["gene"]
        puts triple(gene_id, "rdfs:label", quote(hash["gene"].first))
      else
        # [TODO] Where else to find gene name?
        puts triple(gene_id, "rdfs:label", quote("gene#{count}"))
      end
      count += 1

      parse_qualifiers(gene_id, hash)
    end
  end

  ###
  ### CDS
  ###

  def parse_cds
    cdss = @features.select {|x| x.feature == "CDS"}

    count = 1
    cdss.each do |cds|
      cds_id = new_uuid
      hash = cds.to_hash

      puts triple(cds_id, "rdf:type", "obo:SO_0000316") + "  # SO:CDS"

      if hash["locus_tag"]
        if locus_tag = hash["locus_tag"].first
          gene_id = @locus[locus_tag]
        end
      end

      if gene_id
        puts triple(cds_id, "obo:so_part_of", gene_id)
      else
        # [TODO] sure to do this?
        puts triple(cds_id, "obo:so_part_of", @sequence_id)
      end

      if locus_tag
        puts triple(cds_id, "rdfs:label", quote(locus_tag))
      elsif hash["gene"]
        puts triple(cds_id, "rdfs:label", quote(hash["gene"].first))
      else
        puts triple(cds_id, "rdfs:label", quote("CDS#{count}"))
      end
      count += 1
      elem_type = { :id => "obo:SO_0000147", :term => "SO:exon" }
      loc_id, exons = new_location(cds.position, elem_type)
      puts triple(cds_id, "faldo:location", loc_id)
      puts triple(cds_id, "obo:so_has_part", "(#{exons.join(' ')})")  # rdf:List

      parse_qualifiers(cds_id, hash)
    end
  end

  ###
  ### Features
  ###

  def parse_features
    features = @features.select {|x| ! x.feature[/^(gene|CDS)$/]}

    features.each do |feat|
      feature = feat.feature
      feature_id = new_uuid
      hash = feat.to_hash

      puts triple(feature_id, "obo:so_part_of", @sequence_id)
      puts triple(feature_id, "rdfs:label", quote(feature))

      if so_id = @ft_so.so_id(feature)
        if so_id != "undefined"
          so = so_id.sub(':', '_')
          puts triple(feature_id, "rdf:type", "obo:#{so}") + "  # SO:#{@ft_so.so_term(feature)}"
        else
          puts triple(feature_id, "rdf:type", "obo:SO_0000110") + "  # SO:sequence_feature"
        end
      end

      loc_id, _ = new_location(feat.position)
      puts triple(feature_id, "faldo:location", loc_id)

      parse_qualifiers(feature_id, hash)
    end
  end

  def parse_qualifiers(feature_id, hash)
    hash.each do |qual, vals|
      vals.each do |val|
        if val == true
          puts triple(feature_id, "insdc:feature_#{qual}", true)
        else
          data = val.to_s.gsub(/\s+/, ' ').strip
          case qual
          when "protein_id"
            xref(feature_id, 'Protein', val)
          when "db_xref"
            db, id = val.split(':', 2)
            # ad hoc
            if db == 'InterPro' and @entry.acc_version[/(NC_010994.1|NC_014958.1|NC_015385.1|NC_015386.1|NC_015387.1|NC_015388.1|NC_015389.1)/]
              # PRJNA59115/NC_010994.1
              # PRJNA62225/NC_014958.1
              # PRJNA65781/NC_015385.1
              # PRJNA65781/plasmids/NC_015386.1
              # PRJNA65783/NC_015387.1
              # PRJNA65785/NC_015388.1
              # PRJNA65787/NC_015389.1
              #       /db_xref="InterPro:Chromosomal replication control,
              #       initiator (DnaA)/regulator (Hda"
              xref(feature_id, db, id) if id[/IPR\d+/]
            elsif db == "ASAP" and @entry.acc_version[/(NC_017263.1|NC_017264.1|NC_017265.1|NC_017266.1)/]
              # PRJNA158537/plasmids/NC_017263.1
              # PRJNA158537/plasmids/NC_017264.1
              # PRJNA158537/NC_017265.1
              # PRJNA158537/plasmids/NC_017266.1
              #       /db_xref="ASAP:BBE-0004740"
              #       /db_xref="ASAP:BBE-0004740 ERIC"
              xref(feature_id, db, id) unless id[/\s/]
            elsif db == 'TIGRFAM' and @entry.acc_version[/NC_013418.2/]
              # PRJNA41287/NC_013418.2
              #       /db_xref="TIGRFAM:TIGR00336, TIGR01740"
              #       /db_xref="TIGRFAM:TIGR00197; TF"
              if id[/,/]
                ids = id.split(',').map{|x| x.strip}
                ids.each do |x|
                  xref(feature_id, db, x)
                end
              else
                xref(feature_id, db, id.sub(/;.*/, ''))
              end
            else
              xref(feature_id, db, id)
            end
          else
            if data[/^\d+$/]
              puts triple(feature_id, "insdc:feature_#{qual}", data)
            else
              puts triple(feature_id, "insdc:feature_#{qual}", quote(data))
            end
          end
        end
      end
    end
  end

end


if __FILE__ == $0
  require 'getoptlong'

  args = GetoptLong.new(
    [ '--seqtype', '-t', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--prefixes', '-p', GetoptLong::NO_ARGUMENT ],
  )

  opts = {
    :seqtype => "SO:chromosome",
  }

  args.each_option do |name, value|
    case name
    when /--seqtype/
      opts[:seqtype] = value
    when /--prefixes/
      opts[:prefixes] = true
    end
  end

  if opts[:prefixes]
    RefSeq2RDF.new
  else
    RefSeq2RDF.new(ARGF, opts[:seqtype])
  end
end

__END__
