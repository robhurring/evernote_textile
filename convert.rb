# = About
# convert Evernote notes tagged 'convert' using RedCloth brand textile :)
# this will ruin rich formatted texts, as the script doesn't properly parse
# ENML, or it isn't returned properly. either way. its a hack, so..
# 
# == Usage
# create a note, on the iphone or whatever, as plain text and use textile syntax. this script supports ENML todos
# currently, but may support more stuff in the future.
# 
# to create a todo you can use the following:
# 
#   [x]   => checked off todo
#   [ ]   => non-checked off todo
# 
# Author:: Rob Hurring
# Date: 9/8/2010

require 'rubygems'
require 'yaml'
require 'pp'
require 'lib/evernote/evernote'
require 'RedCloth'
require 'nokogiri'

# whitelist the HTML tags so we don't go nuts.
# Thanks: http://jeff.jones.be/technology/articles/textile-filtering-with-redcloth/
module RedCloth::Formatters::HTML
  include RedCloth::Formatters::Base
  
  def after_transform(text)
    text.chomp!
    clean_html(text, ALLOWED_TAGS)
  end
  
  ALLOWED_TAGS = {
      'i' => nil,
      'u' => nil,
      'b' => nil,
      'pre' => nil,
      'code' => nil,
      'strong' => nil,
      'em' => nil,
      'ins' => nil,
      'del' => nil,
      'p' => nil
    }
end

convert_tag_name = 'convert'
convert_tag_guid = nil

config = YAML.load_file(File.dirname(__FILE__)+'/evernote.yml')
Evernote.config = config

user_store = Evernote::UserStore.new.authenticate!
note_store = Evernote::NoteStore.new(user_store.user)

# find our convert-tag's GUID
tags_list = note_store.listTags(user_store.token)
tags_list.each do |tag|
  if tag.name == convert_tag_name
    convert_tag_guid = tag.guid
  end
end

if convert_tag_guid.nil?
  raise "Couldn't find the proper GUID for our convert flag: #{convert_tag_name}!"
end

# find convertable notes
nb_filter = Evernote::EDAM::NoteStore::NoteFilter.new(:tagGuids => [convert_tag_guid])
note_list = note_store.findNotes(user_store.token, nb_filter, 0, 10)

# replace special evernote structs before converting RedCloth-textile
content_filters = {
  /^\[(.+)\]\s/ => Proc.new{ %{<en-todo checked="#{$1 == 'x'}" /> } } # [x] | [ ] for todos
}

note_list.notes.each do |note|
  puts "Converting: #{note.title} (#{note.guid})"

  note_content = note_store.getNoteContent(user_store.token, note.guid)

  converted = Nokogiri::XML(note_content).xpath('//en-note/*').inject('') do |builder, node|
    next if node.name =~ /^en/ # ignore ENML specific nodes
    node_content = node.content.dup
    content_filters.each{ |k, v| node_content.gsub!(k, &v) }
    builder << RedCloth.new(node_content).to_html
  end
  
  note.tagGuids -= [convert_tag_guid]
  note.content = %{<?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd">
    <en-note>
      #{converted}
    </en-note>}.force_encoding('UTF-8')
  
  if note_store.updateNote(user_store.token, note)
    puts "Converted!"
  else
    puts "Conversion failed."
  end
end
