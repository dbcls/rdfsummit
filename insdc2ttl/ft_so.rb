#!/usr/bin/env ruby

require 'json'

hash = {}

ft_so = File.open("ft_so.tsv")
ft_id = File.open("ft_id.tsv")

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

puts JSON.pretty_generate(hash)
