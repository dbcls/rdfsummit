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
### Mapping INSDC or RefSeq db_xref to Identifiers.org
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
### Mapping INSDC or RefSeq feature table to Sequence Ontology
###

# https://gist.github.com/3650401
class FT_SO
  def initialize
    @data = JSON.parse(File.read(File.dirname(__FILE__) + "/ft_so.json"))
    @data["ncRNA"] = {
      "so_id" => "SO:0000655",
      "so_term" => "ncRNA",
      "ft_desc" => "noncoding RNA",
      "so_desc" => "An RNA transcript that does not encode for a protein rather the RNA molecule is the gene product."
    }
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
### Convert INSDC or RefSeq entries to RDF
###

class INSDC2RDF

  include RDFSupport

  def initialize(io = nil, seqtype = nil)
    set_prefixes

    @seqtype = seqtype
    @rs_id = RS_ID.new
    @ft_so = FT_SO.new

    @gene = {}
    @xref_warn = {}
    @feature_count = Hash.new(0)

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
      triple("@prefix", "insdc:", "<http://ddbj.nig.ac.jp/ontologies/sequence/>"),
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
      #puts triple(uri, "rdf:type", "idorg:#{hash['class']}")
      puts triple(uri, "rdf:type", "<http://info.identifiers.org/#{db}#Entry>")
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

  def new_location(pos, subpart_type = false)

    @locations = Bio::Locations.new(pos)
    fuzzy_first = @locations.first.lt or @locations.last.gt
    fuzzy_last = @locations.last.lt or @locations.last.gt
    strand = @locations.first.strand
    
    pos_begin =position_uri_from_location_start(@locations.first)
    pos_end = position_uri_from_location_end(@locations.last)
    loc_id = "location:#{@entry.entry_id}\\\/#{@locations.first.from}t#{@locations.last.to}"

    puts triple(loc_id, "insdc:location", quote(pos))
    
    puts triple(loc_id, "rdf:type", "faldo:Region")
    puts triple(loc_id, "faldo:begin", pos_begin)
    puts triple(loc_id, "faldo:end", pos_end)
    # join(<1,60..99,161..241,302..370,436..594,676..887,993..1141,1209..1329,1387..1559,1626..1646,1708..>1843)
    # [TODO] Note that positions of an object located over the origin can be faldo:begin > faldo:end
    # e.g., join(800..900,1000..1024,1..234) will be faldo:begin 800 and faldo:end 234
    new_stranded_positions(pos_begin, pos_end, @locations.first.from, @locations.last.to, strand, fuzzy_first, fuzzy_last)

    list = []
    if subpart_type
      @locations.each do |loc|
	      puts loc.inspect
        subpart_id = new_uuid
        subpart_begin = position_uri_from_location_start(loc)
        subpart_end = position_uri_from_location_end(loc)
        puts triple(subpart_id, "obo:so_part_of", loc_id)
        puts triple(subpart_id, "rdf:type", subpart_type[:id]) + "  # #{subpart_type[:term]}"
        puts triple(subpart_id, "rdf:type", "faldo:Region")
        puts triple(subpart_id, "faldo:begin", subpart_begin)
        puts triple(subpart_id, "faldo:end", subpart_end)
        new_stranded_positions(subpart_begin, subpart_end, loc.from, loc.to, loc.strand)
        list << subpart_id
      end
    end

    return loc_id, list
  end
  
  def position_uri_from_location_start(loc)
    	"insdc:#{@entry.entry_id}\\\/position\\\/#{loc.from}.#{loc.strand}"
  end

  def position_uri_from_location_end(loc)
	"insdc:#{@entry.entry_id}\\\/position\\\/#{loc.to}.#{loc.strand}"
  end

  def new_stranded_positions(pos_begin, pos_end, from, to, strand, fuzzy_from = nil, fuzzy_to = nil)
    if strand > 0
      new_position(pos_begin, from, "faldo:ForwardStrandPosition", fuzzy_from)
      new_position(pos_end, to, "faldo:ForwardStrandPosition", fuzzy_to)
    else
      new_position(pos_begin, to, "faldo:ReverseStrandPosition", fuzzy_to)
      new_position(pos_end, from, "faldo:ReverseStrandPosition", fuzzy_from)
    end
  end

  def new_position(pos_id, pos, strand, fuzzy = nil)
    puts triple(pos_id, "faldo:position", pos)
    puts triple(pos_id, "faldo:reference", "<http://togows.org/entry/nucleotide/#{@entry.acc_version}.fasta>")
    if fuzzy
      puts triple(pos_id, "rdf:type", "faldo:FuzzyPosition")
    else
      puts triple(pos_id, "rdf:type", "faldo:ExactPosition")
    end
    puts triple(pos_id, "rdf:type", strand)
  end

  ###
  ### Main
  ###

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
  # * bind sequences by BioProject ID?
  # * flag complete/draft?
  def parse_sequence
    @sequence_id = "insdc:" + @entry.entry_id

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
    if bioproject = @entry.bioproject
      sequence_link_bioproject(bioproject)
    elsif project = @entry.project
      sequence_link_bioproject("PRJNA#{project}")
    end
    if biosample = @entry.biosample
      sequence_link_biosample(biosample)
    end
    # [TODO] how to deal with direct submissions (references without PMID)?
    sequence_ref(@entry.references)
  end

  def sequence_type(so = "SO:sequence")
    case so
    when /0000001/, "SO:region", "SO:sequence"
      puts triple(@sequence_id, "rdf:type", "obo:SO_0000001") + "  # SO:sequence"
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
    fasta_uri = "<http://togows.org/entry/nucleotide/#{str}.fasta>"
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

  def sequence_link_accver(str, source_db = 'RefSeq')
    # [TODO] distinguish RefSeq/GenBank/DDBJ entries by the prefix of accession IDs
    # [TODO] register GenBank/DDBJ in rs_id.json to enable the above
    # [TODO] rewrite parse_entry and subsequent methods to use Bio::Sequence for EMBL support
    xref(@sequence_id, source_db, str)
  end

  def sequence_link_bioproject(str)
    id_pfx = "http://identifiers.org/bioproject"
    xref_id = "<#{id_pfx}/#{str}>"
    puts triple(@sequence_id, 'insdc:dblink', xref_id)
    puts triple(xref_id, 'rdfs:label', quote(str))
    puts triple(xref_id, 'rdf:type', "<#{id_pfx}#Entry>")
  end

  def sequence_link_biosample(str)
    id_pfx = "http://identifiers.org/biosample"
    xref_id = "<#{id_pfx}/#{str}>"
    xred_type = "<#{id_pfx}#Entry>"
    puts triple(@sequence_id, 'insdc:dblink', xref_id)
    puts triple(xref_id, 'rdfs:label', quote(str))
    puts triple(xred_id, 'rdf:type', xref_type)
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
          puts triple(@source_id, "insdc:#{qual}", true)
        else        
          data = val.to_s.gsub(/\s+/, ' ').strip
          if data[/^\d+$/]
            puts triple(@source_id, "insdc:#{qual}", data)
          else
            puts triple(@source_id, "insdc:#{qual}", quote(data))
          end
        end
      end
    end
  end

  ###
  ### Genes
  ###

  def parse_genes
    genes = @features.select {|x| x.feature == "gene"}
  
    genes.each do |gene|
      gene_id = new_uuid
      hash = gene.to_hash

      puts triple(gene_id, "rdf:type", "obo:SO_0000704") + "  # SO:gene"
      puts triple(gene_id, "obo:so_part_of", @sequence_id)

      loc_id, _ = new_location(gene.position)
      puts triple(gene_id, "faldo:location", loc_id)

      if hash["locus_tag"]
        locus_tag = hash["locus_tag"].first
        @gene[locus_tag] = gene_id
        puts triple(gene_id, "rdfs:label", quote(locus_tag))
      elsif hash["gene"]
        gene = hash["gene"].first
        @gene[gene] = gene_id
        puts triple(gene_id, "rdfs:label", quote(gene))
      else
        # [TODO] Where else to find gene name?
      end
      parse_qualifiers(gene_id, hash)
    end
  end

  ###
  ### Features (part of gene: CDS, mRNA, misc_RNA, precursor_RNA, ncRNA, tRNA, rRNA)
  ###

  def parse_features
    features = @features.select {|x| x.feature != "gene" }

    features.each do |feat|
      feature_id = new_uuid
      hash = feat.to_hash

      feature = feat.feature
      @feature_count[feature] += 1

      case feature
      when "CDS"
        puts triple(feature_id, "rdf:type", "obo:SO_0000316") + "  # SO:CDS"
      when "mRNA"
        puts triple(feature_id, "rdf:type", "obo:SO_0000234") + "  # SO:mRNA"
      when "misc_RNA"
        puts triple(feature_id, "rdf:type", "obo:SO_0000673") + "  # SO:transcript"
      when "precursor_RNA"
        puts triple(feature_id, "rdf:type", "obo:SO_0000185") + "  # SO:primary_transcript"
      when "ncRNA"
        puts triple(feature_id, "rdf:type", "obo:SO_0000655") + "  # SO:ncRNA"
      when "tRNA"
        puts triple(feature_id, "rdf:type", "obo:SO_0000253") + "  # SO:tRNA"
      when "rRNA"
        puts triple(feature_id, "rdf:type", "obo:SO_0000252") + "  # SO:rRNA"
      else
        if so_id = @ft_so.so_id(feature)
          if so_id != "undefined"
            so = so_id.sub(':', '_')
            puts triple(feature_id, "rdf:type", "obo:#{so}") + "  # SO:#{@ft_so.so_term(feature)}"
          else
            puts triple(feature_id, "rdf:type", "obo:SO_0000110") + "  # SO:sequence_feature"
          end
        end
      end

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

      puts triple(feature_id, "rdfs:label", quote(locus_tag || gene || feature))
      puts triple(feature_id, "obo:so_part_of", gene_id || @sequence_id)

      if gene_id
        subpart_type = { :id => "obo:SO_0000147", :term => "SO:exon" }
      else
        subpart_type = { :id => "obo:SO_0000001", :term => "SO:region" }
      end

      loc_id, subparts = new_location(feat.position, subpart_type)
      puts triple(feature_id, "faldo:location", loc_id)
      unless subparts.empty?
        puts triple(feature_id, "obo:so_has_part", "(#{subparts.join(' ')})")  # rdf:List
      end

      parse_qualifiers(feature_id, hash)
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
    [ '--seqtype', '-t', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--prefixes', '-p', GetoptLong::NO_ARGUMENT ],
  )

  opts = {
    :seqtype => "SO:sequence",
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
    INSDC2RDF.new
  else
    INSDC2RDF.new(ARGF, opts[:seqtype])
  end
end

__END__
