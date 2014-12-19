#!/usr/bin/env ruby
#
# convert assembly_reprots to RDF
# * ftp://ftp.ncbi.nlm.nih.gov/genomes/ASSEMBLY_REPORTS/assembly_summary_refseq.txt
#

#[" assembly_id", "GCF_000001215.2"]
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
#


class AssemblyReports2RDF
  ASSEMBLY_ROOT= 'ASSEMBLY_REPORTS'
  REPORT_FILES = %w(assembly_summary_refseq.txt)

  attr_accessor :status

  def initialize
    @status = Hash.new{|h,k|h[k]=0}
    @reports =[] 
    parse_reports
    output_prefix
    output_project
  end 

  def parse_reports
    REPORT_FILES.each do |input_file|
        head = []
        File.readlines("#{ASSEMBLY_ROOT}/#{input_file}").each_with_index do |line,i|
            if i == 0
               head =line.strip.gsub("\r","").gsub(/^#/,"").split("\t")
            else
               @reports << head.zip(line.strip.split("\t")).inject({}){|h,col| h[col[0]]=col[1];h}
            end 
        end 
    end 
  end

  def output_assembly_reports id
      # /home/sw/tf/ASSEMBLY_REPORTS/All/
      File.readlines("#{ASSEMBLY_ROOT}/All/#{id}.assembly.txt").each_with_index do |line,i|
         next if line =~/^#/
         # Sequence-Name Sequence-Role   Assigned-Molecule       Assigned-Molecule-Location/Type GenBank-Accn    Relationship    RefSeq-Accn     Assembly-Unit
         sequence_name, sequence_role, assigned_molecule, assigned_molecule_location_type, genbank_accession, relationship, refseq_accession, assembly_unit =  line.strip.split("\t")
         puts "\tasm:sequnece\t["
         puts "\t\tasm:sequence_name\t#{quote(sequence_name)} ;"
         puts "\t\tasm:sequence_role\t#{quote(sequence_role)} ;"
         puts "\t\tasm:assigned_molecule\t#{quote(assigned_molecule)} ;"
         puts "\t\tasm:assigned_molecule_location_type\t#{quote(assigned_molecule_location_type)} ;"
         puts "\t\tasm:genbank_accession\t#{quote(genbank_accession)} ;"
         puts "\t\tasm:genbank\t<http://identifiers.org/insdc/#{genbank_accession}> ;"
         puts "\t\tasm:relationship\t#{quote(relationship)} ;"
         puts "\t\tasm:refseq_accession\t#{quote(refseq_accession)} ;"
         puts "\t\tasm:refseq\t<http://identifiers.org/refseq/#{refseq_accession}> ;"
         puts "\t\tasm:assembly_unit\t#{quote(assembly_unit)} ] ;"

         @status[assigned_molecule_location_type] += 1
      end
  end

  def quote(str)
      return str.to_s.gsub('\\', '\\\\').gsub("\t", '\\t').gsub("\n", '\\n').gsub("\r", '\\r').gsub('"', '\\"').inspect
  end
  
  def output_prefix
      puts "@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> ."
      puts "@prefix obo: <http://purl.obolibrary.org/obo/> ."
      puts "@prefix asm: <http://www.ncbi.nlm.nih.gov/assembly/> ."
      puts
      puts
  end
  
  def output_project
    @reports.each do |project|
    #@reports.first(5).each do |project|
         @sequences =[] 
         acc = project["BioProject Accession"] || project["bioproject"]
         @project_uri = "http://identifiers.org/bioproject/#{acc}"
         #puts "<#{@project_uri}>"
         puts "["
         project.each do |k,v|
             output_pv(k,v)
         end 
         puts "\trdfs:seeAlso\t<http://www.ncbi.nlm.nih.gov/assembly/#{project[' assembly_id']}> ;"
         #puts "\trdfs:seeAlso\tftp://ftp.ncbi.nlm.nih.gov/genomes/ASSEMBLY_REPORTS/All/#{project[' assembly_id']}.assembly.txt ;"
         output_assembly_reports project[' assembly_id']
         puts "]"
         puts "." 
         puts 
         #output_sequences # for genome_reports
         @status[project["Status"]] += 1
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
  
  def output_pv k,v
      #p [k,v]
       case k
       ### assembly_reports
       when ' assembly_id'
           puts "\tasm:assembly_id\t#{quote(v)} ;" 
       #when 'bioproject'
       #when 'biosample'
       when 'wgs_master'
          puts "\tasm:wgs_master\t#{quote(v)} ;"
       when 'refseq_category'
           puts "\tasm:refseq_category\t#{quote(v)} ;"
       #when 'organism_name'
       #when 'tax_id'
       when 'species_taxid'    
           puts "\tasm:species_taxid\t#{quote(v)} ;"
       when 'infraspecific_name'
           puts "\tasm:infraspecific_name\t#{quote(v)} ;"
       when 'isolate'
           puts "\tasm:isolate\t#{quote(v)} ;"
       when 'version_status'
           puts "\tasm:version_status\t#{quote(v)} ;"
       when 'assembly_level'    
           puts "\tasm:assembly_level\t#{quote(v)} ;"
       when 'release_type'
           puts "\tasm:release_type\t#{quote(v)} ;"
       when 'genome_rep'    
           puts "\tasm:genome_rep\t#{quote(v)} ;"
       #when 'seq_rel_date'
       when 'asm_name'
           puts "\tasm:asm_name\t#{quote(v)} ;"
       when 'submitter'
           puts "\tasm:submitter\t#{quote(v)} ;"
       when 'gbrs_paired_asm'  
           puts "\tasm:gbrs_paired_asm\t#{quote(v)} ;"
       when 'paired_asm_comp'    
           puts "\tasm:paired_asm_comp\t#{quote(v)} ;"
       ### genome_reports    
       when 'Organism/Name', 'organism_name'    
          puts "\tasm:organism_name\t#{quote(v)} ;" 
       when 'TaxID','taxid'
          puts "\tasm:tax_id\t#{quote(v)} ;" 
          puts "\tasm:taxon\t<http://identifiers.org/taxonomy/#{v}> ;" if v !='-'
       when 'BioProject Accession','bioproject'
          puts "\tasm:bioproject_accession\t#{quote(v)} ;" 
          puts "\tasm:bioproject\t<http://identifiers.org/bioproject/#{v}> ;" 
       when 'BioProject ID'
          puts "\tasm:bioproject_id\t#{quote(v)} ;" 
       when 'Group'
          puts "\tasm:group\t#{quote(v)} ;" 
       when 'SubGroup'
          puts "\tasm:subgroup\t#{quote(v)} ;" 
       when 'Size (Mb)'
          puts "\tasm:size\t#{quote(v)} ;" 
       when 'GC%'
          puts "\tasm:gc\t#{quote(v)} ;" 
       when 'Assembly Accession'
          puts "\t_asm:assembly_accession\t#{quote(v)} ;" 
       when 'Chromosomes'
          puts "\tasm:chromosomes\t#{quote(v)} ;" 
       when 'Organelles'
          puts "\tasm:organelles\t#{quote(v)} ;" 
       when 'Plasmids'
          puts "\tasm:plasmids\t#{quote(v)} ;" 
       when 'WGS'
          puts "\tasm:wgs\t#{quote(v)} ;" 
       when 'Scaffolds'
          puts "\tasm:scaffolds\t#{quote(v)} ;" 
       when 'Genes'
          puts "\tasm:genes\t#{quote(v)} ;" 
       when 'Proteins'
          puts "\tasm:proteins\t#{quote(v)} ;" 
       when 'Release Date', 'seq_rel_date'
          puts "\tasm:release_date\t#{quote(v)} ;"
       when 'Modify Date'
          puts "\tasm:modify_date\t#{quote(v)} ;"
       when 'Status'
          puts "\tasm:status\t#{quote(v)} ;" 
          #puts "\t:status2so\t#{term2so(v)} ;"
       when 'Center'
          puts "\tasm:center\t#{quote(v)} ;" 
       when 'BioSample Accession','biosample'
          puts "\tasm:biosample_accession\t#{quote(v)} ;" 
          puts "\tasm:biosample\t<http://identifiers.org/biosample/#{v}> ;" if (v != '-' and  v != 'na')
       when 'Chromosomes/RefSeq'
          puts "\tasm:chromosomes_refseq\t#{quote(v)} ; #only prokaryotes" 
          resource_sequence(v,k)
          #v.split(",").each { |vv| puts "\t:chromosome\t<http://identifiers.org/refseq/#{vv}> ;"} if v != '-'
       when 'Chromosomes/INSDC'
          puts "\tasm:chromosomes_insdc\t#{quote(v)} ; #only prokaryotes" 
       when 'Plasmids/RefSeq'
          puts "\tasm:plasmids_refseq\t#{quote(v)} ; #only prokaryotes" 
          resource_sequence(v,k)
          #v.split(",").each { |vv| puts "\t:plasmid\t<http://identifiers.org/refseq/#{vv}> ;"} if v != '-'
       when 'Plasmids/INSDC'
          puts "\tasm:plasmids_insdc\t#{quote(v)} ; #only prokaryotes" 
       when 'Reference'
          puts "\tasm:reference\t#{quote(v)}; #only prokaryotes" 
       when 'FTP Path'
          puts "\tasm:ftp_path\t#{quote(v)}; #only prokaryotes" 
       when 'Pubmed ID'
          puts "\tasm:pubmed_id\t#{quote(v)} ; #only prokaryotes" 
       else
           puts "     when '#{k}'"
           warn "undefied key: #{k}"
           raise error
       end
  end
end

AssemblyReports2RDF.new
#reports = AssemblyReports2RDF.new
#warn reports.status
