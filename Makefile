.PHONY: build
.PHONY: serve

build:
	cd rosshemsley.co.uk && HUGO_ENV=production hugo -d ../docs

serve:
	cd rosshemsley.co.uk && hugo serve -D 

serve-no-draft:
	cd rosshemsley.co.uk && hugo serve
