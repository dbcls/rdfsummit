#!/usr/bin/env ruby

require 'json'

hash = Hash.new({})

ft_so = File.open("ft_so.tsv")
ft_id = File.open("ft_id.tsv")
encoding = File.open("encoding.tsv")

ft_so.gets

ft_so.each do |line|
  ft_term, so_term, so_id, ft_desc, so_desc, skos, = line.split("\t")

  hash[ft_term] = {
    "so_id" => so_id,
    "so_term" => so_term,
    "ft_desc" => ft_desc,
    "so_desc" => so_desc,
    "mapping" => skos,
  }
end

ft_id.each do |line|
  ft_class, ft_term = line.strip.split(/\t/)
  if hash[ft_term]
    hash[ft_term]["ft_id"] = ft_class
  end
end

encoding.each do |line|
  next if line[/^#/]
  ft_term, encoding, so_term = line.strip.split(/\t/)
  hash[ft_term]["encoding"] = { "so_id" => encoding, "so_term" => so_term }
end

# http://www.insdc.org/rna_vocab.html
# http://www.sequenceontology.org/browser/current_svn/term/SO:0000602
hash["guide_RNA"] = {
  "so_id" => "SO:0000602",
  "so_term" => "guide_RNA",
  "so_desc" => "A short 3'-uridylated RNA that can form a duplex (except for its post-transcriptionally added oligo_U tail (SO:0000609)) with a stretch of mature edited mRNA.",
  "ft_desc" => "short 3'-uridylated RNA that can form a duplex with a stretch of mature edited mRNA.",
  "mapping" => "",
  "encoding" => { "so_id" => "SO:0000979", "so_term" => "gRNA_encoding" }
}

# http://www.sequenceontology.org/browser/current_svn/term/SO:0000276
hash["miRNA"] = {
  "so_id" => "SO:0000276",
  "so_term" => "miRNA",
  "so_desc" => "Small, ~22-nt, RNA molecule that is the endogenous transcript of a miRNA gene. Micro RNAs are produced from precursor molecules (SO:0000647) that can form local hairpin structures, which ordinarily are processed (via the Dicer pathway) such that a single miRNA molecule accumulates from one arm of a hairpin precursor molecule. Micro RNAs may trigger the cleavage of their target molecules or act as translational repressors.",
  "ft_desc" => "small, ~22-nt, RNA molecule, termed microRNA, produced from precursor molecules that can form local hairpin structures, which ordinarily are processed (via the Dicer pathway) such that a single miRNA molecule accumulates from one arm of a hairpin precursor molecule. MicroRNAs may trigger the cleavage of their target molecules or act as translational repressors.",
  "mapping" => "",
  "encoding" => { "so_id" => "SO:0000571", "so_term" => "miRNA_encoding" }
}

# http://www.sequenceontology.org/browser/current_svn/term/SO:0000590
hash["SRP_RNA"] = {
  "so_id" => "SO:0000590",
  "so_term" => "SRP_RNA",
  "so_desc" => "The signal recognition particle (SRP) is a universally conserved ribonucleoprotein. It is involved in the co-translational targeting of proteins to membranes. The eukaryotic SRP consists of a 300-nucleotide 7S RNA and six proteins: SRPs 72, 68, 54, 19, 14, and 9. Archaeal SRP consists of a 7S RNA and homologues of the eukaryotic SRP19 and SRP54 proteins. In most eubacteria, the SRP consists of a 4.5S RNA and the Ffh protein (a homologue of the eukaryotic SRP54 protein). Eukaryotic and archaeal 7S RNAs have very similar secondary structures, with eight helical elements. These fold into the Alu and S domains, separated by a long linker region. Eubacterial SRP is generally a simpler structure, with the M domain of Ffh bound to a region of the 4.5S RNA that corresponds to helix 8 of the eukaryotic and archaeal SRP S domain. Some Gram-positive bacteria (e.g. Bacillus subtilis), however, have a larger SRP RNA that also has an Alu domain. The Alu domain is thought to mediate the peptide chain elongation retardation function of the SRP. The universally conserved helix which interacts with the SRP54/Ffh M domain mediates signal sequence recognition. In eukaryotes and archaea, the SRP19-helix 6 complex is thought to be involved in SRP assembly and stabilizes helix 8 for SRP54 binding.",
  "ft_desc" => "signal recognition particle, a universally conserved ribonucleoprotein involved in the co-translational targeting of proteins to membranes.",
  "mapping" => "",
  "encoding" => { "so_id" => "SO:0000642", "so_term" => "SRP_RNA_encoding" }
}

puts JSON.pretty_generate(hash)
