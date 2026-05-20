# frozen_string_literal: true

require "erb"
require "fileutils"
require "securerandom"

ROOT         = __dir__
TEMPLATE_DIR = File.join(ROOT, "template")
AGENTS_DIR   = File.join(ROOT, "agents")
PLACEHOLDER  = "AGENT_NAME"

namespace :generate do
  desc "Generate a new agent: rake generate:agent[name]"
  task :agent, [:name] do |_t, args|
    name = args[:name]&.strip&.downcase
    abort "Usage: rake generate:agent[name]" if name.nil? || name.empty?
    abort "Agent '#{name}' already exists at agents/#{name}" if Dir.exist?(File.join(AGENTS_DIR, name))

    title    = name.capitalize
    as_token = SecureRandom.hex(32)
    hs_token = SecureRandom.hex(32)
    b        = binding

    # -- Walk the template tree and merge into the repo ----------------------

    Dir.glob(File.join(TEMPLATE_DIR, "**", "*"), File::FNM_DOTMATCH).sort.each do |src|
      next if File.directory?(src)

      rel  = src.sub("#{TEMPLATE_DIR}/", "")
      dest = File.join(ROOT, rel.gsub(PLACEHOLDER, name))

      is_erb = dest.end_with?(".erb")
      dest   = dest.chomp(".erb") if is_erb

      FileUtils.mkdir_p(File.dirname(dest))

      if is_erb
        template = File.read(src)
        File.write(dest, ERB.new(template, trim_mode: "-").result(b))
      else
        FileUtils.cp(src, dest)
      end
    end

    # -- Copy Gemfile.lock from brute (identical base deps) ------------------

    FileUtils.cp(
      File.join(AGENTS_DIR, "brute", "Gemfile.lock"),
      File.join(AGENTS_DIR, name, "Gemfile.lock")
    )

    # -- Patch homeserver.yaml -----------------------------------------------

    hs_path    = File.join(ROOT, "docker", "synapse", "homeserver.yaml")
    hs_content = File.read(hs_path)
    as_line    = "  - /data/appservices/#{name}.yml\n"

    unless hs_content.include?(as_line)
      hs_content.sub!(/^(app_service_config_files:\n(?:  - [^\n]+\n)*)/) { "#{$1}#{as_line}" }
      File.write(hs_path, hs_content)
    end

    # -- Patch docker-compose.yml --------------------------------------------

    compose_path = File.join(ROOT, "docker-compose.yml")
    compose      = File.read(compose_path)

    # Next available host ports
    next_a2a    = (compose.scan(/- (\d+):4000/).flatten.map(&:to_i).max || 3999) + 1
    next_app    = (compose.scan(/- (\d+):5000/).flatten.map(&:to_i).max || 4999) + 1
    next_health = (compose.scan(/- (\d+):8080/).flatten.map(&:to_i).max || 8079) + 1

    service_block = [
      "",
      "  #{name}:",
      "    build:",
      "      context: ./agents",
      "      dockerfile: #{name}/Dockerfile",
      "    restart: unless-stopped",
      "    depends_on:",
      "      synapse:",
      "        condition: service_healthy",
      "      ollama:",
      "        condition: service_started",
      "    environment:",
      "      AGENT_NAME: #{name}",
      "      AS_TOKEN: \"#{as_token}\"",
      "      HS_TOKEN: \"#{hs_token}\"",
      "      HOMESERVER_ADDRESS: \"http://synapse:8008\"",
      "      HOMESERVER_DOMAIN: \"localhost\"",
      "      OLLAMA_API_BASE: \"http://ollama:11434/v1\"",
      "    volumes:",
      "      - #{name}-sessions:/app/sessions",
      "    ports:",
      "      - #{next_a2a}:4000",
      "      - #{next_app}:5000",
      "      - #{next_health}:8080",
      "",
    ].join("\n")

    compose.sub!(/^(  bootstrap:)/, "#{service_block}\n  bootstrap:")

    compose.sub!(/(  bootstrap:.*?depends_on:\n(?:.*?condition:.*?\n)*)/m) do |match|
      match + "      #{name}:\n        condition: service_started\n"
    end

    compose.sub!(/DEMO_AGENTS: "(.*?)"/) { "DEMO_AGENTS: \"#{$1} #{name}\"" }

    compose.sub!(/^(volumes:\n)/) { "#{$1}  #{name}-sessions:\n" }

    File.write(compose_path, compose)
  end
end
