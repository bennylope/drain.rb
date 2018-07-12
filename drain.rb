#!/usr/bin/env ruby

# A little Ruby script to download your Drip broadcast messages to Jekyll-ready
# Markdown files. These could be used as posts or, better yet, as a collection.
# Inspired by Jonathan Stark's Drain https://github.com/jonathanstark/drain/
#
# Copyright Ben Lopatin, 2018
# Shared with an MIT license: https://opensource.org/licenses/MIT

# Since this is a standalone script, installing the dependencies is your responsibility
#  - drip-ruby
#  - slugify
#  - reverse_markdown
#
# The _drain.yml file must include these 3 key, value pairs:
#
# - account_id: the ID of your Drip account
# - api_key: your API key for accessing the Drip API
# - directory: the directory where you'll include all of your new files
#
# Optionally you can include:
# - layout: the Jekyll layout (defaults to "newsletter")
# - published: whether these should be published by default (default is true)
# - status: the broadcast messages status to filter on (default is "sent")
# - overwrite: whether existing files should be overwritten (default is false)

# TODO: make broadcast status from env/arg
# TODO: filter braodcasts based on groups

require 'date'
require 'yaml'
require 'drip'
require 'slugify'
require 'reverse_markdown'


if File.exist?("_drain.yml")
    CONF = YAML.load(File.open(File.join(File.dirname(__FILE__), "_drain.yml"), File::RDONLY).read)
else
    abort("Cannot find your _drain.yml configuration file")
end

target = File.join(File.dirname(__FILE__), CONF["directory"])
overwrite = CONF.fetch("overwrite", false)
options = {
    status: CONF.fetch("status", "sent")
}

client = Drip::Client.new do |c|
    c.api_key = CONF["api_key"]
    c.account_id = CONF["account_id"]
end

response = client.broadcasts(options)

if response.success?
    for broadcast in response.body["broadcasts"]
        slug = broadcast["subject"].slugify.gsub(/\A[_\W]+|[_\W]+\Z/, '')
        filename = File.join(target, slug + '.md')
        if overwrite or !File.file?(filename)
            frontmatter = {
                "title" => broadcast["subject"],
                "layout" => CONF.fetch("layout", "newsletter"),
                "published" => CONF.fetch("published", true),
                "date" => broadcast["send_at"]
            }
            body = ReverseMarkdown.convert broadcast["html_body"].split("{%")[0]
            content = [frontmatter.to_yaml, body].join("\n")
            File.open(filename, 'w') { |file| file.write(content) }
        end
    end
else
    abort("API failure!")
end