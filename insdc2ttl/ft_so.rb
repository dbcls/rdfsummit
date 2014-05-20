#!/usr/bin/env ruby

require 'json'

hash = {}

ARGF.gets

ARGF.each do |line|
  ft_term, so_term, so_id, ft_desc, so_desc, skos, = line.split("\t")

  hash[ft_term] = {
    "so_id" => so_id,
    "so_term" => so_term,
    "ft_desc" => ft_desc,
    "so_desc" => so_desc,
    "mapping" => skos,
  }
end

puts JSON.pretty_generate(hash)
