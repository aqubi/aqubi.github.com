require "json"
require "net/http"
require "uri"
require "yaml"
require "fileutils"
require "open-uri"

APPS_FILE = "_data/apps.yml"
OUTPUT_FILE = "products.md"
IMAGE_DIR = "img"

FileUtils.mkdir_p(IMAGE_DIR)

def fetch_app(app_id, country)
  uri = URI("https://itunes.apple.com/lookup?id=#{app_id}&country=#{country}")
  response = Net::HTTP.get_response(uri)

  return nil unless response.is_a?(Net::HTTPSuccess)

  data = JSON.parse(response.body)
  data["results"]&.first
rescue => e
  warn "Failed to fetch app #{app_id} (#{country}): #{e.message}"
  nil
end

apps = YAML.load_file(APPS_FILE)

markdown = <<~MD
  ---
  layout: products
  title: Products
  css: /assets/css/products.css
  ---

  # Products

  <div class="products-grid">

MD

apps.each do |config|
  app_id = config["id"].to_s

  puts "Fetching App Store data: #{app_id}"

  #
  # US App Storeを優先
  #
  app = fetch_app(app_id, "us")

  #
  # USで見つからない場合は日本のApp Store
  #
  unless app
    puts "  Not available in US. Trying Japan..."
    app = fetch_app(app_id, "jp")
  end

  unless app
    warn "App not found: #{app_id}"
    next
  end

  name = app["trackName"]
  app_store_url = app["trackViewUrl"]

  puts "  #{name}"

  #
  # App icon
  #
  artwork_url =
    app["artworkUrl512"] ||
    app["artworkUrl100"] ||
    app["artworkUrl60"]

  image_filename = "app_#{app_id}.png"
  image_path = File.join(IMAGE_DIR, image_filename)

  if artwork_url
    puts "  Downloading icon: #{image_filename}"

    begin
      URI.open(artwork_url) do |image|
        File.binwrite(image_path, image.read)
      end
    rescue => e
      warn "  Failed to download icon: #{e.message}"
    end
  else
    warn "  Artwork URL not found"
  end

  description = config["description"]
  devices = config["devices"]

  #
  # Links
  #
  links = []

  if config["help"]
    links << "<a href=\"#{config["help"]}\">Help</a>"
  end

  if config["privacy"]
    links << "<a href=\"#{config["privacy"]}\">Privacy Policy</a>"
  end

  if app_store_url
    links << "<a href=\"#{app_store_url}\">App Store</a>"
  end

  #
  # Product HTML
  #
  markdown << <<~HTML
    <div class="product">

  HTML

  #
  # Icon
  #
  if File.exist?(image_path)
    if app_store_url
      markdown << <<~HTML
        <a class="app-icon" href="#{app_store_url}">
          <img src="#{image_path}" alt="#{name}">
        </a>

      HTML
    else
      markdown << <<~HTML
        <div class="app-icon">
          <img src="#{image_path}" alt="#{name}">
        </div>

      HTML
    end
  end

  #
  # Text area
  #
  markdown << <<~HTML
      <div class="product-info">
        <h2>#{name}</h2>

  HTML

  if description && !description.empty?
    markdown << "    <p class=\"description\">#{description}"

    if devices && !devices.empty?
      markdown << "<br>\n"
      markdown << "      <span class=\"devices\">#{devices}</span>"
    end

    markdown << "</p>\n\n"
  elsif devices && !devices.empty?
    markdown << <<~HTML
        <p class="description">
          <span class="devices">#{devices}</span>
        </p>

    HTML
  end

  unless links.empty?
    markdown << <<~HTML
        <div class="app-links">
          #{links.join(" · ")}
        </div>

    HTML
  end

  markdown << <<~HTML
      </div>
    </div>

  HTML
end

markdown << "</div>\n"

File.write(OUTPUT_FILE, markdown)

puts
puts "Generated #{OUTPUT_FILE}"