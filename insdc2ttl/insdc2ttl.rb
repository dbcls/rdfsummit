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

    def project
      dblink[/Project: (\d+)/, 1]
    end

    def bioproject
      dblink[/BioProject: (\S+)/, 1]
    end

    def biosample
      dblink[/BioSample: (\S+)/, 1]
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
      triple("@prefix", "skos:", "<http://www.w3.org/2004/02/skos/core#>"),
      triple("@prefix", "sio:", "<http://semanticscience.org/resource/>"),
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
### Mapping of INSDC or RefSeq db_xref to Identifiers.org URI
###

# https://gist.github.com/3985701
# https://gist.github.com/4146256
class RS_ID
  include RDFSupport

  def initialize
    @rs_id = JSON.parse(File.read(File.dirname(__FILE__) + "/rs_id.json"))
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
### Mapping of INSDC or RefSeq feature table to Sequence Ontology
###

# https://gist.github.com/3650401
class FT_SO
  def initialize
    @data = JSON.parse(File.read(File.dirname(__FILE__) + "/ft_so.json"))
  end

  # ftso = FT_SO.new
  # puts ftso.so_id("-10_signal")  # => "SO:0000175"
  def so_id(feature)
    if hash = @data[feature]
      return hash["so_id"]
    end
  end

  # puts ftso.so_id("-10_signal")  # => "obo:SO_0000175"
  def obo_id(feature)
    return "obo:" + so_id(feature).sub(':', '_')
  end

  # puts ftso.so_term("-10_signal")  # => "minus_10_signal"
  def so_term(feature)
    if hash = @data[feature]
      return hash["so_term"]
    end
  end

  # puts ftso.so_desc("-10_signal")  # => "A conserved region about 10-bp upstream of ..."
  def so_desc(feature)
    if hash = @data[feature]
      return hash["so_desc"]
    end
  end

  # puts ftso.ft_desc("-10_signal")  # => "Pribnow box; a conserved region about 10 bp upstream of ..."
  def ft_desc(feature)
    if hash = @data[feature]
      return hash["ft_desc"]
    end
  end

  def ft_id(feature)
    if hash = @data[feature]
      return hash["ft_id"]
    end
  end
end

###
### Convert INSDC or RefSeq entries to RDF
###

class INSDC2RDF

  include RDFSupport

  def initialize(io = nil, opts = nil)
    @datasource = opts[:datasource]
    @seqtype = opts[:seqtype]
    @rs_id = RS_ID.new
    @ft_so = FT_SO.new

    case @datasource
    when /RefSeq/i
      @entry_prefix = "http://identifiers.org/refseq/"
    else # /INSDC|GenBank|ENA|DDBJ/i
      @entry_prefix = "http://identifiers.org/insdc/"
    end

    @gene = {}
    @xref_warn = {}
    @feature_count = Hash.new(0)

    set_prefixes

    puts prefix
    puts

    parse_entry(io) if io
  end

  attr_accessor :prefix

  def self.prefixes
    puts prefix
  end

  def set_prefixes
    @prefix = default_prefix + [
      #triple("@prefix", "genome:", "<http://purl.jp/bio/10/genome/>"),
      #triple("@prefix", "insdc:", "<http://insdc.org/owl/>"),
      triple("@prefix", "insdc:", "<http://ddbj.nig.ac.jp/ontologies/nucleotide/>"),
    ]
  end

  def xref(subject, db, id)
    case db
    when "GI"
      id = "GI:#{id}"
    when "HOMD"
      id.sub!(/^tax_/, '')
    when "ECOCYC"
      #id = "ECOCYC:#{id}"
    when "ERIC", "HMP", "PSEUDO", "Pathema"
      unless @xref_warn[db]
        $stderr.puts "Warning: Need to register '#{db}' in Identifiers.org"
        @xref_warn[db] = true
      end
    end

    if hash = @rs_id.fetch(db)
      uri = "<#{hash['prefix']}/#{id}>"
      puts triple(subject, "rdfs:seeAlso", uri)
      puts triple(uri, "rdfs:label", quote(id))
      puts triple(uri, "rdf:type", "insdc:#{hash['class']}")
      puts triple(uri, "sio:SIO_000068", "<#{hash['prefix']}>") + "  # sio:is-part-of"
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

  def new_feature_uri(feature, from, to, strand, count = false)
    if count
      "<#{@sequence_id}#feature:#{from}-#{to}:#{strand}:#{feature}.#{count}>"
    else
      "<#{@sequence_id}#feature:#{from}-#{to}:#{strand}:#{feature}>"
    end
  end

  def new_region_uri(from, to, strand)
    "<#{@sequence_id}#region:#{from}-#{to}:#{strand}>"
  end

  def new_position_uri(pos, strand)
    "<#{@sequence_id}#position:#{pos}:#{strand}>"
  end

  def new_location(object, pos)
    puts triple(object, "insdc:location", quote(pos))
    locations = Bio::Locations.new(pos)

    # [TODO] annotation located over the origin of a circular genome can be faldo:begin > faldo:end even in ForwardStrandPosition
    # e.g., join(800..900,1000..1024,1..234) will be faldo:begin 800 and faldo:end 234
    min, max = locations.span
    strand = locations.first.strand
    if strand > 0
      fuzzy_min = locations.first.lt
      fuzzy_max = locations.last.gt
      strand_min = locations.first.strand
      strand_max = locations.last.strand
    else
      fuzzy_min = locations.last.lt
      fuzzy_max = locations.first.gt
      strand_min = locations.last.strand
      strand_max = locations.first.strand
    end
    region_id = new_faldo_region(object, min, max, strand_min, strand_max, fuzzy_min, fuzzy_max)

    return region_id, locations
  end

  def add_subparts(locations, feature_type)
    count = 1
    sub_parts = []
    sub_ordered_parts = []
    locations.each do |loc|
      subpart_id = new_uuid
      subfeature_id = new_feature_uri(feature_type[:term], loc.from, loc.to, loc.strand)

      #puts triple(subpart_id, "obo:so_part_of", region_id)
      puts triple(subpart_id, "sio:SIO_000300", count) + "  # sio:has-value"
      puts triple(subpart_id, "sio:SIO_000628", subfeature_id) + "  # sio:referes-to"
      puts triple(subfeature_id, "rdf:type", "insdc:#{feature_type[:ft]}")
      puts triple(subfeature_id, "rdfs:subClassOf", feature_type[:id]) + "  # SO:#{feature_type[:term]}"
      new_faldo_region(subfeature_id, loc.from, loc.to, loc.strand, loc.strand, loc.lt, loc.gt)
      sub_parts << subfeature_id
      sub_ordered_parts << subpart_id
      count += 1
    end
    return [sub_parts, sub_ordered_parts]
  end

  def new_faldo_region(object, min, max, strand_min, strand_max, fuzzy_min = nil, fuzzy_max = nil)
    region_id = new_region_uri(min, max, strand_min)
    region_min = new_position_uri(min, strand_min)
    region_max = new_position_uri(max, strand_max)

    puts triple(object, "faldo:location", region_id)
    puts triple(region_id, "rdf:type", "faldo:Region")
    if strand_min > 0
      puts triple(region_id, "faldo:begin", region_min)
      puts triple(region_id, "faldo:end", region_max)
      new_faldo_position(region_min, min, "faldo:ForwardStrandPosition", fuzzy_min)
      new_faldo_position(region_max, max, "faldo:ForwardStrandPosition", fuzzy_max)
    else
      puts triple(region_id, "faldo:begin", region_max)
      puts triple(region_id, "faldo:end", region_min)
      new_faldo_position(region_min, min, "faldo:ReverseStrandPosition", fuzzy_min)
      new_faldo_position(region_max, max, "faldo:ReverseStrandPosition", fuzzy_max)
    end

    return region_id
  end

  def new_faldo_position(pos_id, pos, strand, fuzzy = nil)
    puts triple(pos_id, "faldo:position", pos)
    puts triple(pos_id, "faldo:reference", @sequence_uri)
    puts triple(pos_id, "rdf:type", strand)
    if fuzzy
      puts triple(pos_id, "rdf:type", "faldo:FuzzyPosition")
    else
      puts triple(pos_id, "rdf:type", "faldo:ExactPosition")
    end
  end

  ###
  ### Main
  ###

  # [TODO] rewrite parse_entry and subsequent methods to use Bio::Sequence for EMBL support
  def parse_entry(io)
    # Read INSDC or RefSeq entry
    Bio::FlatFile.auto(io).each do |entry|
      @entry = entry
      @features = entry.features
      @source = @features.shift
      parse_sequence
      parse_source
      parse_genes
      parse_features
    end
  end

  ###
  ### Sequence
  ###

  # [TODO]
  # * bind multiple sequences by BioProject ID?
  # * add a flag for sequencing status representing complete/draft?
  def parse_sequence
    @sequence_id = "#{@entry_prefix}#{@entry.acc_version}"
    @sequence_uri = "<#{@sequence_id}#sequence>"
    @entry_uri = "<#{@sequence_id}>"

    puts triple(@entry_uri, "rdf:type", "insdc:Entry")

    # [TODO] obtain rdfs:label from source /chromosome (eukaryotes) /plasmid (prokaryotes) -> see insdc:source_chromosome, insdc:source_plasmid
    sequence_label(@entry.definition)
    sequence_version(@entry.acc_version)
    # [TODO] sequenced date: updated date in the source DB or generation date of the RDF data?
    sequence_date(@entry.date)
    # [TODO] find appropriate REST URI to retreive genomic DNA sequence by <@sequence_id.fasta>
    sequence_seq(@entry.acc_version)
    # [TODO] how to automatically identify the input is chromosome/plasmid/contig/...?
    sequence_type(@seqtype)
    sequence_length(@entry.nalen)
    sequence_form(@entry.circular)
    sequence_division(@entry.division)
    # [TODO] rdfs:seeAlso (like UniProt) or dc:relation, owl:sameAs
    if @entry.gi[/GI:/]
      sequence_link_gi(@entry.gi.sub('GI:',''))
    end
    sequence_link_accession(@entry.accession, @datasource)
    sequence_link_accver(@entry.acc_version, @datasource)
    if bioproject = @entry.bioproject
      sequence_link_bioproject(bioproject)
    elsif project = @entry.project
      sequence_link_bioproject("PRJNA#{project}")
    end
    if biosample = @entry.biosample
      sequence_link_biosample(biosample)
    end
    sequence_keywords(@entry.keywords)
    sequence_source(@entry.source)
    # [TODO] how to deal with direct submissions (references without PMID)?
    sequence_references(@entry.references)
    sequence_comment(@entry.comment)
  end

  def sequence_type(so = "SO:sequence")
    case so
    when /0000001/, "SO:region", "SO:sequence"
      puts triple(@sequence_uri, "rdfs:subClassOf", "obo:SO_0000001") + "  # SO:sequence"
    when /0000340/, "SO:chromosome"
      puts triple(@sequence_uri, "rdfs:subClassOf", "obo:SO_0000340") + "  # SO:chromosome"
    when /0000155/, "SO:plasmid"
      puts triple(@sequence_uri, "rdfs:subClassOf", "obo:SO_0000155") + "  # SO:plasmid"
    when /0000736/, "SO:organelle_sequence"
      puts triple(@sequence_uri, "rdfs:subClassOf", "obo:SO_0000736") + "  # SO:organelle_sequence"
    when /0000819/, "SO:mitochondrial_chromosome"
      puts triple(@sequence_uri, "rdfs:subClassOf", "obo:SO_0000819") + "  # SO:mitochondrial_chromosome"
    when /0000740/, "SO:plastid_sequence"
      puts triple(@sequence_uri, "rdfs:subClassOf", "obo:SO_0000740") + "  # SO:plastid_sequence"
    when /0000719/, "SO:ultracontig"
      puts triple(@sequence_uri, "rdfs:subClassOf", "obo:SO_0000719") + "  # SO:ultracontig"
    when /0000148/, "SO:supercontig", "SO:scaffold"
      puts triple(@sequence_uri, "rdfs:subClassOf", "obo:SO_0000148") + "  # SO:supercontig/scaffold"
    when /0000149/, "SO:contig"
      puts triple(@sequence_uri, "rdfs:subClassOf", "obo:SO_0000149") + "  # SO:contig"
    else
      puts triple(@sequence_uri, "rdfs:subClassOf", "obo:SO_0000353") + "  # SO:sequence_assembly"
    end
  end

  def sequence_label(str)
    # Use "name:" key in the JSON representation
    puts triple(@entry_uri, "insdc:definition", quote(str))
    puts triple(@entry_uri, "rdfs:label", quote(str))
  end

  def sequence_version(str)
    puts triple(@entry_uri, "insdc:sequence_version", quote(str))
  end

  def sequence_length(int)
    puts triple(@sequence_uri, "insdc:sequence_length", int)
  end

  def sequence_seq(entry_id)
    puts triple(@entry_uri, "insdc:sequence", @sequence_uri)
    # [TODO] where to obtain the actual DNA sequence? in what format?
    #puts triple(@sequence_uri, "rdfs:seeAlso", "<http://togows.org/entry/nucleotide/#{entry_id}.fasta>")
    puts triple(@sequence_uri, "rdfs:seeAlso", "<http://www.ncbi.nlm.nih.gov/nuccore/#{entry_id}?report=fasta>")
    case @datasource
    when /INSDC|GenBank|ENA|DDBJ/i
      #puts triple(@sequence_uri, "rdfs:seeAlso", "<http://togows.org/entry/embl/#{entry_id}.fasta>")
      puts triple(@sequence_uri, "rdfs:seeAlso", "<http://www.ebi.ac.uk/ena/data/view/#{entry_id}&display=fasta>")
      #puts triple(@sequence_uri, "rdfs:seeAlso", "<http://togows.org/entry/ddbj/#{entry_id}.fasta>")
      puts triple(@sequence_uri, "rdfs:seeAlso", "<http://getentry.ddbj.nig.ac.jp/getentry/na/#{entry_id}?format=fasta>")
    end
  end

  def sequence_form(form)
    case form
    when "linear"
      puts triple(@sequence_uri, "insdc:topology", "insdc:linear")
      puts triple(@sequence_uri, "obo:so_has_quality", "obo:SO_0000987") + "  # SO:linear"
    when "circular"
      puts triple(@sequence_uri, "insdc:topology", "insdc:circular")
      puts triple(@sequence_uri, "obo:so_has_quality", "obo:SO_0000988") + "  # SO:circular"
    end
  end

  def sequence_division(division)
    # [TODO] Change to use classes which will be defined in INSDC/DDBJ ontology
    puts triple(@entry_uri, 'insdc:division', "insdc:Division\\##{division}")
  end

  def sequence_date(date)
    puts triple(@entry_uri, "insdc:sequence_date", quote(usdate2date(date))+"^^xsd:date")
  end

  def sequence_link_gi(str)
    xref(@entry_uri, 'GI', str)
  end

  def sequence_link_accession(str, source_db = 'RefSeq')
    xref(@entry_uri, source_db, str)
  end

  def sequence_link_accver(str, source_db = 'RefSeq')
    # [TODO] automatically distinguish RefSeq/GenBank/DDBJ entries by the prefix of accession IDs?
    # [TODO] register GenBank/DDBJ in rs_id.json to enable the above
    xref(@entry_uri, source_db, str)
  end

  def sequence_link_bioproject(str)
    id_pfx = "http://identifiers.org/bioproject"
    xref_id = "<#{id_pfx}/#{str}>"
    puts triple(@entry_uri, 'insdc:dblink', xref_id)
    puts triple(xref_id, 'rdfs:label', quote(str))
    puts triple(xref_id, 'rdf:type', "insdc:BioProject")
    puts triple(xref_id, 'sio:SIO_000068', "<#{id_pfx}>") + "  # sio:is-part-of"
  end

  def sequence_link_biosample(str)
    id_pfx = "http://identifiers.org/biosample"
    xref_id = "<#{id_pfx}/#{str}>"
    puts triple(@entry_uri, 'insdc:dblink', xref_id)
    puts triple(xref_id, 'rdfs:label', quote(str))
    puts triple(xref_id, 'rdf:type', "insdc:BioSample")
    puts triple(xred_id, 'sio:SIO_000068', "<#{id_pfx}>") + "  # sio:is-part-of"
  end

  def sequence_keywords(keywords)
    # [TODO] change to use controlled vocabulary in the INSDC/DDBJ ontology
    keywords.each do |keyword|
      name = quote(keyword).sub(/^"/, '').sub(/"$/, '')
      puts triple(@entry_uri, 'insdc:keyword', "insdc:Keyword\\##{name}")
    end
  end

  def sequence_source(source)
    puts triple(@entry_uri, 'insdc:source', quote(source["common_name"]))
    puts triple(@entry_uri, 'insdc:organism', quote(source["organism"]))
    puts triple(@entry_uri, 'insdc:taxonomy', quote(source["taxonomy"]))
  end

  def sequence_references(references)
    count = 1
    references.each do |ref|
      @reference_uri = new_reference_uri(count)
      puts triple(@entry_uri, 'insdc:reference', @reference_uri)
      puts triple(@reference_uri, 'sio:SIO_000300', count) + "  # sio:has-value"
      puts triple(@reference_uri, 'insdc:reference\\#title', quote(ref.title)) if ref.title
      ref.authors.each do |author|
        puts triple(@reference_uri, 'insdc:reference\\#author', quote(author)) if author
      end
      puts triple(@reference_uri, 'insdc:reference\\#journal', quote(ref.journal)) if ref.journal
      puts triple(@reference_uri, 'insdc:reference\\#volume', quote(ref.volume)) unless ref.volume.to_s.empty?
      puts triple(@reference_uri, 'insdc:reference\\#issue', quote(ref.issue)) unless ref.issue.to_s.empty?
      puts triple(@reference_uri, 'insdc:reference\\#pages', quote(ref.pages)) unless ref.pages.to_s.empty?
      puts triple(@reference_uri, 'insdc:reference\\#year', quote(ref.year)) unless ref.year.to_s.empty?
      puts triple(@reference_uri, 'insdc:reference\\#medline', quote(ref.medline)) unless ref.medline.to_s.empty?
      puts triple(@reference_uri, 'insdc:reference\\#pubmed', quote(ref.pubmed)) unless ref.pubmed.to_s.empty?
      ref.comments.each do |comment|
        puts triple(@reference_uri, 'insdc:reference\\#comments', quote(comment)) unless comment.to_s.empty?
      end if ref.comments
      if pmid = ref.pubmed
        if pmid.length > 0
          xref(@entry_uri, 'PubMed', pmid)
        end
      end
      count += 1
    end
  end

  def new_reference_uri(count)
    "<#{@sequence_id}#reference.#{count}>"
  end

  def sequence_comment(comment)
    puts triple(@entry_uri, 'insdc:comment', quote(comment))
  end

  ###
  ### Source
  ###

  def parse_source
    hash = @source.to_hash
    region_id, locations = source_location(@source.position)
    from, to = locations.span
    @source_uri = new_feature_uri(@source.feature, from, to, locations.first.strand)

    source_link(hash["db_xref"])
    hash.delete("db_xref")
    source_qualifiers(hash)
  end

  def source_location(pos)
    new_location(@sequence_uri, pos)
  end

  def source_link(links)
    links.each do |link|
      db, entry_id = link.split(':', 2)
      xref(@source_uri, db, entry_id)
      if db == "taxon"
        @taxonomy_id = entry_id
        puts triple(@sequence_uri, "obo:RO_0002162", "<http://identifiers.org/taxonomy/#{@taxonomy_id}>") + "  # RO:in taxon"
      end
    end
  end

  def source_qualifiers(hash)
    hash.each do |qual, vals|
      vals.each do |val|
        if val == true
          puts triple(@source_uri, "insdc:#{qual}", true)
        else        
          data = val.to_s.gsub(/\s+/, ' ').strip
          if data[/^\d+$/]
            puts triple(@source_uri, "insdc:#{qual}", data)
          else
            puts triple(@source_uri, "insdc:#{qual}", quote(data))
          end
        end
      end
    end
  end

  ###
  ### Genes
  ###

  # parse genes first to collect gene IDs for mRNA, CDS etc. (then parse rest of features)
  def parse_genes
    genes = @features.select {|x| x.feature == "gene"}
  
    genes.each do |gene|
      @feature_count[gene.feature] += 1
      locations = Bio::Locations.new(gene.position)
      from, to = locations.span
      gene_id = new_feature_uri("gene", from, to, locations.first.strand, @feature_count[gene.feature])
      hash = gene.to_hash

      # try to cache gene IDs in the @gene hash for linking with other features (CDS, mRNA etc.)
      if hash["locus_tag"]
        locus_tag = hash["locus_tag"].first
        @gene[locus_tag] = gene_id
      elsif hash["gene"]
        gene = hash["gene"].first
        @gene[gene] = gene_id
      else
        # [TODO] where else to find gene name?
      end
    end
  end

  ###
  ### Features (part of gene: CDS, mRNA, misc_RNA, precursor_RNA, ncRNA, tRNA, rRNA)
  ###

  def parse_features
    @features.each do |feat|
      feature = feat.feature
      position = feat.position

      # try to link gene-related features (CDS, mRNA etc.) by matching /locus_tag or /gene qualifier values
      hash = feat.to_hash
      gene_id = locus_tag = gene = nil
      if hash["locus_tag"]
        if locus_tag = hash["locus_tag"].first
          gene_id = @gene[locus_tag]
        end
      elsif hash["gene"]
        if gene = hash["gene"].first
          gene_id = @gene[gene]
        end
      end

      # re-use URI for genes otherwise generate new URI
      if feature == "gene"
        feature_id = gene_id
      else
        @feature_count[feature] += 1
        locations = Bio::Locations.new(position)
        min, max = locations.span
        strand = locations.first.strand
        feature_id = new_feature_uri(feature, min, max, strand, @feature_count[feature])
      end

      # add type by Sequence Ontology
      so_id = "SO:0000001"
      so_obo_id = "obo:SO_0000001"
      so_term = "region"
      ft_id = "Feature"
      if so_id = @ft_so.so_id(feature)
        if so_id != "undefined"
          so_obo_id = @ft_so.obo_id(feature)
          so_term = @ft_so.so_term(feature)
          ft_id = @ft_so.ft_id(feature)
        end
      end

      # feature types and labels
      puts triple(feature_id, "rdf:type", "insdc:#{ft_id}")
      puts triple(feature_id, "rdfs:subClassOf", so_obo_id) + "  # SO:#{so_term}"
      # to make compatible with Ensembl RDF
      puts triple(feature_id, "obo:RO_0002162", "<http://identifiers.org/taxonomy/#{@taxonomy_id}>") + "  # RO:in taxon"
      puts triple(feature_id, "rdfs:label", quote(locus_tag || gene || feature))
      if locus_tag || gene
        puts triple(feature_id, "skos:prefLabel", quote(locus_tag || gene))
        if hash["gene_synonym"]
          hash["gene_synonym"].first.split(/;\s+/).each do |synonym|
            puts triple(feature_id, "skos:altLabel", quote(synonym))
          end
        end
      end

      # feature qualifiers
      parse_qualifiers(feature_id, hash)

      # parent-child relationship (gene -> mRNA|CDS|misc_RNA etc.)
      parent_uri = @sequence_uri
      if gene_id and gene_id != feature_id
        parent_uri = gene_id
        puts triple(feature_id, "sio:SIO_010081", gene_id) + "  # sio:is-transcribed-from"
        # to make compatible with Ensembl RDF
        puts triple(feature_id, "rdfs:subClassOf", "obo:SO_0000673") + "  # SO:transcript"
        puts triple(gene_id, "rdfs:subClassOf", "obo:SO_0000010") + "  # SO:protein_coding"
      end
      puts triple(feature_id, "obo:so_part_of", parent_uri)

      # add FALDO location and subparts (exons etc.)
      region_id, locations = new_location(feature_id, position)
      if locations.count > 1
        if gene_id
          # link to exons in join(exon1, exon2, ...)
          feature_type = { :id => "obo:SO_0000147", :term => "exon", :ft => "Exon" }
        else
          # [TODO] need to confirm that if there are any features having subparts other than exons
          feature_type = { :id => "obo:SO_0000001", :term => "region", :ft => "Feature" }
        end
        sub_parts, sub_ordered_parts = add_subparts(locations, feature_type)
        #puts triple(feature_id, "obo:so_has_part", "(#{sub_parts.join(' ')})")  # rdf:List
        # exon URIs
        puts triple(feature_id, "obo:so_has_part", sub_parts.join(', '))
        # part URIs
        puts triple(feature_id, "sio:SIO_000974", sub_ordered_parts.join(', ')) + "  # sio:has-ordered-part"
      end
    end
    $stderr.puts "Features: #{@feature_count.to_json}"
  end

  def parse_qualifiers(feature_id, hash)
    hash.each do |qual, vals|
      vals.each do |val|
        if val == true
          puts triple(feature_id, "insdc:#{qual}", true)
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
              puts triple(feature_id, "insdc:#{qual}", data)
            else
              puts triple(feature_id, "insdc:#{qual}", quote(data))
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
    [ '--datasource', '-d', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--seqtype', '-t', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--prefixes', '-p', GetoptLong::NO_ARGUMENT ],
  )

  opts = {
    :seqtype => "SO:sequence",
    :datasource => "insdc",     # Can be RefSeq, INSDC, GenBank, ENA, DDBJ
  }

  args.each_option do |name, value|
    case name
    when /--datasource/
      opts[:datasource] = value
    when /--seqtype/
      opts[:seqtype] = value
    when /--prefixes/
      opts[:prefixes] = true
    end
  end

  if opts[:prefixes]
    INSDC2RDF.new
  else
    INSDC2RDF.new(ARGF, opts)
  end
end

__END__
