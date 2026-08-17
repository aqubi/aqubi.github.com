# Run Jekyll locally with live reload.
# $ make serve
serve:
	bundle exec jekyll serve --livereload

# Generate products.md and download app icons from App Store metadata.
# 1. Edit _data/apps.yml
# 2. $ make products
products:
	ruby scripts/generate_products.rb