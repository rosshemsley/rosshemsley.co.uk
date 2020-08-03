.PHONY: build
.PHONY: serve

build:
	rm -rf docs
	cd rosshemsley.co.uk && HUGO_ENV=production hugo -d ../docs
	cp CNAME.in ./docs/CNAME

serve:
	cd rosshemsley.co.uk && hugo serve -D 

serve-no-draft:
	cd rosshemsley.co.uk && hugo serve
