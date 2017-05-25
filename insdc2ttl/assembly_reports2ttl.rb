#!/usr/bin/env ruby
#
# convert assembly_reprots to RDF
# * ftp://ftp.ncbi.nlm.nih.gov/genomes/ASSEMBLY_REPORTS/assembly_summary_refseq.txt
#
# [w3sw@t262 cron]$ vi ~/tf/rdfsummit/insdc2ttl/assembly_reports2ttl.rb
# ruby ~/tf/rdfsummit/insdc2ttl/assembly_reports2ttl.rb ~/rdf/linksets/data ~/rdf/linksets/rdf


#["assembly_accession", "GCF_000001215.2"]
#["bioproject", "PRJNA164"]
#["biosample", "na"]
#["wgs_master", "AABU00000000.1"]
#["refseq_category", "representative-genome"]
#["taxid", "7227"]
#["species_taxid", "7227"]
#["organism_name", "Drosophila melanogaster"]
#["infraspecific_name", "na"]
#["isolate", "na"]
#["version_status", "latest"]
#["assembly_level", "Chromosome"]
#["release_type", "Major"]
#["genome_rep", "Full"]
#["seq_rel_date", "2007/10/22"]
#["asm_name", "Release 5"]
#["submitter", "The FlyBase Consortium/Berkeley Drosophila Genome Project/Celera Genomics"]
#["gbrs_paired_asm", "GCA_000001215.2"]
#["paired_asm_comp", "different"]

require "fileutils"
require 'pp'

class AssemblyReports2RDF

  attr_accessor :status

  def initialize input,output 
    @root_path = input 
    @out_path  = output
    @status = Hash.new{|h,k|h[k]=0}
    #output_prefix f
    @paths =[]
    datasets.each do |key, dataset|
      @source = dataset[:source]
      @idtype = dataset[:idtype]
      @reports =[]
      @out_summary=dataset[:outpath]
      parse_summary "#{@root_path}/#{dataset[:path]}"
      output_summary
    end
    @paths.each do |path|
       #puts path
       output_each_assembly path
    end
  end

  def datasets
     {:insdc =>
         { name: 'INSDC',
           path: 'genomes/ASSEMBLY_REPORTS/assembly_summary_genbank.txt',
           outpath: 'genomes/ASSEMBLY_REPORTS/assembly_summary_genbank.ttl',
           source: 'assembly_summary_genbank.txt',
           idtype: 'insdc'
         },
      :refseq =>
         { name: 'RefSeq',
           path: 'genomes/ASSEMBLY_REPORTS/assembly_summary_refseq.txt',
           outpath: 'genomes/ASSEMBLY_REPORTS/assembly_summary_refseq.ttl',
           source: 'assembly_summary_refseq.txt',
           idtype: 'refseq'
         }
     }
  end

  def parse_summary file_path 
    head = []
    File.readlines("#{file_path}",:encoding =>'UTF-8').each_with_index do |line,i|
      if i == 0  # description row
      elsif i == 1
        head =line.strip.gsub("\r","").gsub(/^#/,"").strip.split("\t")
      else
        @reports << head.zip(line.strip.split("\t")).inject({}){|h,col| h[col[0]]=col[1];h}
      end
    end
  end

  def output_each_assembly base_path
    # base_path = project['ftp_path'].sub('ftp://ftp.ncbi.nlm.nih.gov/', '')
    basename = File.basename(base_path)
    subject = "http://ddbj.nig.ac.jp/#{base_path}"
    stats_filepath = "#{@root_path}/#{base_path}/#{basename}_assembly_stats.txt"
    report_filepath ="#{@root_path}/#{base_path}/#{basename}_assembly_report.txt"
    if FileTest.exist?(report_filepath) and FileTest.exist?(stats_filepath) 
      #out_file = "#{@out_path}/#{base_path}/#{basename}.ttl"
      out_dir  = "#{@out_path}/#{File.dirname(base_path)}"
      FileUtils.mkdir_p(out_dir) unless FileTest.exist?(out_dir)
      out_file = "#{@out_path}/#{base_path}.ttl"
      puts out_file

      File.open(out_file,"w") do |f|
        f.puts output_prefix_common
        f.puts
        f.puts "<#{subject}>"
        File.readlines(stats_filepath, :encoding =>'UTF-8').each_with_index do |line,i|
          next if line =~/^#/
          unit_name, molecule_name, molecule_type_loc, sequence_type, statistic, value = line.strip.split("\t")
          if unit_name == 'all' and molecule_name == 'all' and  molecule_type_loc == 'all' and sequence_type == 'all'
            #pp [statistic, value]
            f.puts "\t\tasm:#{statistic}\t#{value} ;"
          end
        end

        File.readlines(report_filepath, :encoding =>'UTF-8').each_with_index do |line,i|
          next if line =~/^#/
          # Sequence-Name Sequence-Role   Assigned-Molecule       Assigned-Molecule-Location/Type GenBank-Accn    Relationship    RefSeq-Accn     Assembly-Unit
          sequence_name, sequence_role, assigned_molecule, assigned_molecule_location_type, genbank_accession, relationship, refseq_accession, assembly_unit =  line.strip.split("\t")
          f.puts "\t\tasm:sequence\t["
          f.puts "\t\tasm:sequence_name\t#{quote(sequence_name)} ;"
          f.puts "\t\tasm:sequence_role\t#{quote(sequence_role)} ;"
          f.puts "\t\tasm:assigned_molecule\t#{quote(assigned_molecule)} ;"
          f.puts "\t\tasm:assigned_molecule_location_type\t#{quote(assigned_molecule_location_type)} ;"
          f.puts "\t\tasm:genbank_accession\t#{quote(genbank_accession)} ;"
          f.puts "\t\tasm:genbank\t<http://identifiers.org/insdc/#{genbank_accession}> ;"
          f.puts "\t\tasm:relationship\t#{quote(relationship)} ;"
          f.puts "\t\tasm:refseq_accession\t#{quote(refseq_accession)} ;"
          f.puts "\t\tasm:refseq\t<http://identifiers.org/refseq/#{refseq_accession}> ;"
          f.puts "\t\tasm:assembly_unit\t#{quote(assembly_unit)} ] ;"
          @status[assigned_molecule_location_type] += 1
        end
        f.puts "."
      end
    end
  end

  def quote(str)
      return str.to_s.gsub(/(\\|\t|\n|\r|")/, '\\' => '\\\\', "\t" => '\\t', "\n" => '\\n', "\r" => '\\r', '"' => '\\"').inspect
  end

  def output_prefix_common
      "@prefix asm: <http://ddbj.nig.ac.jp/ontologies/assembly/> ."
  end

  def output_prefix f
      f.puts output_prefix_common
      f.puts "@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> ."
      f.puts "@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> ."
      #puts "@prefix obo: <http://purl.obolibrary.org/obo/> ."
      f.puts "@prefix sio: <http://semanticscience.org/resource/> ."
      f.puts
      f.puts
  end

  def output_summary
    #@reports.each do |project| 
    out_file = "#{@out_path}/#{@out_summary}"
    out_dir  = File.dirname(out_file)
    FileUtils.mkdir_p(out_dir) unless FileTest.exist?(out_dir)
    puts out_file

    File.open(out_file,"w") do |f|
      output_prefix f

      #@reports.first(5).each do |project|
      @reports.each do |project|
        base_path = project['ftp_path'].sub('ftp://ftp.ncbi.nlm.nih.gov/', '')
        #basename = File.basename(base_path)
        subject = "http://ddbj.nig.ac.jp/#{base_path}"
        @sequences =[]
        acc = project["BioProject Accession"] || project["bioproject"]
        @project_uri = "http://identifiers.org/bioproject/#{acc}"
        f.puts "<#{subject}>"
        f.puts "\trdf:type\tasm:Assembly_Database_Entry ;"
        #puts "\tsio:SIO_000068\t<http://identifiers.org/#{@idtype}> ;" # sio:is-part-of
        f.puts "\trdf:type\t<http://identifiers.org/#{@idtype}> ;" # sio:is-part-of
        f.puts "\tasm:wasDerivedFrom \"#{@source}\" ;" # prov:wasDerivedFrom
        # sio:SIO_000068  <http://identifiers.org/ncbigi>
        project.each do |k,v|
          output_pv(k,v,f)
        end
        #puts "\trdfs:seeAlso\t<http://www.ncbi.nlm.nih.gov/assembly/#{project[' assembly_accession']}> ;"
        f.puts "\trdfs:seeAlso\tasm:#{project['assembly_accession']} ."
        f.puts
        #puts "\trdfs:seeAlso\tftp://ftp.ncbi.nlm.nih.gov/genomes/ASSEMBLY_REPORTS/All/#{project[' assembly_accession']}.assembly.txt ;"

        @paths.push(base_path)
        #output_each_assembly base_path

        #output_sequences # for genome_reports
        @status[project["Status"]] += 1
      end
    end
  end

  def output_sequences
      @sequences.each do |h|
          acc, type = h
          puts "<http://identifiers.org/refseq/#{acc}>"
          puts "\trdf:type\t#{type} ;"
          puts "\trdfs:label\t#{quote(acc)} ;"
          puts "\t:collection\t<#{@project_uri}#sequences> ;"
          puts "."
          puts
      end
  end

  def term2so str #status or replicon
      case str
      when "Plasmids/RefSeq" #replicon
          "obo:SO_0000155"
      when "Chromosomes/RefSeq" #replicon
          "obo:SO_0000340"
      when "Contig" #status
          "obo:SO_0000149"
      when "Gapless Chromosome" #status
          "obo:SO_0000340"
      when "Complete" #status
          "obo:SO_0000148"
      when "Scaffold" #status
          "obo:SO_0000148"
      when "Chromosome" #status
          "obo:SO_0000340"
      when "Chromosome with gaps" #status
          "obo:SO_0000340"
      else
          warn "undefied status: #{str}"
          raise error
      end
  end

  def resource_sequence v,k
      if  v != '-'
        v.split(",").each do |acc|
            #puts "\t:chromosome\t<http://identifiers.org/refseq/#{acc}> ;"
            #puts "\t:plasmid\t<http://identifiers.org/refseq/#{acc}> ;"
            #puts "\t:sequences\t<http://identifiers.org/refseq/#{acc}> ;"
            puts "\t:sequences\t<#{@project_uri}#sequences> ;" if @sequences.length == 1
            @sequences << [acc, term2so(k)]
        end
      end
  end

  def output_pv k,v,f
      #p [k,v]
       case k
       ### assembly_reports
       when 'assembly_id', 'assembly_accession'
           f.puts "\tasm:assembly_id\t#{quote(v)} ;"
       #when 'bioproject'
       #when 'biosample'
       when 'wgs_master'
          f.puts "\tasm:wgs_master\t#{quote(v)} ;"
       when 'refseq_category'
           f.puts "\tasm:refseq_category\t#{quote(v)} ;"
       #when 'organism_name'
       #when 'tax_id'
       when 'species_taxid'
           f.puts "\tasm:species_taxid\t#{quote(v)} ;"
       when 'infraspecific_name'
           f.puts "\tasm:infraspecific_name\t#{quote(v)} ;"
       when 'isolate'
           f.puts "\tasm:isolate\t#{quote(v)} ;"
       when 'version_status'
           f.puts "\tasm:version_status\t#{quote(v)} ;"
       when 'assembly_level'
           f.puts "\tasm:assembly_level\t#{quote(v)} ;"
       when 'release_type'
           f.puts "\tasm:release_type\t#{quote(v)} ;"
       when 'genome_rep'
           f.puts "\tasm:genome_rep\t#{quote(v)} ;"
       #when 'seq_rel_date'
       when 'asm_name'
           f.puts "\tasm:asm_name\t#{quote(v)} ;"
       when 'submitter'
           f.puts "\tasm:submitter\t#{quote(v)} ;"
       when 'gbrs_paired_asm'
           f.puts "\tasm:gbrs_paired_asm\t#{quote(v)} ;"
       when 'paired_asm_comp'
           f.puts "\tasm:paired_asm_comp\t#{quote(v)} ;"
       ### genome_reports
       when 'Organism/Name', 'organism_name'
           f.puts "\tasm:organism_name\t#{quote(v)} ;" 
       when 'TaxID','taxid'
          f.puts "\tasm:tax_id\t#{quote(v)} ;"
          f.puts "\tasm:taxon\t<http://identifiers.org/taxonomy/#{v}> ;" if v !='-'
       when 'BioProject Accession','bioproject'
          f.puts "\tasm:bioproject_accession\t#{quote(v)} ;"
          f.puts "\tasm:bioproject\t<http://identifiers.org/bioproject/#{v}> ;"
       when 'BioProject ID'
          f.puts "\tasm:bioproject_id\t#{quote(v)} ;"
       when 'Group'
          f.puts "\tasm:group\t#{quote(v)} ;"
       when 'SubGroup'
          f.puts "\tasm:subgroup\t#{quote(v)} ;"
       when 'Size (Mb)'
          f.puts "\tasm:size\t#{quote(v)} ;"
       when 'GC%'
          f.puts "\tasm:gc\t#{quote(v)} ;"
       when 'Assembly Accession'
          f.puts "\t_asm:assembly_accession\t#{quote(v)} ;"
       when 'Chromosomes'
          f.puts "\tasm:chromosomes\t#{quote(v)} ;"
       when 'Organelles'
          f.puts "\tasm:organelles\t#{quote(v)} ;"
       when 'Plasmids'
          f.puts "\tasm:plasmids\t#{quote(v)} ;"
       when 'WGS'
          f.puts "\tasm:wgs\t#{quote(v)} ;"
       when 'Scaffolds'
          f.puts "\tasm:scaffolds\t#{quote(v)} ;"
       when 'Genes'
          f.puts "\tasm:genes\t#{quote(v)} ;"
       when 'Proteins'
          f.puts "\tasm:proteins\t#{quote(v)} ;"
       when 'Release Date', 'seq_rel_date'
          f.puts "\tasm:release_date\t#{quote(v)} ;"
       when 'Modify Date'
          f.puts "\tasm:modify_date\t#{quote(v)} ;"
       when 'Status'
          f.puts "\tasm:status\t#{quote(v)} ;"
          #puts "\t:status2so\t#{term2so(v)} ;"
       when 'Center'
          f.puts "\tasm:center\t#{quote(v)} ;"
       when 'BioSample Accession','biosample'
          f.puts "\tasm:biosample_accession\t#{quote(v)} ;"
          f.puts "\tasm:biosample\t<http://identifiers.org/biosample/#{v}> ;" if (v != '-' and  v != 'na' and v != '')
       when 'Chromosomes/RefSeq'
          f.puts "\tasm:chromosomes_refseq\t#{quote(v)} ; #only prokaryotes"
          resource_sequence(v,k)
          #v.split(",").each { |vv| puts "\t:chromosome\t<http://identifiers.org/refseq/#{vv}> ;"} if v != '-'
       when 'Chromosomes/INSDC'
          f.puts "\tasm:chromosomes_insdc\t#{quote(v)} ; #only prokaryotes"
       when 'Plasmids/RefSeq'
          f.puts "\tasm:plasmids_refseq\t#{quote(v)} ; #only prokaryotes"
          resource_sequence(v,k)
          #v.split(",").each { |vv| puts "\t:plasmid\t<http://identifiers.org/refseq/#{vv}> ;"} if v != '-'
       when 'Plasmids/INSDC'
          f.puts "\tasm:plasmids_insdc\t#{quote(v)} ; #only prokaryotes"
       when 'Reference'
          f.puts "\tasm:reference\t#{quote(v)}; #only prokaryotes"
       when 'FTP Path' , 'ftp_path'
          f.puts "\tasm:ftp_path\t#{quote(v)}; #only prokaryotes"
       when 'excluded_from_refseq'
          f.puts "\tasm:excluded_from_refseq\t#{quote(v)} ;"
       when 'Pubmed ID'
          f.puts "\tasm:pubmed_id\t#{quote(v)} ; #only prokaryotes"
       when 'relation_to_type_material'
          f.puts "\tasm:relation_to_type_material\t#{quote(v)} ;"
       else
           f.puts "     when '#{k}'"
           warn "undefied key: #{k}"
           raise error
       end
  end
end

input = ARGV.shift
output= ARGV.shift

AssemblyReports2RDF.new(input,output)
